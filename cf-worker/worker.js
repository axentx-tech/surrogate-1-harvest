// surrogate-1-cursor — replaces HF Space's status server
// Routes:
//   GET  /health                       -> 200 ok
//   GET  /dynamic-datasets             -> array of registered datasets
//   GET  /cursor/<slug>                -> {offset, total, last_batch}
//   POST /cursor/<slug>/advance        -> atomic offset += body.size, returns new offset
//   POST /datasets                     -> {slug, hf_id, schema?, score?, cap?}  (registers a new ds)
//
// Bindings: env.DB (D1 surrogate-1-cursor), env.CACHE (KV surrogate-1-cursor-cache)

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === "/health" || path === "/") {
        return json({ status: "ok", service: "surrogate-1-cursor", ts: Date.now() });
      }

      // GET /dynamic-datasets — KV-cached for 60s, falls through to D1
      if (path === "/dynamic-datasets" && request.method === "GET") {
        const cached = await env.CACHE.get("datasets:all", { type: "json" });
        if (cached) return json(cached);
        const r = await env.DB.prepare(
          "SELECT slug, hf_id AS id, schema, license, cap, score, downloads, discovered_ts FROM datasets ORDER BY score DESC LIMIT 5000"
        ).all();
        const list = r.results || [];
        ctx.waitUntil(env.CACHE.put("datasets:all", JSON.stringify(list), { expirationTtl: 60 }));
        return json(list);
      }

      // POST /datasets — register or upsert a dataset
      if (path === "/datasets" && request.method === "POST") {
        const b = await request.json().catch(() => ({}));
        if (!b.slug || !b.hf_id) return json({ error: "slug and hf_id required" }, 400);
        await env.DB.prepare(
          "INSERT INTO datasets (slug, hf_id, schema, license, cap, score) VALUES (?1, ?2, ?3, ?4, ?5, ?6) " +
          "ON CONFLICT(slug) DO UPDATE SET hf_id=excluded.hf_id, schema=excluded.schema, license=excluded.license, cap=excluded.cap, score=excluded.score"
        ).bind(b.slug, b.hf_id, b.schema || "messages", b.license || null, b.cap || 50000, b.score || 0.5).run();
        ctx.waitUntil(env.CACHE.delete("datasets:all"));
        return json({ ok: true, slug: b.slug });
      }

      // /cursor/<slug>(/advance)?
      const m = path.match(/^\/cursor\/([^\/]+)(\/advance)?\/?$/);
      if (m) {
        const slug = decodeURIComponent(m[1]);
        const isAdvance = !!m[2] && request.method === "POST";

        if (isAdvance) {
          const b = await request.json().catch(() => ({}));
          const size = Math.max(1, Math.min(100000, parseInt(b.size || 1000)));
          const last = (b.last_batch || "").slice(0, 200);
          // Atomic upsert + increment via D1
          const cur = await env.DB.prepare(
            "INSERT INTO cursors (dataset_id, offset, last_batch) VALUES (?1, ?2, ?3) " +
            "ON CONFLICT(dataset_id) DO UPDATE SET offset = offset + ?2, last_batch = ?3, updated_at = unixepoch() " +
            "RETURNING dataset_id, offset, total, last_batch, updated_at"
          ).bind(slug, size, last).first();
          return json(cur);
        }

        // GET cursor state
        let cur = await env.DB.prepare(
          "SELECT dataset_id, offset, total, last_batch, updated_at FROM cursors WHERE dataset_id = ?"
        ).bind(slug).first();
        if (!cur) cur = { dataset_id: slug, offset: 0, total: null, last_batch: null, updated_at: null };
        return json(cur);
      }

      return json({ error: "not found", path }, 404);
    } catch (e) {
      return json({ error: e.message, stack: e.stack?.split("\n")[0] }, 500);
    }
  },
};
