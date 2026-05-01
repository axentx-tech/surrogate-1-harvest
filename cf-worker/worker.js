// surrogate-1-cursor — CF Worker replacement for HF Space cursor service
//
// Routes:
//   GET  /health                          -> 200 ok
//   GET  /dynamic-datasets                -> array of registered datasets (KV-cached 60s)
//   GET  /cursor/<slug>                   -> {dataset_id, offset, total, exhausted, last_batch, updated_at}
//   POST /cursor/<slug>/advance           -> body {size, total?, last_batch?, exhausted?} -> atomic increment
//   POST /datasets                        -> body {slug, hf_id, schema?, score?, cap?} -> upsert
//   GET  /metrics                         -> Prom-ish counters
//   GET  /audit?limit=N&since=TS          -> recent audit log (auth required)
//
// Bindings: env.DB (D1 surrogate-1-cursor), env.CACHE (KV), env.AUTH_TOKEN (secret)
//
// Roadmap features in this version:
//   #1  cursor "exhausted" + total tracking
//   #2  Worker auth (shared secret on write/audit)
//   #9  audit log (every advance/upsert)
//   #21 /metrics endpoint

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Auth-Token",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });

// Auth: required on writes (POST advance/datasets) and audit reads.
// Reads of /cursor/<slug> + /dynamic-datasets stay public so external
// orchestrators can poll without secrets — they can only READ.
function authed(request, env) {
  const want = (env.AUTH_TOKEN || "").trim();
  if (!want) return true; // not configured = open mode (dev only)
  const got = (
    request.headers.get("X-Auth-Token") ||
    (request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "")
  ).trim();
  return got && got === want;
}

async function audit(env, ctx, action, slug, meta) {
  // Fire-and-forget — never block the request on audit write
  ctx.waitUntil(
    env.DB.prepare(
      "INSERT INTO audit_log (action, dataset_id, meta, ts) VALUES (?1, ?2, ?3, unixepoch())"
    )
      .bind(action, slug || null, JSON.stringify(meta || {}).slice(0, 2000))
      .run()
      .catch(() => {})
  );
}

async function bumpMetric(env, ctx, key) {
  ctx.waitUntil(
    env.DB.prepare(
      "INSERT INTO metrics (key, n) VALUES (?1, 1) " +
      "ON CONFLICT(key) DO UPDATE SET n = n + 1"
    ).bind(key).run().catch(() => {})
  );
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    const url = new URL(request.url);
    const path = url.pathname;
    const t0 = Date.now();

    try {
      // ── public reads ──────────────────────────────────────────────────
      if (path === "/health" || path === "/") {
        await bumpMetric(env, ctx, "req:health");
        return json({ status: "ok", service: "surrogate-1-cursor", ts: Date.now() });
      }

      if (path === "/dynamic-datasets" && request.method === "GET") {
        await bumpMetric(env, ctx, "req:datasets");
        const cached = await env.CACHE.get("datasets:all", { type: "json" });
        if (cached) return json(cached);
        const r = await env.DB.prepare(
          "SELECT slug, hf_id AS id, schema, license, cap, score, downloads, discovered_ts FROM datasets ORDER BY score DESC LIMIT 5000"
        ).all();
        const list = r.results || [];
        ctx.waitUntil(env.CACHE.put("datasets:all", JSON.stringify(list), { expirationTtl: 60 }));
        return json(list);
      }

      if (path === "/metrics" && request.method === "GET") {
        const r = await env.DB.prepare("SELECT key, n FROM metrics ORDER BY key").all();
        // Prometheus exposition format
        const lines = [
          "# HELP surrogate_cursor_requests Total requests by endpoint",
          "# TYPE surrogate_cursor_requests counter",
        ];
        for (const m of (r.results || [])) {
          lines.push(`surrogate_cursor_requests{key="${m.key}"} ${m.n}`);
        }
        return new Response(lines.join("\n") + "\n", {
          headers: { "Content-Type": "text/plain; version=0.0.4", ...CORS },
        });
      }

      // /cursor/<slug>(/advance)?
      const m = path.match(/^\/cursor\/([^\/]+)(\/advance)?\/?$/);
      if (m) {
        const slug = decodeURIComponent(m[1]);
        const isAdvance = !!m[2] && request.method === "POST";

        if (isAdvance) {
          // Writes require auth
          if (!authed(request, env)) {
            return json({ error: "auth required (X-Auth-Token header)" }, 401);
          }
          const b = await request.json().catch(() => ({}));
          const size = Math.max(1, Math.min(100000, parseInt(b.size || 1000)));
          const last = (b.last_batch || "").slice(0, 200);
          const total = b.total != null ? parseInt(b.total) : null;
          const exhausted = b.exhausted ? 1 : 0;

          // Atomic upsert + increment.  If `exhausted` is set or new offset
          // reaches `total`, mark the cursor done — workers will skip on next
          // /cursor/<slug> read because exhausted=1.
          const cur = await env.DB.prepare(
            "INSERT INTO cursors (dataset_id, offset, total, last_batch, exhausted) " +
            "VALUES (?1, ?2, ?3, ?4, ?5) " +
            "ON CONFLICT(dataset_id) DO UPDATE SET " +
            "  offset     = offset + ?2, " +
            "  total      = COALESCE(?3, total), " +
            "  last_batch = ?4, " +
            "  exhausted  = MAX(exhausted, ?5), " +
            "  updated_at = unixepoch() " +
            "RETURNING dataset_id, offset, total, last_batch, exhausted, updated_at"
          ).bind(slug, size, total, last, exhausted).first();
          // Auto-mark exhausted if offset reached total
          if (cur && cur.total != null && cur.offset >= cur.total && !cur.exhausted) {
            await env.DB.prepare(
              "UPDATE cursors SET exhausted = 1 WHERE dataset_id = ?"
            ).bind(slug).run();
            cur.exhausted = 1;
          }
          await bumpMetric(env, ctx, "req:advance");
          await audit(env, ctx, "advance", slug, { size, total, exhausted: cur?.exhausted });
          return json(cur);
        }

        // Public read of cursor state
        await bumpMetric(env, ctx, "req:cursor_read");
        let cur = await env.DB.prepare(
          "SELECT dataset_id, offset, total, last_batch, exhausted, updated_at FROM cursors WHERE dataset_id = ?"
        ).bind(slug).first();
        if (!cur) {
          cur = { dataset_id: slug, offset: 0, total: null, last_batch: null, exhausted: 0, updated_at: null };
        }
        return json(cur);
      }

      // POST /datasets — register or upsert (auth required)
      if (path === "/datasets" && request.method === "POST") {
        if (!authed(request, env)) return json({ error: "auth required" }, 401);
        const b = await request.json().catch(() => ({}));
        if (!b.slug || !b.hf_id) return json({ error: "slug and hf_id required" }, 400);
        await env.DB.prepare(
          "INSERT INTO datasets (slug, hf_id, schema, license, cap, score) VALUES (?1, ?2, ?3, ?4, ?5, ?6) " +
          "ON CONFLICT(slug) DO UPDATE SET hf_id=excluded.hf_id, schema=excluded.schema, license=excluded.license, cap=excluded.cap, score=excluded.score"
        ).bind(b.slug, b.hf_id, b.schema || "messages", b.license || null, b.cap || 50000, b.score || 0.5).run();
        ctx.waitUntil(env.CACHE.delete("datasets:all"));
        await audit(env, ctx, "register", b.slug, { hf_id: b.hf_id });
        await bumpMetric(env, ctx, "req:datasets_upsert");
        return json({ ok: true, slug: b.slug });
      }

      // GET /audit — last N audit rows (auth required)
      if (path === "/audit" && request.method === "GET") {
        if (!authed(request, env)) return json({ error: "auth required" }, 401);
        const limit = Math.min(500, parseInt(url.searchParams.get("limit") || "100"));
        const since = parseInt(url.searchParams.get("since") || "0");
        const r = await env.DB.prepare(
          "SELECT id, action, dataset_id, meta, ts FROM audit_log WHERE ts >= ? ORDER BY id DESC LIMIT ?"
        ).bind(since, limit).all();
        return json(r.results || []);
      }

      return json({ error: "not found", path }, 404);
    } catch (e) {
      await bumpMetric(env, ctx, "req:error");
      return json({ error: e.message, stack: (e.stack || "").split("\n")[0] }, 500);
    } finally {
      // Latency observability
      const dt = Date.now() - t0;
      ctx.waitUntil(
        env.DB.prepare(
          "INSERT INTO metrics (key, n) VALUES ('latency_ms_sum', ?) ON CONFLICT(key) DO UPDATE SET n = n + ?"
        ).bind(dt, dt).run().catch(() => {})
      );
    }
  },
};
