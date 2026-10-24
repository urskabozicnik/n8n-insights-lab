# FIX: case 01, banner missing

## The cracking command

```bash
docker compose exec n8n printenv N8N_DISABLED_MODULES
# insights
```

or, from the outside with the owner cookie: `GET /rest/insights/summary` returns
**404**, not 403. A 403 would mean "module loaded, you're not allowed". A 404
means the route doesn't exist because the module never loaded.

## The path

1. Log in as owner, look at Overview. No banner, no Insights menu entry. On
   Community you'd still expect the banner.
2. `docker compose logs n8n | head -40`. Nothing says "insights", which is itself
   the finding: a loaded module logs at boot at debug level, a disabled one is
   silent. The customer read the silence as "nothing wrong".
3. `diff <(docker compose -f ../../reference/compose.yaml config) <(docker compose config)`
   shows one extra line: `N8N_DISABLED_MODULES: insights`, with a comment from a
   previous admin dated Feb 2026 about DB CPU.
4. Remove the line, `docker compose up -d` (watch for `Recreated`), `./verify.sh`.

## Root cause

A previous admin disabled the module during the compaction CPU problem (LIGO-296,
real fix shipped in 2.22.0 / 1.123.45) and nobody turned it back on. The current
admin inherited the file and assumed the missing banner was a Community
limitation.

## What the customer lost

Three weeks of history, and everything since February. The module wasn't
collecting, so there is nothing to backfill. Insights starts recording from the
restart.

## The reply (three sentences, roughly)

Insights isn't limited by the Community edition: the 7-day summary works on every
plan, and the module was switched off in your compose file
(`N8N_DISABLED_MODULES: insights`, with a note from February about a database
CPU problem that was fixed in 2.22). Remove that line and recreate the container
and the banner comes back; the full dashboard with date ranges would still need
a paid plan. Nothing was collected while it was off, so the summary will start
from today rather than show the last three weeks.

## Where this shows up for real

T-80055 (Starter, plan gating), T-22123 (non-admin can't see banner), LIGO-510
(module runs on every plan; `N8N_DISABLED_MODULES` is the only off switch), and
Devin's T-62514 reply recommending the disable as a temporary CPU mitigation,
which is exactly how this leftover happens.
