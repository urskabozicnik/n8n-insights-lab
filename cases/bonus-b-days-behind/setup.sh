#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file.
set -euo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5711
WF=InsLabHello000001

docker compose up -d
wait_ready
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='$WF';")" != "1" ]]; then
  import_workflows
fi
hit hello 1
wait_raw $WF 2 1 30
META=$(q "SELECT \"metaId\" FROM insights_metadata WHERE \"workflowId\"='$WF';")
# Three days of un-compacted raw rows, the backlog this throttling produced.
q "INSERT INTO insights_raw (\"metaId\", type, value, timestamp)
   SELECT $META, t.type, CASE t.type WHEN 2 THEN 1 WHEN 1 THEN 900 ELSE 10 END, g
   FROM generate_series(now() - interval '72 hours', now() - interval '1 hour', interval '6 minutes') g
   CROSS JOIN (VALUES (2),(1),(0)) AS t(type);" >/dev/null
echo "ready: http://localhost:$PORT  (raw backlog: $(raw_count) rows)"
