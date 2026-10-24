#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file: it is never part
# of the puzzle. Run it, then run ./verify.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5701

docker compose up -d
wait_ready
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='InsLabHello000001';")" != "1" ]]; then
  import_workflows
fi
# The customer's workflows have been running for weeks. Give the instance some
# production traffic so the absence of data is noticeable.
hit hello 12
echo "ready: http://localhost:$PORT"
