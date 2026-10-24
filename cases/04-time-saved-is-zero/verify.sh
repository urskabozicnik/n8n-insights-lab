#!/usr/bin/env bash
# Case 04 check. Looks at the running stack, not at what you edited.
set -uo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5704
CASE="case 04"
INV=InsLabInvoice0004
HELLO=InsLabHello000001

wait_ready || fail "n8n main is not ready on http://localhost:$PORT"
ok "main ready"
w=$(docker compose ps --status running --format '{{.Service}}' | grep -c n8n-worker)
[[ "$w" -ge 1 ]] || fail "no running worker. This customer runs queue mode; removing the worker is not a fix."
ok "worker running"
[[ "$(login)" == "200" ]] || fail "owner login failed"
[[ "$(summary_code)" == "200" ]] || fail "insights module not loaded"
ok "insights module loaded"

# Control: fixed time saved still works.
before=$(raw_for $HELLO 0); before=${before:-0}
hit hello
wait_raw $HELLO 0 $((before + 1)) 30 || fail "fixed time saved stopped being recorded; you broke the control"
ok "fixed time saved still recorded (control)"

# The case: a dynamic run must record a non-zero time-saved value.
before=$(raw_for $INV 0); before=${before:-0}
hit invoices
wait_raw $INV 0 $((before + 1)) 45 || fail "no time-saved row for the dynamic run"
val=$(q "SELECT ir.value FROM insights_raw ir JOIN insights_metadata im ON ir.\"metaId\"=im.\"metaId\" WHERE im.\"workflowId\"='$INV' AND ir.type=0 ORDER BY ir.id DESC LIMIT 1;")
[[ "${val:-0}" -gt 0 ]] || fail "the dynamic run recorded time saved = ${val:-0}. Still zero."
ok "dynamic run recorded time saved = $val minutes"
if [[ "$val" == "15" ]]; then
  ok "and it is 15 (3 min x 5 items), so Per Item is working, not just a fixed fallback"
else
  echo "  (note: $val is non-zero but not 15. If you switched the workflow to Fixed, that passes, but say in the reply what the customer gives up.)"
fi

echo "PASS: case 04 solved. In the reply: whose fault is it, what are the options before the board meeting, and which Linear issue do you link?"
