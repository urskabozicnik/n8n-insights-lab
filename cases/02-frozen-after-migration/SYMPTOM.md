# Case 02: "Insights stopped the day we migrated to Postgres"

**Ticket:** T-A11231
**From:** platform@trendline-media.example
**Setup:** self-hosted n8n 2.33.0, migrated from SQLite to PostgreSQL on 13 Oct, Docker Compose, Business licence
**Severity:** medium (monthly ops report due Friday)

---

## What the customer wrote

> We migrated from SQLite to Postgres on the 13th using the export/import route in
> your docs. Everything works: workflows, credentials, executions, all there. But
> the Insights dashboard is frozen. It shows our history up to the 13th and then a
> flat line, even though we've had thousands of production executions since. The
> executions list shows them all.
>
> I'm pretty sure the migration didn't bring the "live" Insights data over and it
> just needs a kick. Or is it the hourly delay you mention in the docs? It's been
> eleven days, so probably not that.

What they already tried:

- Restarted n8n. Twice.
- Checked that `insights_raw` exists in Postgres: "it does, and it has loads of rows, so data IS being collected".
- Re-ran the migration for the insights tables only. No change.
- Set `N8N_LOG_LEVEL=debug`, "didn't see anything about insights failing".

They attached their `compose.yaml` and `.env`. Nothing was changed in them for
the migration beyond the `DB_` block.

---

## Your job

Boot the customer's stack (it comes up already migrated, with their history), find
out why nothing after the 13th reaches the dashboard, fix it, prove it with
`./verify.sh`, and write the reply. The reply has to say whether the eleven days
are recoverable.

```
./setup.sh      # brings up the customer's stack as-is (takes ~2 minutes, it seeds history)
./verify.sh     # tells you whether it is actually fixed
```

n8n is on **http://localhost:5702**. Login `owner@example.com` / `InsightsLab2026`.

Reset from the shipped state any time: `docker compose down -v && ./setup.sh`
