#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file: it is never part
# of the puzzle. Run it, then run ./verify.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5703
WF=InsLabHello000001
NIGHTLY=InsLabNightly0003

docker compose up -d
wait_ready
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='$WF';")" != "1" ]]; then
  import_workflows
fi

# Healthy history: a few runs, compacted.
hit hello 6
wait_raw $WF 2 6 30
wait_period $WF 2 6 150 || true

# Tuesday's "cleanup". The customer deleted shared_workflow rows they thought
# were orphaned. One of them belonged to the schedule-triggered nightly sync,
# which is still active and fires every 10 seconds.
q "DELETE FROM shared_workflow WHERE \"workflowId\"='$NIGHTLY';" >/dev/null

# Let the damage take effect: the next flush fails and keeps failing.
sleep 25
echo "ready: http://localhost:$PORT"
