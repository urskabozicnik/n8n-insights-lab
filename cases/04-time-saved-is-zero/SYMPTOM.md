# Case 04: "Time saved is zero for our biggest workflow"

**Ticket:** T-A11270
**From:** finance-automation@nordfall-accounting.example
**Setup:** self-hosted n8n 2.33.0, queue mode (1 main + 1 worker), Postgres, Redis, Enterprise
**Severity:** medium (they present ROI to the board quarterly, and the quarter ends in six days)

---

## What the customer wrote

> Our invoice-matching workflow runs a few hundred times a day and is set up with
> the Track Time Saved node, Per Item, 3 minutes per invoice. It used to report
> around 15 minutes per run. Since some point in September it reports 0 for every
> single run. The executions themselves are fine, all green, 5 items processed each
> time.
>
> Our other workflows (the ones with the plain "fixed minutes" setting) still
> report time saved correctly, so the Insights pipeline is clearly working. I
> think it's the node: maybe it needs re-adding after the upgrade, or the Per Item
> mode broke. We tried "Once For All Items" too, also 0.
>
> We scaled to queue mode in September, but that can't be related, the time saved
> node runs inside the workflow and the workflow runs fine.

What they already tried:

- Re-added the Track Time Saved node. Still 0.
- Switched Calculation Mode between Per Item and Once. Still 0.
- Opened an execution and confirmed the node ran and output 5 items.
- Checked `insights_raw`: "there IS a time-saved row for each run, it just says 0".

They attached their `compose.yaml` and `.env`.

---

## Your job

Boot the customer's stack, reproduce, find out why dynamic time saved is 0 while
fixed time saved works, get a non-zero value recorded, prove it with
`./verify.sh`, and write the reply. The reply has to say whether this is
something they did wrong, and what the options are before the board meeting.

```
./setup.sh      # brings up main + worker + postgres + redis, seeds both workflows
./verify.sh     # tells you whether it is actually fixed
```

n8n is on **http://localhost:5704**. Login `owner@example.com` / `InsightsLab2026`.
Two production webhooks: `/webhook/hello` (fixed, 10 min) and `/webhook/invoices` (dynamic).

Reset from the shipped state any time: `docker compose down -v && ./setup.sh`
