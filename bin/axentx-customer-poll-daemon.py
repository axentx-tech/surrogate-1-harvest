#!/usr/bin/env python3
"""axentx customer-poll — weekly Discord poll for ground-truth product validation.

Every 7 days, picks the highest-priority BUILD-verdict opportunity from
the last week (business-queue done items), generates 3 short Discord
poll questions about it, posts to the configured webhook. Stores question
+ thread URL in D1 cursor so a future answer-collection step can fetch
the human verdict. Today: post-only (collection is manual)."""
from __future__ import annotations
import datetime, json, os, sys, urllib.request
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from axentx_pipeline import REPO_ROOT, log, call_llm, daemon_loop
POLL_SEC = int(os.environ.get("CUSTOMER_POLL_SEC", "604800"))  # 7 days

DISCORD = os.environ.get("DISCORD_WEBHOOK","")
SYS = """Generate 3 Discord poll questions to validate this product hypothesis with real users.
Each question: ≤140 chars, asks about the user's actual behavior (not opinion).
Output JSON: {"questions":["...","...","..."],"options_per_q":["yes","no","maybe"]}"""

def post_discord(text: str):
    if not DISCORD: return
    body = json.dumps({"content": text[:1800]}).encode()
    req = urllib.request.Request(DISCORD, data=body,
        headers={"Content-Type":"application/json",
                 "User-Agent":"DiscordBot (https://github.com/arkashira/surrogate-1-harvest, 1.0)"})
    try: urllib.request.urlopen(req, timeout=8).read()
    except Exception as e: log("customer-poll", f"discord fail: {e}")

def do_one() -> bool:
    done_dir = REPO_ROOT/"state"/"swarm-shared"/"done"
    if not done_dir.exists(): return False
    week_ago = datetime.datetime.utcnow().timestamp() - 7*86400
    builds = []
    for p in done_dir.glob("*.json"):
        if p.stat().st_mtime < week_ago: continue
        try:
            it = json.loads(p.read_text())
            biz = it.get("business_verdict",{}) or {}
            if (biz.get("verdict") or "").upper() == "BUILD":
                builds.append(it)
        except: continue
    if not builds:
        log("customer-poll","no BUILD opportunities this week")
        return False
    # pick the highest sev pain
    builds.sort(key=lambda i: -(i.get("verdict",{}).get("severity",0)))
    item = builds[0]
    bd = item.get("bd_verdict",{}) or {}
    ctx = (
        f"Hypothesis: {bd.get('feature_one_liner') or bd.get('new_product_one_liner','?')}\n"
        f"Audience: {item.get('verdict',{}).get('audience','?')}\n"
    )
    try:
        out = call_llm(ctx, system=SYS, max_tokens=400, timeout=30)
        txt = out.strip()
        if "```" in txt: txt = txt.split("```")[1]
        if txt.startswith("json"): txt = txt[4:]
        d = json.loads(txt.strip())
    except Exception as e:
        log("customer-poll", f"llm fail: {e}")
        return False
    msg = (
        f"**🔬 Weekly customer poll**\n\n"
        f"Hypothesis: {bd.get('feature_one_liner') or bd.get('new_product_one_liner','')}\n\n" +
        "\n".join(f"**Q{i+1}:** {q}" for i,q in enumerate(d.get("questions",[]))) +
        f"\n\n_Reply yes/no/maybe in this thread to validate or reject._"
    )
    post_discord(msg)
    log("customer-poll", f"✓ posted to Discord: {item['id'][:30]}")
    return True

if __name__ == "__main__":
    daemon_loop("customer-poll", POLL_SEC, do_one)
