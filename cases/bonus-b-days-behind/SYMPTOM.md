# Bonus B: "Insights is three days behind"

**Ticket:** T-A11315
**From:** integrations@larkspur-retail.example
**Setup:** self-hosted n8n 2.33.0 + PostgreSQL (shared with their ERP), Docker Compose, Enterprise
**Severity:** low, "but it's getting worse every week"

---

## What the customer wrote

> Insights works, it's just late. A run I do now shows up on the dashboard about
> three days later. In August it was a few hours. Our DBA says the n8n database
> load is fine, lower than it used to be in fact, so it's not a performance
> problem on our side.
>
> We never touched Insights apart from the throttling we did after the CPU
> incident in May, which your support team recommended and which fixed the
> problem. I assume the hourly compaction job is just slow on 2.33.0 and you have
> a fix coming?

What they already tried:

- Confirmed DB CPU is low.
- Restarted n8n. "The lag got a bit worse, if anything."

They attached their `compose.yaml` and `.env`.

---

## Your job

Boot the stack (it comes with a backlog), work out why the lag grows, fix it
without undoing the protection their DBA signed off on, prove it with
`./verify.sh`, and write the reply.

```
./setup.sh
./verify.sh
```

n8n is on **http://localhost:5711**. Login `owner@example.com` / `InsightsLab2026`.
