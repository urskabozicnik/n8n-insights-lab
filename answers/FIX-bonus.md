# FIX: bonus A, won't start

## The cracking command

```bash
docker compose logs n8n | head -30
```

n8n refuses to boot because the same module is listed in both
`N8N_ENABLED_MODULES` and `N8N_DISABLED_MODULES`. It says so in one sentence.

## Fix

Delete both lines. Insights is in the default module list; it was only ever
missing because of the `N8N_DISABLED_MODULES` line from their Community days.
`docker compose up -d`, `./verify.sh`.

## The reply

Insights is on by default, so there's nothing to enable: the restart loop is
n8n refusing to start because `insights` is now listed as both enabled and
disabled in your compose file (the log says exactly that in the first few
lines). Remove both lines and recreate the container and Insights will load
with your Business licence. The module docs page you followed is for optional
modules that are off by default, which Insights isn't.

## Where this shows up for real

Jaakko's note in Slack, 23 Oct 2026, on an instance that wouldn't boot for
this reason. Rare, five minutes, worth knowing.

---

# FIX: bonus B, days behind

## The cracking command

```bash
docker compose exec n8n printenv | grep COMPACTION
# N8N_INSIGHTS_COMPACTION_BATCH_SIZE=1
# N8N_INSIGHTS_COMPACTION_MAX_BATCHES_PER_RUN=1
# N8N_INSIGHTS_COMPACTION_BATCH_DELAY_MILLISECONDS=5000
```

One row per batch, one batch per run, one run per minute: 60 raw rows an hour
compacted. The seeded backlog is ~2,100 rows and every run adds three. The lag
can only grow. A restart skips a run, so "it got a bit worse" is accurate.

## Fix

Keep the knobs that protect the shared database and restore the ones that
decide throughput:

```
N8N_INSIGHTS_COMPACTION_BATCH_SIZE: "500"            # default
N8N_INSIGHTS_COMPACTION_MAX_BATCHES_PER_RUN: "1000"  # default
N8N_INSIGHTS_COMPACTION_BATCH_DELAY_MILLISECONDS: "1000"   # gentle, still far above default 100
N8N_INSIGHTS_COMPACTION_MAX_RUNTIME_SECONDS: "120"   # hard cap per run
```

`docker compose up -d`. Backlog drains within a couple of runs. `verify.sh`
refuses a fix that removes every limit, because their DBA has a point.

## The reply

Insights isn't slow on 2.33; the throttling you applied in May limits
compaction to one raw row per batch and one batch per run, so it clears about
60 executions an hour while you produce more than that, and the lag grows
every day. The protection you want comes from the batch delay and the runtime
cap, not from the batch size, so I'd set the values below: still gentle on
the ERP database, but able to keep up. The current backlog will drain over the
next hour or so rather than disappear, and no data is lost.

## Where this shows up for real

LIGO-296 (Choco, Wayfair) is the incident that led to these env vars existing
(2.22.0, PR #30503). T-44747 and T-62514 are the tickets. Community thread
306986 is a customer who set `MAX_RUNTIME_SECONDS=0` the other way and had
compaction not run at all because there was no stable leader.
