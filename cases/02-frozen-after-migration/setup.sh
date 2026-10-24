#!/usr/bin/env bash
# Prepares the customer's environment. Don't read this file: it is never part
# of the puzzle. Run it, then run ./verify.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ../../tools/lib.sh
PORT=5702
WF=InsLabHello000001

docker compose up -d
wait_ready
if [[ "$(q "SELECT COUNT(*) FROM workflow_entity WHERE id='$WF';")" != "1" ]]; then
  import_workflows
fi

# Pre-migration history: 20 days of hourly buckets, already compacted, as the
# migration would have copied them. Then one real run so metadata exists.
hit hello 1
wait_raw $WF 2 1 30
META=$(q "SELECT \"metaId\" FROM insights_metadata WHERE \"workflowId\"='$WF';")
q "INSERT INTO insights_by_period (\"metaId\", type, value, \"periodUnit\", \"periodStart\")
   SELECT $META, t.type, CASE t.type WHEN 2 THEN 40 + (random()*20)::int WHEN 3 THEN (random()*3)::int ELSE 1500 END,
          0, g
   FROM generate_series(now() - interval '31 days', now() - interval '11 days', interval '1 hour') g
   CROSS JOIN (VALUES (2),(3),(1)) AS t(type);" >/dev/null
# Let compaction fold the real run, so by_period has rows with real ids.
wait_period $WF 2 1 150 || true

# The damage. A pg_dump/restore or a hand-rolled copy brings rows but not the
# sequence position. Postgres now hands out ids that already exist.
q "SELECT setval(pg_get_serial_sequence('insights_by_period','id'), 1, false);" >/dev/null

# Eleven days of traffic since: raw rows pile up, nothing compacts.
hit hello 25
echo "ready: http://localhost:$PORT (give it a minute, then look)"
