#!/usr/bin/env bash
# Case 01 check. Looks at the running stack, not at what you edited.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5701
CASE="case 01"
WF=InsLabHello000001

wait_ready || fail "n8n is not ready on http://localhost:$PORT. Try: docker compose logs --tail=30 n8n"
ok "n8n ready"

[[ "$(login)" == "200" ]] || fail "owner login failed"

# The summary endpoint only exists when the module is loaded. 404 = not loaded.
code=$(summary_code)
[[ "$code" == "200" ]] || fail "GET /rest/insights/summary returned $code. The insights module is not loaded on this instance."
ok "insights module loaded (summary endpoint -> 200)"

# And it must actually collect: one production run, one success row.
before=$(raw_for $WF 2); before=${before:-0}
hit hello
wait_raw $WF 2 $((before + 1)) 30 || fail "a production webhook run did not reach insights_raw"
ok "production executions are being recorded again"

echo "PASS: case 01 solved. Now: is this a Community limitation? Say so in the reply, one way or the other."
