#!/usr/bin/env bash
# Surrogate-1 dataset enricher — pulls top 5 public datasets, dedup, merge into axentx/surrogate-1-training-pairs.
#
# Sources (commercially licensed, high quality):
#   1. ise-uiuc/Magicoder-OSS-Instruct-75K        MIT      (code instructions)
#   2. ise-uiuc/Magicoder-Evol-Instruct-110K      Apache   (evolved code)
#   3. theblackcat102/evol-codealpaca-v1          Apache   (general code Q&A)
#   4. HuggingFaceH4/ultrachat_200k               MIT      (multi-turn chat)
#   5. OpenAssistant/oasst1                        Apache   (assistant)
#
# Run: dataset-enrich.sh
# Output: enriched dataset with dedup against existing axentx pairs.
set -uo pipefail
set -a; source "$HOME/.hermes/.env" 2>/dev/null; set +a

LOG="$HOME/.claude/logs/dataset-enrich.log"
WORK="$HOME/.hermes/workspace/dataset-enrich"
mkdir -p "$WORK" "$(dirname "$LOG")"

echo "[$(date +%H:%M:%S)] dataset enrich start" | tee "$LOG"

~/.claude/venv/bin/python <<'PYEOF' 2>&1 | tee -a "$LOG"
from huggingface_hub import HfApi, snapshot_download
from pathlib import Path
from datasets import load_dataset
import hashlib, json, time

WORK = Path("/Users/Ashira/.hermes/workspace/dataset-enrich")
WORK.mkdir(parents=True, exist_ok=True)
api = HfApi()

DATASETS = [
    ("ise-uiuc/Magicoder-OSS-Instruct-75K", "MIT",     "magicoder-oss"),
    ("theblackcat102/evol-codealpaca-v1",   "Apache",  "evol-codealpaca"),
    ("HuggingFaceH4/ultrachat_200k",         "MIT",    "ultrachat"),
    # ise-uiuc/Magicoder-Evol-Instruct-110K  - large, do separately if first 3 work
]

# 1. Build dedup set from existing axentx pairs (hash of prompt)
existing_hashes = set()
print("Loading existing axentx training pairs for dedup...", flush=True)
src = Path.home() / 'axentx/surrogate/data/training-jsonl'
for jsonl_file in src.glob('*.jsonl'):
    if 'thinkbit' in jsonl_file.name or 'fs-code' in jsonl_file.name:
        continue
    try:
        with open(jsonl_file) as f:
            for i, line in enumerate(f):
                if i > 50000: break  # cap per file
                try:
                    d = json.loads(line)
                    text = d.get('prompt') or d.get('instruction') or (d.get('messages',[{}])[0].get('content','') if d.get('messages') else '')
                    if text:
                        existing_hashes.add(hashlib.md5(text[:200].encode()).hexdigest()[:16])
                except: pass
    except: pass
print(f"  loaded {len(existing_hashes):,} existing prompt hashes for dedup", flush=True)

# 2. Pull each dataset, normalize, dedup
new_pairs_total = 0
out_path = WORK / "merged-public-dedup.jsonl"
out_path.parent.mkdir(parents=True, exist_ok=True)

with open(out_path, "w") as out:
    for ds_id, license_, slug in DATASETS:
        print(f"\n--- {ds_id} ({license_}) ---", flush=True)
        try:
            t0 = time.time()
            # Use streaming to avoid downloading huge files
            ds = load_dataset(ds_id, split="train", streaming=True)
            kept = 0; dup = 0; total = 0
            for row in ds:
                total += 1
                if total > 250000: break  # 250K cap per dataset

                # Normalize different schemas → unified format
                prompt = ""
                response = ""
                if "instruction" in row and "response" in row:
                    prompt = str(row["instruction"])
                    response = str(row["response"])
                elif "problem" in row and "solution" in row:
                    prompt = str(row["problem"])
                    response = str(row["solution"])
                elif "messages" in row:
                    msgs = row["messages"]
                    if len(msgs) >= 2:
                        prompt = str(msgs[0].get("content", ""))
                        response = str(msgs[1].get("content", ""))
                else:
                    continue

                if not prompt or not response or len(prompt) < 20 or len(response) < 20:
                    continue

                h = hashlib.md5(prompt[:200].encode()).hexdigest()[:16]
                if h in existing_hashes:
                    dup += 1
                    continue
                existing_hashes.add(h)

                out.write(json.dumps({
                    "source": slug,
                    "license": license_,
                    "prompt": prompt[:4000],
                    "response": response[:8000],
                    "messages": [
                        {"role": "user",      "content": prompt[:4000]},
                        {"role": "assistant", "content": response[:8000]},
                    ],
                }, ensure_ascii=False) + "\n")
                kept += 1
            elapsed = time.time() - t0
            print(f"  total scanned: {total}, kept: {kept}, dedup: {dup}, time: {elapsed:.0f}s", flush=True)
            new_pairs_total += kept
        except Exception as e:
            print(f"  ❌ {type(e).__name__}: {str(e)[:200]}", flush=True)
            continue

print(f"\n=== Total new pairs after dedup: {new_pairs_total:,} ===", flush=True)
print(f"Output: {out_path} ({out_path.stat().st_size/1024/1024:.1f} MB)", flush=True)

# 3. Push to axentx/surrogate-1-training-pairs as new file
if new_pairs_total > 0:
    repo_path = f"public-merged-dedup-{time.strftime('%Y-%m-%d')}.jsonl"
    print(f"\nUploading {repo_path} to axentx/surrogate-1-training-pairs...", flush=True)
    api.upload_file(
        path_or_fileobj=str(out_path),
        path_in_repo=repo_path,
        repo_id="axentx/surrogate-1-training-pairs",
        repo_type="dataset",
        commit_message=f"Public datasets dedup-merged: {new_pairs_total} new pairs"
    )
    print(f"✅ uploaded → axentx/surrogate-1-training-pairs/{repo_path}", flush=True)
PYEOF

echo "[$(date +%H:%M:%S)] dataset enrich done" | tee -a "$LOG"
