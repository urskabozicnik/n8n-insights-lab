#!/usr/bin/env bash
# Reference stack check. Fires one production webhook and follows it through
# the whole Insights pipeline. Every query in here is one you will use today.
set -uo pipefail
cd "$(dirname "$0")"
source ../tools/lib.sh
PORT=5678
CASE="reference stack"
WF=InsLabHello000001

# 1. Both containers up.
running=$(docker compose ps --status running --format '{{.Service}}' | sort | tr '\n' ' ')
[[ "$running" == *n8n* && "$running" == *postgres* ]] \
  || fail "expected both containers running, got: ${running:-none}"
ok "both containers running"

# 2. Readiness, never /healthz.
wait_ready || fail "http://localhost:$PORT/healthz/readiness is not returning 200"
ok "n8n ready on http://localhost:$PORT/healthz/readiness"

# 3. Owner login.
[[ "$(login)" == "200" ]] || fail "login as $EMAIL failed"
ok "owner login works ($EMAIL / $PASSWORD)"

# 4. The module is loaded. 404 here means N8N_DISABLED_MODULES contains insights
#    (or the module failed to load; read the top of the n8n log).
code=$(summary_code)
[[ "$code" == "200" ]] || fail "GET /rest/insights/summary returned $code, expected 200"
ok "insights module loaded (GET /rest/insights/summary -> 200)"

# 5. Seed workflow present and active. First run imports it.
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='$WF' AND active=true;")" != "1" ]]; then
  import_workflows
fi
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/webhook/hello")
[[ "$code" == "200" ]] || fail "production webhook /webhook/hello returned $code"
ok "hello-webhook is active and answers"

# 6. Stage one: the flush. One production run = one type-2 (success) raw row.
before=$(raw_for $WF 2); before=${before:-0}
hit hello
wait_raw $WF 2 $((before + 1)) 30 \
  || fail "no new success row in insights_raw after 30s. Flush is broken, or the run was not a production run."
ok "1 production execution landed in insights_raw (type 2 = success)"

# 7. Stage two: compaction. Within ~a minute the raw row is folded into
#    insights_by_period, which is the only table the dashboard reads.
pbefore=$(period_for $WF 2); pbefore=${pbefore:-0}
wait_period $WF 2 $((before + 1)) 150 \
  || fail "insights_by_period did not pick up the run within 150s. Compaction is not running."
ok "compaction folded it into insights_by_period"

echo "PASS: reference stack healthy, open http://localhost:$PORT"
