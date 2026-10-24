# Case 01: "Insights isn't showing up at all"

**Ticket:** T-A11204
**From:** it@bergwerk-tools.example
**Setup:** self-hosted n8n 2.33.0 + PostgreSQL, Docker Compose, Community edition
**Severity:** low, but the CTO asked

---

## What the customer wrote

> We're on the Community edition and I know the full Insights dashboard is a paid
> thing, fine. But your docs say the 7-day summary at the top of the Overview page
> is "available for all plans and editions" and we don't have it. No banner, and
> the Insights entry in the left menu isn't there either. I'm the instance owner.
>
> We've been on 2.33.0 for three weeks. Before that we were on 1.9x for a long
> time. I assume this just doesn't work on Community after all, or it needs a
> licence key we don't have. Can you confirm so I can tell my CTO?

What they already tried:

- Logged out and in again as owner.
- Hard refresh, incognito window.
- Checked Settings > Usage and plan: "Community", as expected.
- "Checked the logs, nothing about insights in there."

They attached their `compose.yaml` and `.env`: the two files in this directory.
Assume they are what is actually deployed. There's a comment in the compose file
from whoever set it up, which the current admin says they "inherited".

---

## Your job

Boot the customer's stack, reproduce, find out why, fix it, prove it with
`./verify.sh`, and write the three-sentence reply. The reply has to say whether
this is a Community limitation or not.

```
./setup.sh      # brings up the customer's stack as-is
./verify.sh     # tells you whether it is actually fixed
```

n8n is on **http://localhost:5701**. Login `owner@example.com` / `InsightsLab2026`.

Reset from the shipped state any time: `docker compose down -v && ./setup.sh`

When you're done, tell the room: what you observed, **which command told you the
answer**, what you changed, and what you'd tell the customer about the three weeks
of history they expected to see.
