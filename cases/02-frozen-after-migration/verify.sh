#!/usr/bin/env bash
# Case 02 check. Looks at the running stack, not at what you edited.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5702
CASE="case 02"
WF=InsLabHello000001

wait_ready || fail "n8n is not ready on http://localhost:$PORT"
ok "n8n ready"
[[ "$(login)" == "200" ]] || fail "owner login failed"
[[ "$(summary_code)" == "200" ]] || fail "insights module not loaded"
ok "insights module loaded"

# New run must reach raw (flush is fine in this case) AND be compacted.
before=$(period_for $WF 2); before=${before:-0}
rawbefore=$(raw_count)
hit hello
wait_raw $WF 2 1 30 || fail "run did not reach insights_raw"
ok "run reached insights_raw"
wait_period $WF 2 $((before + 1)) 150 \
  || fail "insights_by_period has not moved after 150s. Compaction is still failing. Check: docker compose logs --since=3m n8n | grep -i constraint"
ok "compaction is folding raw rows again"

# And the backlog must drain: raw should be smaller than when we started.
sleep 5
rawafter=$(raw_count)
[[ "${rawafter:-0}" -lt "${rawbefore:-1}" ]] || fail "insights_raw is not draining (before $rawbefore, after $rawafter)"
ok "backlog is draining ($rawbefore -> $rawafter raw rows)"

echo "PASS: case 02 solved. In the reply: are the eleven days recoverable? (Look at insights_by_period for the last 11 days before you answer.)"
