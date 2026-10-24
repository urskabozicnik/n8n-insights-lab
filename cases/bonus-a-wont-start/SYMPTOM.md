# Bonus A: "n8n won't start since we enabled Insights"

**Ticket:** T-A11301
**From:** admin@pinewood-dental.example
**Setup:** self-hosted n8n 2.33.0 + PostgreSQL, Docker Compose, just upgraded to Business
**Severity:** production down

---

## What the customer wrote

> We upgraded to the Business licence yesterday mainly for Insights. I added the
> environment variable to enable the Insights module like your module docs
> describe, restarted, and now n8n doesn't come up at all. The container just
> keeps restarting. Rolling the variable back fixes it but then we don't have
> Insights, which is what we're paying for.
>
> Is the Insights module broken on 2.33.0? Do we need a newer version for the
> Business licence?

What they already tried:

- Removed the new variable: n8n starts, no Insights.
- Re-added it: restart loop.
- Checked the licence key is applied (Settings shows Business when it does start).

They attached their `compose.yaml` and `.env`.

---

## Your job

Five-minute case. Boot it, read the log, fix it so n8n starts **and** Insights is
on, prove it with `./verify.sh`, write the reply.

```
./setup.sh
./verify.sh
```

n8n is on **http://localhost:5710**. Login `owner@example.com` / `InsightsLab2026`.
