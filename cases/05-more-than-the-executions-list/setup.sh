#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file: it is never part
# of the puzzle. Run it, then run ./verify.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5705
WF=InsLabHello000001

docker compose up -d
wait_ready
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='$WF';")" != "1" ]]; then
  import_workflows
fi
# A week of traffic, as far as this instance is concerned.
hit hello 120
wait_raw $WF 2 120 60 || true
# Give pruning (every minute here) time to do what the customer configured.
sleep 75
echo "ready: http://localhost:$PORT"
