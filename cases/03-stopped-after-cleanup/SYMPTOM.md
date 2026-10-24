# Case 03: "Insights stopped recording on Tuesday"

**Ticket:** T-A11258
**From:** automation@harbourline-logistics.example
**Setup:** self-hosted n8n 2.33.0 + PostgreSQL, Docker Compose, Enterprise
**Severity:** high (they report executions to Finance from Insights)

---

## What the customer wrote

> Insights has been flat since Tuesday afternoon. Zero production executions on
> every workflow, even though the executions list shows hundreds a day as usual
> and nothing is failing. The Overview banner still says "last 7 days" with
> numbers that stopped growing on Tuesday.
>
> The only thing we did on Tuesday was a database cleanup. One of your support
> replies in May told us to look for "orphaned shared_workflow rows" when our UI
> got slow, so we ran that query, found a handful, and deleted them. The UI is
> faster now. I don't see how that would stop Insights, those are different
> tables, but I'm mentioning it for completeness.
>
> I'd guess the compaction job died. Can you tell us how to restart it without
> restarting n8n? We'd rather not interrupt the nightly syncs.

What they already tried:

- Nothing yet beyond looking. "We didn't want to make it worse."
- Confirmed `insights_by_period` has rows up to Tuesday 15:00.
- Confirmed `insights_raw` is "basically empty", which they say is normal since
  it compacts every hour.

They attached their `compose.yaml` and `.env`.

---

## Your job

Boot the customer's stack, reproduce, find the stage that is broken, fix it,
prove it with `./verify.sh`, and write the reply. The reply has to answer their
question about restarting without a restart, and say what happened to the data
since Tuesday.

```
./setup.sh      # brings up the customer's stack as-is, with the cleanup already done
./verify.sh     # tells you whether it is actually fixed
```

n8n is on **http://localhost:5703**. Login `owner@example.com` / `InsightsLab2026`.

Reset from the shipped state any time: `docker compose down -v && ./setup.sh`
