#!/usr/bin/env bash
# Bonus B check.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5711
CASE="bonus b"
WF=InsLabHello000001

wait_ready || fail "n8n is not ready"
ok "n8n ready"
[[ "$(login)" == "200" ]] || fail "owner login failed"
[[ "$(summary_code)" == "200" ]] || fail "insights module not loaded (disabling it is not the fix)"
ok "insights module loaded"

start=$(raw_count); start=${start:-0}
echo "  raw backlog now: $start rows"
# Within ~2.5 minutes (two compaction runs) the backlog must be essentially gone.
for _ in $(seq 1 150); do
  n=$(raw_count); n=${n:-0}
  [[ "$n" -le 10 ]] && break
  sleep 1
done
[[ "${n:-999}" -le 10 ]] || fail "raw backlog still $n rows after 150s. Compaction is still starved."
ok "backlog drained ($start -> $n raw rows)"

# They still need protection: some throttling must remain. Reality check only:
# the compaction job must not be allowed to run unbounded.
delay=$(docker compose exec -T n8n printenv N8N_INSIGHTS_COMPACTION_BATCH_DELAY_MILLISECONDS 2>/dev/null || echo "")
runtime=$(docker compose exec -T n8n printenv N8N_INSIGHTS_COMPACTION_MAX_RUNTIME_SECONDS 2>/dev/null || echo "")
if [[ "${delay:-100}" -eq 0 && "${runtime:-300}" -eq 0 ]]; then
  fail "you removed every limit. Their DBA signed off on throttling; keep a delay or a runtime cap."
fi
ok "some throttling still in place (delay=${delay:-default} ms, runtime cap=${runtime:-default} s)"

echo "PASS: bonus b solved. In the reply: why the lag grew, the values you'd recommend, and that the backlog drains rather than disappears."
