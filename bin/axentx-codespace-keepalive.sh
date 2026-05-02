#!/usr/bin/env bash
# axentx-codespace-keepalive.sh — keeps the ENTIRE codespace LLM fleet warm
# during business hours. Reads CS_FLEET (TSV: tok<TAB>name<TAB>account, one
# per line) and pings every endpoint in turn.
#
# Account policy (2026-05-02):
#   ashirap         — FORBIDDEN
#   midnightcrisis  — quota exhausted this month
#   ashirapit, midnightgts, luckyburster-lab, surrogate-1, axentx-tech,
#   arkship-ai, ifusefreedomza — codespace-eligible. Each gets 60h/mo.
#
# Strategy:
#   - During WORKING_HOURS_UTC (default 0–12 UTC ≈ 7am–7pm Bangkok), ping
#     each endpoint every PING_SEC. Auto-start any that's not Available.
#   - Outside hours: silent. Codespaces auto-stop at 30min idle.
#   - Failure on one endpoint never blocks the rest (set +e in the loop).
#
# Required env:
#   CS_FLEET                 multiline TSV "<token><TAB><cs-name><TAB><account>"
#                            (CRLF / multiline both fine)
set -u +e

CS_FLEET="${CS_FLEET:-}"
PING_SEC="${PING_SEC:-1200}"
WHS="${WHS:-0}"
WHE="${WHE:-12}"
LOG_FILE="${LOG_FILE:-}"

log() {
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG_FILE"
    else
        echo "[$(date -u +%FT%TZ)] $*"
    fi
}

if [ -z "$CS_FLEET" ]; then
    log "FATAL: CS_FLEET env not set (multiline TSV: token<TAB>cs-name<TAB>account)"
    exit 1
fi

# Number of codespaces in the fleet
N=$(echo "$CS_FLEET" | grep -c '	')
log "start — fleet keepalive over $N codespaces (every ${PING_SEC}s, ${WHS}–${WHE} UTC)"

while true; do
    h=$(date -u +%H | sed 's/^0//')
    h=${h:-0}
    if [ "$h" -ge "$WHS" ] 2>/dev/null && [ "$h" -lt "$WHE" ] 2>/dev/null; then
        # Iterate fleet members. Each line: TOKEN \t CS_NAME \t ACCOUNT
        echo "$CS_FLEET" | while IFS=$'\t' read -r tok name acct; do
            [ -n "$tok" ] && [ -n "$name" ] || continue
            url="https://${name}-11434.app.github.dev"
            state=$(GH_TOKEN=$tok gh codespace view -c "$name" --json state -q .state 2>/dev/null || echo "unknown")
            if [ "$state" != "Available" ]; then
                log "  [$acct] state=$state — starting"
                GH_TOKEN=$tok gh codespace start -c "$name" >/dev/null 2>&1
                sleep 10
            fi
            r=$(curl -s -o /dev/null -w "%{http_code}/%{time_total}s" -m 12 "$url/api/tags" 2>/dev/null || echo "fail")
            log "  [$acct/$name] $state → $r"
        done
    else
        log "  outside hours (h=$h)"
    fi
    sleep "$PING_SEC"
done
