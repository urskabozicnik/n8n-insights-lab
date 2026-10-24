# The Insights diagnostic kit

One page. Run the queries with `docker compose exec -T postgres psql -U n8n -d n8n`
from inside a case directory, or source `tools/lib.sh` and use `q "SELECT ..."`.

---

## 1. The pipeline

```
execution ends on MAIN or WEBHOOK process (never on a worker)
   │  mode in: trigger, webhook, cli, retry, evaluation, error
   │  status in: success, error, crashed
   ▼
in-memory buffer ──── flush every 30s or 1000 events (lab: 5s) ────▶  insights_metadata  (one row per workflow)
                                                                       insights_raw       (one row per execution per metric)
                                                                            │
                                   compaction every 60 min (lab: 1 min), leader only
                                   raw → hour; hour → day after 90d; day → week after 180d
                                                                            ▼
                                                                       insights_by_period
                                                                            │
                                                     dashboard, banner, /rest/insights/*, /api/v1/insights/summary
                                                     read ONLY this table
                                                                            │
                                   pruning every 24h deletes rows older than N8N_INSIGHTS_MAX_AGE_DAYS (365)
```

So: the dashboard lags by up to one compaction interval. If raw grows and
by_period doesn't move, compaction is broken. If raw doesn't grow either, the
flush is broken. If nothing is in any table, the module isn't loaded or the
executions aren't production executions.

## 2. The four queries

```sql
-- A. is anything arriving at all (last 20 raw rows, newest first)
SELECT ir.id, im."workflowName", ir.type, ir.value, ir.timestamp
FROM insights_raw ir JOIN insights_metadata im ON ir."metaId" = im."metaId"
ORDER BY ir.id DESC LIMIT 20;

-- B. is compaction keeping up
SELECT (SELECT COUNT(*) FROM insights_raw) AS raw_rows,
       (SELECT MAX("periodStart") FROM insights_by_period WHERE "periodUnit" = 0) AS last_hour_bucket,
       now() AS db_now;

-- C. what the dashboard would show for a workflow, per day
SELECT date_trunc('day', "periodStart") AS day, type, SUM(value)
FROM insights_by_period bp JOIN insights_metadata im ON bp."metaId" = im."metaId"
WHERE im."workflowId" = '<id>' AND "periodUnit" <= 1
GROUP BY 1, 2 ORDER BY 1, 2;

-- D. the controlled test: one production run of one workflow should be exactly one type-2 row
SELECT type, value, timestamp FROM insights_raw ir
JOIN insights_metadata im ON ir."metaId" = im."metaId"
WHERE im."workflowId" = '<id>' ORDER BY timestamp DESC;
```

Metric `type`: 0 time saved (minutes), 1 runtime (ms), 2 success, 3 failure,
4 billable (2.40+). `periodUnit`: 0 hour, 1 day, 2 week.

## 3. The two log lines

```bash
docker compose logs --since=2m n8n | grep -iE 'insight'
```

| Line | Stage | Means |
|---|---|---|
| `Error while saving insights metadata and raw data` (often with `Could not find shared workflow for insight with workflowId …`) | flush | One event in the buffer can't be attributed. On versions before 2.41.0 the whole batch is re-buffered every flush, forever, and nothing new reaches the DB. Restart main clears it. The gap is permanent. |
| `duplicate key value violates unique constraint "PK_b606942249b90cc39b0265f0575"` | compaction | The Postgres id sequence on `insights_by_period` is behind `MAX(id)`. Typical after a SQLite → Postgres migration. `insights_raw` grows, dashboard freezes. |

Set `N8N_LOG_LEVEL=debug` to also see `Inserting N insights raw` and the compaction
runs. A healthy instance logs a compaction line every interval even when there is
nothing to compact.

## 4. The real env vars

| Variable | Default | |
|---|---|---|
| `N8N_DISABLED_MODULES=insights` | | off switch, the only one. Never put the same module in `N8N_ENABLED_MODULES` and `N8N_DISABLED_MODULES`: n8n refuses to boot. |
| `N8N_INSIGHTS_FLUSH_INTERVAL_SECONDS` | 30 | |
| `N8N_INSIGHTS_FLUSH_BATCH_SIZE` | 1000 | |
| `N8N_INSIGHTS_COMPACTION_INTERVAL_MINUTES` | 60 | |
| `N8N_INSIGHTS_COMPACTION_BATCH_SIZE` | 500 | |
| `N8N_INSIGHTS_COMPACTION_MAX_BATCHES_PER_RUN` | 1000 | 0 = unlimited (2.22+) |
| `N8N_INSIGHTS_COMPACTION_MAX_RUNTIME_SECONDS` | 300 | 0 = unlimited (2.22+) |
| `N8N_INSIGHTS_COMPACTION_BATCH_DELAY_MILLISECONDS` | 100 | (2.22+) |
| `N8N_INSIGHTS_COMPACTION_HOURLY_TO_DAILY_THRESHOLD_DAYS` | 90 | |
| `N8N_INSIGHTS_COMPACTION_DAILY_TO_WEEKLY_THRESHOLD_DAYS` | 180 | |
| `N8N_INSIGHTS_MAX_AGE_DAYS` | 365 | cap 730 (2.20+). Before 2.20 it came from the licence, usually 180. |
| `N8N_INSIGHTS_PRUNE_CHECK_INTERVAL_HOURS` | 24 | |

Not real, however often customers paste them: `N8N_INSIGHTS_ENABLED`,
`N8N_INSIGHTS_RETENTION_DAYS`, `N8N_INSIGHTS_COLLECT_ONLY_SUCCESSFUL`.

Check what the container actually got: `docker compose exec n8n printenv | grep INSIGHTS`.

## 5. What counts

| Counted | Not counted |
|---|---|
| mode trigger, webhook, cli, retry, evaluation | manual (the Test button) |
| mode error (error-workflow runs, against the error workflow) | integrated (sub-workflows called by Execute Workflow) |
| status success, error, crashed | internal, chat (Chat Hub), agent, AI-assistant verification runs |
| counted when the run **ends** | canceled, running, waiting, new |

Time saved: only on success, never for error-workflow runs, only on the parent
workflow. Fixed = the workflow setting. Dynamic = sum of Track Time Saved nodes
that ran (Per Item multiplies by input items). If the setting is Fixed the nodes
are ignored.

## 6. Insights vs billing, the table you will quote most

| | Insights "production executions" | Licence / billable |
|---|---|---|
| Lives in | `insights_by_period` | `workflow_statistics` → licence server |
| Error-workflow runs | counted | not since 2.28.0 / 1.123.60 |
| Sub-workflows, manual | no | no |
| Counted when | run ends | run starts (cloud) |
| Several instances, one key | per instance | summed |
| Can lose data | yes (stall, crash, restart) | rarely |

The licence server is the source of truth for billing. Insights is not. The
`billable` metric (type 4, 2.40+, API summary only, no backfill) follows licence
rules.

Executions list vs Insights: the list is pruned by `EXECUTIONS_DATA_PRUNE_MAX_COUNT`
(default 10,000) and `EXECUTIONS_DATA_MAX_AGE`; Insights tables are never touched by
execution pruning. Insights showing more than the list is normal.

## 7. Known bugs to recognise on sight (as of Oct 2026)

| You see | It's | Fixed in |
|---|---|---|
| ~2x counts, queue mode | workers also collecting | 1.122.0 |
| Insights stall, "Error while saving insights metadata" | poison event in buffer | 2.41.0 (GOV-112 still open for a variant) |
| `invalid input syntax for type bigint` | decimal dynamic time saved | 2.20.0 |
| Pro/Enterprise sees the paywall on 2.22.4 / 2.23.0-1 | PostHog stub bug | 2.22.6 / 2.23.2 |
| Dynamic time saved = 0, queue mode, 2.27+ | GOV-286 | open |
| 403 "exceeds maximum history" on 14 days, Pro, browser ahead of UTC | GOV-223 | open |
| Days missing on non-UTC Postgres | API-405 / GOV-296 | query side merged, awaiting release |
| Postgres CPU pinned by compaction after a big upgrade | LIGO-296 | 2.22.0 / 1.123.45 |

## 8. The ladder, in one block

```
1. Is the module loaded?       GET /rest/insights/summary → 200, not 404; printenv N8N_DISABLED_MODULES
2. Are runs production runs?   mode + status; the Test button never counts
3. Did the flush land?         query A; grep "Error while saving insights"
4. Did compaction fold it?     query B; grep "duplicate key"; is there a leader?
5. Is it a lag or a gap?       one interval = lag; longer = gap, and gaps are permanent
6. Which number is it being compared to?   §6, before you call anything a bug
7. Change ONE thing            docker compose up -d, wait one interval, query B again
```
