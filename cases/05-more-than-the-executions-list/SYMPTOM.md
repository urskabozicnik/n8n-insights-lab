# Case 05: "Insights is counting executions that don't exist"

**Ticket:** T-A11289
**From:** cto@quillstone-publishing.example
**Setup:** self-hosted n8n 2.33.0 + PostgreSQL, Docker Compose, Business licence
**Severity:** they've put "possible overbilling" in the subject line

---

## What the customer wrote

> Insights says we had 120 production executions this week. The executions list
> for the same workflow shows 50. I've scrolled to the bottom, there are 50. We
> run the one webhook workflow and nothing else.
>
> So Insights is inflating our numbers by more than double. We saw your community
> post about the queue mode counting bug last year, and I assume this is the same
> thing or something like it. We're not in queue mode but clearly something is
> double counting. Since our plan is priced on executions I'd like this corrected
> on our account and an explanation of how long it's been happening.

What they already tried:

- Compared the Insights per-workflow table with the executions list, filtered to
  the same workflow. 120 vs 50.
- Checked they're not in queue mode: "EXECUTIONS_MODE isn't even set".
- Restarted n8n. Numbers unchanged.

They attached their `compose.yaml` and `.env`.

---

## Your job

This case is different: nothing may be broken. Boot the stack, reproduce their
two numbers, work out which one is right and why they differ, and write the
reply. `./verify.sh` here checks that the stack is healthy and that you haven't
"fixed" anything that wasn't broken; the reply is the deliverable.

The reply has to cover: which number is right, why the other one is lower, whether
they've been overbilled, and where they should look for the billing number
(it's neither of the two they compared).

```
./setup.sh      # brings up the stack and gives it a week of traffic (~90 seconds)
./verify.sh     # healthy and not made worse
```

n8n is on **http://localhost:5705**. Login `owner@example.com` / `InsightsLab2026`.

Reset from the shipped state any time: `docker compose down -v && ./setup.sh`
