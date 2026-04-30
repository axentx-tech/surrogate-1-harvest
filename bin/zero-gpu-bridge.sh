#!/usr/bin/env bash
# ZeroGPU bridge — calls our own Surrogate-1 Space (ashirato/surrogate-1-zero-gpu)
# which serves Qwen2.5-Coder-7B + Surrogate-1 v1 LoRA on free PRO ZeroGPU A10G.
#
# Cold-start ~5-10s, then 60-120s of GPU per request. Up to 25K GPU-min/mo
# total under PRO subscription.
#
# Usage:
#   echo "<prompt>" | zero-gpu-bridge.sh [--max-tokens N] [--temperature T]
set -u
SPACE_URL="${ZERO_GPU_SPACE_URL:-https://ashirato-surrogate-1-zero-gpu.hf.space}"
MAX_TOKENS=512
TEMP=0.4
TOP_P=0.9
PROMPT=""
HISTORY="[]"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-tokens) MAX_TOKENS="$2"; shift 2 ;;
        --temperature) TEMP="$2"; shift 2 ;;
        --top-p) TOP_P="$2"; shift 2 ;;
        --space-url) SPACE_URL="$2"; shift 2 ;;
        *) PROMPT="$*"; break ;;
    esac
done
[[ -z "$PROMPT" ]] && [[ ! -t 0 ]] && PROMPT=$(cat)
[[ -z "$PROMPT" ]] && { echo "zero-gpu-bridge: no prompt" >&2; exit 2; }

LOG="$HOME/.surrogate/logs/zero-gpu-bridge.log"
mkdir -p "$(dirname "$LOG")"
[[ -f "$HOME/.hermes/.env" ]] && { set -a; source "$HOME/.hermes/.env"; set +a; }

HF_TOKEN_USE="${HF_TOKEN_PRO:-${HF_TOKEN:-}}"
echo "[$(date '+%H:%M:%S')] space=$SPACE_URL len=${#PROMPT}" >> "$LOG"

RESPONSE=$(SPACE="$SPACE_URL" MAX_TOKENS="$MAX_TOKENS" TEMP="$TEMP" TOP_P="$TOP_P" \
    HF_TOKEN_USE="$HF_TOKEN_USE" \
python3 -c "
import json, os, re, sys, urllib.request, urllib.error
prompt = sys.stdin.read()
space = os.environ['SPACE']
# Gradio 4.44 with .queue() rejects POST /api/predict and POST
# /run/<api_name> ('This API endpoint does not accept direct HTTP POST
# requests. Please join the queue.') — must use /call/<api_name> with
# event_id polling. The Space app.py exposes api_name='respond' for
# the chat function (signature: respond(message) -> str).
hdr = {'Content-Type':'application/json'}
tok = os.environ.get('HF_TOKEN_USE','')
if tok: hdr['Authorization'] = 'Bearer ' + tok

# Step 1: enqueue
try:
    req = urllib.request.Request(
        f'{space}/call/respond',
        data=json.dumps({'data':[prompt]}).encode(), headers=hdr)
    with urllib.request.urlopen(req, timeout=30) as r:
        eid = json.load(r).get('event_id','')
except urllib.error.HTTPError as e:
    print(f'zero-gpu-bridge HTTP {e.code} (enqueue): {e.read().decode(\"utf-8\",\"ignore\")[:300]}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'zero-gpu-bridge enqueue error: {e}', file=sys.stderr); sys.exit(1)

if not eid:
    print('zero-gpu-bridge: no event_id', file=sys.stderr); sys.exit(1)

# Step 2: poll SSE stream until 'event: complete'. Cold-start ~30-60s
# for 7B+LoRA load; warm 5-15s for chat.
try:
    req = urllib.request.Request(f'{space}/call/respond/{eid}', headers=hdr)
    with urllib.request.urlopen(req, timeout=240) as r:
        body = r.read().decode('utf-8','ignore')
    blocks = re.findall(r'event:\s*complete\s*\ndata:\s*(.*)', body)
    if not blocks:
        # surface error events when present
        errs = re.findall(r'event:\s*error\s*\ndata:\s*(.*)', body)
        if errs:
            print(f'zero-gpu-bridge SSE error: {errs[-1][:300]}', file=sys.stderr)
        else:
            print(f'zero-gpu-bridge: no complete event in {len(body)}b', file=sys.stderr)
        sys.exit(1)
    payload = json.loads(blocks[-1])
    out = payload[0] if isinstance(payload, list) and payload else ''
    if isinstance(out, str):
        print(out); sys.exit(0)
    print(f'zero-gpu-bridge: unexpected payload {str(payload)[:200]}', file=sys.stderr)
    sys.exit(1)
except urllib.error.HTTPError as e:
    print(f'zero-gpu-bridge HTTP {e.code} (poll): {e.read().decode(\"utf-8\",\"ignore\")[:300]}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'zero-gpu-bridge poll error: {e}', file=sys.stderr); sys.exit(1)
" <<< "$PROMPT")
RC=$?
echo "[$(date '+%H:%M:%S')] rc=$RC bytes=${#RESPONSE}" >> "$LOG"
[[ $RC -ne 0 ]] && exit $RC
echo "$RESPONSE"
