#!/usr/bin/env bash
# Case 05 check. There is nothing to fix. This checks the stack is healthy, the
# two numbers from the ticket are reproducible, and you have not deleted data
# to make them agree.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5705
CASE="case 05"
WF=InsLabHello000001

wait_ready || fail "n8n is not ready on http://localhost:$PORT"
ok "n8n ready"
[[ "$(login)" == "200" ]] || fail "owner login failed"
[[ "$(summary_code)" == "200" ]] || fail "insights module not loaded (did you disable it? that is not the fix)"
ok "insights module loaded"

ins=$(period_for $WF 2); ins=${ins:-0}
raw=$(raw_for $WF 2); raw=${raw:-0}
total=$((ins + raw))
listed=$(q "SELECT COUNT(*) FROM execution_entity WHERE \"workflowId\"='$WF' AND \"deletedAt\" IS NULL;")
all=$(q "SELECT COUNT(*) FROM execution_entity WHERE \"workflowId\"='$WF';")

echo "  insights (by_period + raw, type success):  $total"
echo "  executions list (not soft-deleted):        ${listed:-0}"
echo "  execution_entity rows incl. soft-deleted:  ${all:-0}"

[[ "$total" -ge 100 ]] || fail "insights history has shrunk to $total. Deleting insights data is not the fix for this ticket."
ok "insights history intact"
[[ "${listed:-0}" -le 60 ]] || fail "the executions list now shows ${listed} rows: you changed the customer's pruning, which was not broken. Put it back."
ok "customer's execution pruning untouched"

echo "PASS: case 05, nothing was broken. Now write the reply: which number is right, why the other is lower, were they overbilled, and where the billing number actually lives."
