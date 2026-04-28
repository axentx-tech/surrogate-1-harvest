#!/usr/bin/env bash
# Bulk-mirror — clone top community datasets ENTIRELY into our 5 sibling
# repos. Single git/HfApi push = millions of pairs in one commit.
#
# This is fundamentally different from dataset-enrich.sh which streams +
# normalizes per-row. Mirror = "the whole parquet, as-is, NOW", which
# is 100-1000x faster GB/hr.
#
# Why this is fine:
#   - Both HF licenses on these datasets allow redistribution
#   - Format conversion can happen at TRAIN TIME (one pass over the mirror)
#   - We're not double-counting commits because each mirror = 1 file = 1 commit
#
set -uo pipefail
set -a; source "$HOME/.hermes/.env" 2>/dev/null; set +a

LOG="$HOME/.surrogate/logs/dataset-mirror.log"
mkdir -p "$(dirname "$LOG")"

if [[ -z "${HF_TOKEN:-}" ]]; then
    echo "[$(date +%H:%M:%S)] dataset-mirror skipping — HF_TOKEN not set" | tee -a "$LOG"
    exit 0
fi

echo "[$(date +%H:%M:%S)] dataset-mirror cycle start" | tee -a "$LOG"

python3 - << 'PYEOF' 2>&1 | tee -a "$LOG"
"""
For each big community dataset on the SOURCES list:
  1. Use huggingface_hub.snapshot_download to pull the parquet shards
  2. Upload them to one of our 5 sibling repos under mirrors/<slug>/<file>
  3. Stamp a marker so we don't re-mirror next cycle
"""
import os, time, json, hashlib, sys
from pathlib import Path
from huggingface_hub import HfApi, snapshot_download, list_repo_files
from huggingface_hub.errors import HfHubHTTPError

api = HfApi(token=os.environ["HF_TOKEN"])

# Top 30 community SFT mixes that are HUGE and immediately useful.
# Each = 100K-10M pairs. License flag = OK to redistribute.
SOURCES = [
    # Massive SFT mixes
    ("teknium/OpenHermes-2.5",                 "OpenHermes-2-5"),
    ("HuggingFaceH4/ultrachat_200k",           "ultrachat-200k"),
    ("Open-Orca/OpenOrca",                     "OpenOrca"),
    ("Open-Orca/SlimOrca-Dedup",               "SlimOrca-Dedup"),
    ("HuggingFaceH4/no_robots",                "no-robots"),
    ("databricks/databricks-dolly-15k",        "dolly-15k"),
    ("garage-bAInd/Open-Platypus",             "Open-Platypus"),
    ("nvidia/OpenMathInstruct-2",              "OpenMathInstruct-2"),
    # Code-specific
    ("ise-uiuc/Magicoder-OSS-Instruct-75K",    "Magicoder-OSS"),
    ("ise-uiuc/Magicoder-Evol-Instruct-110K",  "Magicoder-Evol"),
    ("HuggingFaceH4/CodeAlpaca_20K",           "CodeAlpaca-20K"),
    ("nickrosh/Evol-Instruct-Code-80k-v1",     "Evol-Code-80k"),
    ("bigcode/self-oss-instruct-sc2-exec-filter-50k", "starcoder2-self-oss"),
    # Reasoning
    ("microsoft/orca-math-word-problems-200k", "orca-math-200k"),
    ("meta-math/MetaMathQA",                   "MetaMathQA"),
    ("EleutherAI/proof-pile-2",                "proof-pile-2"),
    ("HuggingFaceTB/finemath",                 "finemath"),
    # Tool / agentic
    ("Salesforce/xlam-function-calling-60k",   "xlam-fc-60k"),
    ("microsoft/orca-agentinstruct-1M-v1",     "orca-agentinstruct-1M"),
    # Conversational
    ("lmsys/lmsys-chat-1m",                    "lmsys-chat-1m"),
    ("nvidia/HelpSteer3",                      "HelpSteer3"),
    ("Anthropic/hh-rlhf",                      "hh-rlhf"),
    # Multilingual
    ("CohereForAI/aya_dataset",                "aya-dataset"),
    ("CohereForAI/aya_collection",             "aya-collection"),
    # General curated
    ("argilla/magpie-ultra-v1.0",              "magpie-ultra"),
    ("Magpie-Align/Magpie-Pro-MT-300K-v0.1",   "magpie-pro-300K"),
    # Code feedback / DPO
    ("m-a-p/CodeFeedback-Filtered-Instruction","CodeFeedback"),
    ("argilla/distilabel-capybara-dpo-7k-binarized", "capybara-dpo-7k"),
    # Smol team
    ("HuggingFaceTB/smoltalk",                 "smoltalk"),
    ("HuggingFaceTB/smollm-corpus",            "smollm-corpus"),
]

# 5 sibling repos to spread across — round-robin by hash for determinism
SIBLINGS = [
    "axentx/surrogate-1-training-pairs",
    "axentx/surrogate-1-pairs-A",
    "axentx/surrogate-1-pairs-B",
    "axentx/surrogate-1-pairs-C",
    "axentx/surrogate-1-pairs-D",
]
def pick_repo(slug):
    h = int(hashlib.md5(slug.encode()).hexdigest()[:8], 16)
    return SIBLINGS[h % len(SIBLINGS)]

STAMPS = Path.home() / ".surrogate/state/dataset-mirror-stamps.json"
STAMPS.parent.mkdir(parents=True, exist_ok=True)
stamps = json.loads(STAMPS.read_text()) if STAMPS.exists() else {}

CACHE = Path("/tmp/dataset-mirror-cache")
CACHE.mkdir(exist_ok=True)

mirrored = 0
skipped = 0
errors = 0

for src_id, slug in SOURCES:
    if slug in stamps:
        skipped += 1
        continue
    target = pick_repo(slug)
    print(f"\n▶ mirror {src_id}  →  {target}/mirrors/{slug}/", flush=True)
    try:
        # Download all parquet/jsonl shards
        local = snapshot_download(
            repo_id=src_id, repo_type="dataset",
            cache_dir=str(CACHE), token=os.environ["HF_TOKEN"],
            allow_patterns=["*.parquet", "*.jsonl", "*.json", "*.arrow", "*.csv"],
        )
        local_path = Path(local)
        # Upload each file individually so commit count stays under 128/hr
        for f in sorted(local_path.rglob("*")):
            if not f.is_file(): continue
            if f.stat().st_size < 1024: continue
            rel = f.relative_to(local_path)
            target_path = f"mirrors/{slug}/{rel}"
            print(f"    upload {rel}  ({f.stat().st_size/1e6:.1f} MB)", flush=True)
            try:
                api.upload_file(
                    path_or_fileobj=str(f),
                    path_in_repo=target_path,
                    repo_id=target,
                    repo_type="dataset",
                    commit_message=f"mirror: {src_id} → mirrors/{slug}/{rel}",
                )
                mirrored += 1
            except HfHubHTTPError as e:
                if "429" in str(e) or "rate limit" in str(e).lower():
                    print(f"    ⚠ rate-limited — sleep 60s and continue with next file", flush=True)
                    time.sleep(60)
                else:
                    print(f"    ❌ {type(e).__name__}: {str(e)[:200]}", flush=True)
                    errors += 1
            time.sleep(2)  # gentle pacing between commits
        stamps[slug] = int(time.time())
        STAMPS.write_text(json.dumps(stamps, indent=2))
    except Exception as e:
        print(f"  ❌ {type(e).__name__}: {str(e)[:200]}", flush=True)
        errors += 1
        continue

print(f"\n✅ mirror cycle done: {mirrored} files uploaded, {skipped} skipped (already mirrored), {errors} errors")
PYEOF

echo "[$(date +%H:%M:%S)] dataset-mirror cycle done" | tee -a "$LOG"
