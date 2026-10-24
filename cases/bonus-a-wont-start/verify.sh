#!/usr/bin/env bash
# Bonus A check.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5710
CASE="bonus a"
WF=InsLabHello000001

state=$(docker compose ps -a --format '{{.Service}}={{.State}}' | grep '^n8n=' | head -1)
[[ "$state" == "n8n=running" ]] || fail "n8n is $state. docker compose logs n8n | head -40"
wait_ready || fail "n8n never became ready"
ok "n8n running and ready"
[[ "$(login)" == "200" ]] || fail "owner login failed"
[[ "$(summary_code)" == "200" ]] || fail "insights is still not loaded. Starting without Insights is the customer's rollback, not the fix."
ok "insights module loaded"
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='$WF' AND active=true;")" != "1" ]]; then
  import_workflows
fi
before=$(raw_for $WF 2); before=${before:-0}
hit hello
wait_raw $WF 2 $((before + 1)) 30 || fail "production run not recorded"
ok "executions recorded"
echo "PASS: bonus a solved."
