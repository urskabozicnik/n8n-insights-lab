#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file: it is never part
# of the puzzle. Run it, then run ./verify.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5704

docker compose up -d
wait_ready
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='InsLabInvoice0004';")" != "1" ]]; then
  import_workflows
  docker compose up -d n8n-worker
  sleep 10
fi
hit hello 3
hit invoices 3
echo "ready: http://localhost:$PORT"
