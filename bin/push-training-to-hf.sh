#!/usr/bin/env bash
# Push accumulated training pairs from local jsonl → axentx/surrogate-1-training-pairs.
# Uses python HfApi only (CLI syntax changed across versions; not reliable).
# Idempotent: tracks last-pushed line offset so duplicates are skipped.
# Only updates offset if push actually succeeded.
set -uo pipefail
set -a; source "$HOME/.hermes/.env" 2>/dev/null; set +a

SRC="$HOME/.surrogate/training-pairs.jsonl"
OFFSET_FILE="$HOME/.surrogate/.training-push-offset"
LOG="$HOME/.surrogate/logs/training-push.log"
mkdir -p "$(dirname "$LOG")"

[[ ! -f "$SRC" ]] && { echo "[$(date +%H:%M:%S)] no source $SRC" | tee -a "$LOG"; exit 0; }

CUR_LINES=$(wc -l < "$SRC" | tr -d ' ')
PREV_OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
NEW_LINES=$(( CUR_LINES - PREV_OFFSET ))

echo "[$(date +%H:%M:%S)] training push: $NEW_LINES new pairs (offset=$PREV_OFFSET, total=$CUR_LINES)" | tee -a "$LOG"
[[ $NEW_LINES -le 0 ]] && exit 0

# Resolve token from any HF env var name
HF_AUTH="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-${HUGGINGFACE_TOKEN:-}}}"
if [[ -z "$HF_AUTH" ]]; then
    echo "[$(date +%H:%M:%S)] ERR: no HF_TOKEN env — cannot upload" | tee -a "$LOG"
    exit 1
fi

# Slice new pairs to a date-stamped file
DATE_TAG=$(date +%Y-%m-%d)
SLICE="$HOME/.surrogate/.push-slice-${DATE_TAG}.jsonl"
tail -n "$NEW_LINES" "$SRC" >> "$SLICE"

# Upload via python HfApi (explicit token, explicit error handling)
if HF_AUTH="$HF_AUTH" python3 - "$SLICE" "$NEW_LINES" "$DATE_TAG" >> "$LOG" 2>&1 <<'PYEOF'
import sys, os, json, hashlib, time
from pathlib import Path
slice_path, n_pairs, date_tag = sys.argv[1], int(sys.argv[2]), sys.argv[3]
hf_auth = os.environ["HF_AUTH"]

try:
    from huggingface_hub import HfApi
except ImportError:
    print(f"[{time.strftime('%H:%M:%S')}] ERR: huggingface_hub not installed")
    sys.exit(2)

# Append to a daily file rather than overwrite — accumulate across pushes
api = HfApi(token=hf_auth)
remote_path = f"auto-orchestrate-{date_tag}.jsonl"
try:
    # Check if remote file exists; if yes, fetch + concat to avoid losing prior pushes
    try:
        existing = api.hf_hub_download(
            repo_id="axentx/surrogate-1-training-pairs",
            filename=remote_path,
            repo_type="dataset",
            local_dir="/tmp/hf-push-cache",
            local_dir_use_symlinks=False,
        )
        # Concat: existing + slice → new payload
        merged = Path("/tmp/hf-push-cache") / f"merged-{remote_path}"
        with open(merged, "wb") as out:
            out.write(Path(existing).read_bytes())
            out.write(Path(slice_path).read_bytes())
        upload_path = str(merged)
    except Exception:
        upload_path = slice_path

    api.upload_file(
        path_or_fileobj=upload_path,
        path_in_repo=remote_path,
        repo_id="axentx/surrogate-1-training-pairs",
        repo_type="dataset",
        commit_message=f"auto-orchestrate: +{n_pairs} pairs ({time.strftime('%H:%M')})",
    )
    print(f"[{time.strftime('%H:%M:%S')}] ✅ uploaded {n_pairs} new pairs to {remote_path}")
    sys.exit(0)
except Exception as e:
    print(f"[{time.strftime('%H:%M:%S')}] ❌ {type(e).__name__}: {str(e)[:300]}")
    sys.exit(3)
PYEOF
then
    # Only advance offset on actual upload success
    echo "$CUR_LINES" > "$OFFSET_FILE"
    rm -f "$SLICE"
    echo "[$(date +%H:%M:%S)] push complete · offset → $CUR_LINES" | tee -a "$LOG"
else
    echo "[$(date +%H:%M:%S)] push failed — offset unchanged ($PREV_OFFSET), slice retained for retry" | tee -a "$LOG"
    exit 1
fi
