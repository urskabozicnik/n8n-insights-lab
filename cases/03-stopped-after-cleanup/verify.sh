#!/usr/bin/env bash
# Case 03 check. Looks at the running stack, not at what you edited.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5703
CASE="case 03"
WF=InsLabHello000001

wait_ready || fail "n8n is not ready on http://localhost:$PORT"
ok "n8n ready"
[[ "$(login)" == "200" ]] || fail "owner login failed"
[[ "$(summary_code)" == "200" ]] || fail "insights module not loaded"
ok "insights module loaded"

# 1. The flush must be clean: no save errors in the last 30 seconds.
sleep 12
if docker compose logs --since=30s n8n 2>/dev/null | grep -q 'Error while saving insights'; then
  fail "the flush is still failing every cycle. docker compose logs --since=1m n8n | grep -i insights"
fi
ok "no insights save errors in the last 30s"

# 2. A new production run reaches insights_raw.
before=$(raw_for $WF 2); before=${before:-0}
hit hello
wait_raw $WF 2 $((before + 1)) 30 || fail "a new run did not reach insights_raw"
ok "new executions are being recorded again"

# 3. And compaction still works end to end.
wait_period $WF 2 $((before + 1)) 150 || fail "run was not compacted into insights_by_period"
ok "compaction folds it into insights_by_period"

echo "PASS: case 03 solved. In the reply: can the compaction job be restarted without a restart, and where did Tuesday-to-today go?"
