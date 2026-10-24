# FIX: case 05, more than the executions list

## The cracking command

```sql
SELECT COUNT(*) FILTER (WHERE "deletedAt" IS NULL) AS listed,
       COUNT(*)                                    AS all_rows
FROM execution_entity WHERE "workflowId" = 'InsLabHello000001';
-- listed 50, all_rows ~50-60 (hard-deleted after the interval)
```

against

```sql
SELECT SUM(value) FROM insights_by_period bp JOIN insights_metadata im USING ("metaId")
WHERE im."workflowId" = 'InsLabHello000001' AND bp.type = 2;
-- 120
```

and the customer's own compose file:

```
EXECUTIONS_DATA_PRUNE_MAX_COUNT: "50"
```

## There is no fix

Insights is right. The executions list is pruned to the newest 50 by the
customer's own setting (the comment says "we only ever look at today's runs").
Execution pruning never touches Insights tables, and Insights is written at
execution end, independently of whether the execution row survives. So 120 is
the real count and 50 is what's left on disk.

Not the queue-mode bug: no workers, no `EXECUTIONS_MODE`, and that bug produced
roughly 2× via a second collector, which would show as duplicate raw rows with
near-identical timestamps (query D shows one row per run here).

## Were they overbilled?

Neither number is the billing number. Billing comes from `workflow_statistics`
(`rootCount`) reported to the licence server, which counts the same kinds of
runs as Insights except error-workflow runs. For a single plain webhook
workflow the licence count should equal Insights, 120. The sentence to use:
the licence server is the source of truth for billing, not the dashboard and
not the executions list. If they want to check it themselves on self-hosted:
`N8N_METRICS_INCLUDE_WORKFLOW_STATISTICS=true` exposes
`n8n_production_root_executions`, or `SELECT SUM("rootCount") FROM workflow_statistics WHERE name='production_success'` (and `production_error`).

## The reply

The 120 is correct: Insights records every production execution as it finishes,
in its own tables, and doesn't go back to the executions list afterwards. The
list shows 50 because your compose file caps it at 50 kept executions
(`EXECUTIONS_DATA_PRUNE_MAX_COUNT`), so older runs are deleted from the list
while Insights keeps counting them. Nothing is being double counted and nothing
on your account needs correcting; and for billing specifically, neither of
those two numbers is what we invoice from. That comes from the licence
server's execution counter, which for a single webhook workflow like yours will
match Insights. If you'd like to see that counter yourself, I can show you the
Prometheus metric or the SQL.

## Where this shows up for real

T-72444 (Tyme, 13k vs empty list, `EXECUTIONS_DATA_PRUNE_MAX_COUNT` 10k
default), T-37991 (Guesty), T-78260. The "we read about the queue mode bug"
framing is from T-36538 (Digital Realty) and T-8663 (Choco). The billing
sentence is from the KB "License Server vs. n8n Insights" and Timothée's line
in #help-enterprise-usage-bot, 23 Oct 2026.
