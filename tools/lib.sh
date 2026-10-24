#!/usr/bin/env bash
# Shared helpers for setup.sh and verify.sh. Source it from a case directory:
#
#   source ../../tools/lib.sh
#
# Everything here talks to the stack in the CURRENT directory (docker compose
# finds the project from the compose.yaml next to you) and to n8n on $PORT.
# Nothing here is part of any puzzle; read it freely.

EMAIL=${EMAIL:-owner@example.com}
PASSWORD=${PASSWORD:-InsightsLab2026}
COOKIES=${COOKIES:-/tmp/inslab-cookies-$$.txt}

# ---- http -------------------------------------------------------------------

# wait_ready: poll /healthz/readiness (never /healthz) for up to 3 minutes.
wait_ready() {
  for _ in $(seq 1 90); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/healthz/readiness")
    [[ "$code" == "200" ]] && return 0
    sleep 2
  done
  return 1
}

# login: cookie-based session as the pre-provisioned owner.
login() {
  curl -s -o /dev/null -c "$COOKIES" -X POST "http://localhost:$PORT/rest/login" \
    -H 'Content-Type: application/json' \
    -d "{\"emailOrLdapLoginId\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" -w '%{http_code}'
}

# summary_code: HTTP status of the Insights summary endpoint. 200 = module loaded
# and the caller may see the summary. 404 = module not loaded. 403 = not allowed.
summary_code() {
  curl -s -o /dev/null -b "$COOKIES" -w '%{http_code}' "http://localhost:$PORT/rest/insights/summary"
}

# summary: the JSON body.
summary() {
  curl -s -b "$COOKIES" "http://localhost:$PORT/rest/insights/summary"
}

# hit <path> [n]: call a PRODUCTION webhook n times (default 1). The test URL
# (/webhook-test/) would be mode=manual and never reach Insights.
hit() {
  local path=$1 n=${2:-1} i
  for i in $(seq 1 "$n"); do
    curl -s -o /dev/null "http://localhost:$PORT/webhook/$path"
  done
}

# ---- database ---------------------------------------------------------------

# q <sql>: one-shot psql, tuples only, no alignment.
q() {
  docker compose exec -T postgres psql -U "${POSTGRES_USER:-n8n}" -d "${POSTGRES_DB:-n8n}" -tAc "$1" 2>/dev/null
}

raw_count()      { q "SELECT COUNT(*) FROM insights_raw;"; }
period_count()   { q "SELECT COUNT(*) FROM insights_by_period;"; }
raw_for()        { q "SELECT COUNT(*) FROM insights_raw ir JOIN insights_metadata im ON ir.\"metaId\"=im.\"metaId\" WHERE im.\"workflowId\"='$1' AND ir.type=${2:-2};"; }
period_for()     { q "SELECT COALESCE(SUM(value),0) FROM insights_by_period bp JOIN insights_metadata im ON bp.\"metaId\"=im.\"metaId\" WHERE im.\"workflowId\"='$1' AND bp.type=${2:-2};"; }

# wait_raw <workflowId> <type> <min> [seconds]: wait until at least <min> raw rows
# of that type exist for the workflow. Default budget 30s (flush is 5s in the lab).
wait_raw() {
  local wf=$1 type=$2 min=$3 budget=${4:-30} n
  for _ in $(seq 1 "$budget"); do
    n=$(raw_for "$wf" "$type"); n=${n:-0}
    [[ "$n" -ge "$min" ]] && return 0
    sleep 1
  done
  return 1
}

# wait_period <workflowId> <type> <min> [seconds]: wait until the compacted sum
# reaches <min>. Default budget 150s (compaction is every minute in the lab, and
# the first run after boot can be up to a minute away).
wait_period() {
  local wf=$1 type=$2 min=$3 budget=${4:-150} n
  for _ in $(seq 1 "$budget"); do
    n=$(period_for "$wf" "$type"); n=${n:-0}
    [[ "$n" -ge "$min" ]] && return 0
    sleep 1
  done
  return 1
}

# ---- workflows --------------------------------------------------------------

# import_workflows: import every JSON in ./workflows via the n8n CLI inside the
# container, assigned to the owner, then activate the ones whose JSON says
# "active": true. IDs are fixed in the JSON so scripts can refer to them.
import_workflows() {
  local f id active
  docker compose exec -T n8n n8n import:workflow --separate --input=/workflows >/dev/null
  for f in workflows/*.json; do
    id=$(sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' "$f" | head -1)
    active=$(grep -c '"active": *true' "$f" || true)
    if [[ "$active" -gt 0 ]]; then
      docker compose exec -T n8n n8n update:workflow --id="$id" --active=true >/dev/null
    fi
  done
  # Activation via CLI takes effect on the next boot of the main process.
  docker compose restart n8n >/dev/null
  wait_ready
}

# ---- output -----------------------------------------------------------------

ok()   { echo "✓ $1"; }
fail() { echo "✗ $1"; echo "FAIL: ${CASE:-this case} not solved"; exit 1; }
