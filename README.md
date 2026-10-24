# Insights Office Hours: the break/fix lab

Seven n8n + PostgreSQL Compose stacks where Insights is doing something a customer
didn't expect. Each one is written as a real ticket: the customer's compose file,
the customer's `.env`, the customer's symptom, and the customer's confident wrong
theory about the cause. Six of them are broken. One of them isn't, and that is the
point of that one.

You will not build anything today. You will diagnose, and then you will write the
first reply.

Insights is a pipeline, not a page. Executions go into a memory buffer, the buffer
flushes to `insights_raw`, a compaction task folds `insights_raw` into
`insights_by_period`, and the dashboard reads only `insights_by_period`. Every
Insights ticket we get is one of those four stages misbehaving, or a customer
comparing two numbers that were never supposed to match. By the end of the hour
you should be able to look at a customer's instance and say which stage, from one
query or one log line.

> **Which query (or log line) told you the answer?**

"I restarted it and it came back" does not count. Restarting is sometimes the fix,
but you have to know why it worked and what the customer lost.

---

## Pre-work: two commands

```bash
git clone <this repo> && cd n8n-insights-lab
docker compose -f reference/compose.yaml pull
```

Same images as the Docker lab: `docker.n8n.io/n8nio/n8n:2.33.0` and
`postgres:17-alpine`. If you did Session 2 you already have them. Case 04 adds
`redis:7-alpine` (queue mode). Pull it ahead if your wifi is bad:

```bash
docker compose -f cases/04-time-saved-is-zero/compose.yaml pull
```

---

## Step one: boot the stack that works

```bash
cd reference
docker compose up -d
./verify.sh
```

Expected:

```
✓ both containers running
✓ n8n ready on http://localhost:5678/healthz/readiness
✓ owner login works (owner@example.com / InsightsLab2026)
✓ insights module loaded (GET /rest/insights/summary -> 200)
✓ hello-webhook is active and answers
✓ 1 production execution landed in insights_raw (type 2 = success)
✓ compaction folded it into insights_by_period
PASS: reference stack healthy, open http://localhost:5678
```

That last pair of lines is the lab in miniature. `verify.sh` fired one production
webhook, waited for the 5-second flush, then waited for the 1-minute compaction.
Read it. It is 40 lines and every query in it is one you'll use on a real ticket.

The reference stack runs Insights fast on purpose:

```
N8N_INSIGHTS_FLUSH_INTERVAL_SECONDS=5          # real default: 30
N8N_INSIGHTS_COMPACTION_INTERVAL_MINUTES=1     # real default: 60
```

Every case uses the same two values, so "wait a minute and check again" is literal.
On a customer's instance it's "wait an hour". Keep that in mind when you write the
reply: half of our "Insights is delayed" tickets are the real default working as
designed.

Leave the reference running. It's the control for every experiment today, and
`diff <(docker compose -f ../../reference/compose.yaml config) <(docker compose config)`
from inside a case directory is still one of the best first moves.

---

## About the licence

The lab runs unlicensed. That is deliberate. What you get on Community is the 7-day
summary banner on the Overview page and the `/rest/insights/summary` endpoint,
which is what every `verify.sh` here calls. The full dashboard, date ranges and
per-workflow table need Pro, Business or Enterprise, and you'll verify those things
in the database instead, which is exactly what you do on a customer's self-hosted
instance anyway since you can't log in to it.

If the facilitator has an Enterprise trial key, it goes into `reference/.env` as
`N8N_LICENSE_ACTIVATION_KEY` and every case picks it up. Then you get the dashboard
too. Nothing in the cases depends on it.

Two facts worth knowing before you start, because customers get both wrong:

- The Insights module collects, compacts and stores data on **every** plan,
  including Community. The licence only gates who can *see* it. The only way to
  stop collection is `N8N_DISABLED_MODULES=insights`.
- Only owners and admins see the banner. A member who is "admin" of a project sees
  nothing. That is two tickets a month on its own.

---

## How every case works

```bash
cd cases/01-banner-missing
cat SYMPTOM.md      # the ticket
./setup.sh          # prepares the customer's environment (seeds workflows, data, damage)
./verify.sh         # PASS / FAIL
```

Same four rules as the Docker lab:

- **Don't read `setup.sh`.** It seeds the customer's instance. Some setups insert
  rows straight into the Insights tables to simulate weeks of history, and reading
  how is a spoiler.
- **`verify.sh` checks reality, not intent.** It fires a webhook, waits, and looks
  at the tables and the summary endpoint. It never checks what you edited. A fix
  nobody expected that actually works, passes.
- **You cannot brick a case.** `docker compose down -v && ./setup.sh` resets it.
- After an env change, `docker compose up -d`, not `restart`. Look for `Recreated`.

One rule that is new for this lab:

- **Every case ends with a reply.** `verify.sh` passing is half the job. The other
  half is three sentences you'd send the customer: what happened, what you changed
  or what they should change, and what they lost (if anything). Case 05 has no fix
  at all; the reply is the whole deliverable there.

---

## Rules of engagement

1. **Every case works the same way.** `./setup.sh`, then `./verify.sh`.
2. **Hints are in every case directory. Don't open hint 1 for the first five
   minutes.** Sit with the symptom. Open them in order. No hint contains a fix, a
   filename or a value.
3. **Name the one query or log line that cracked it.** The facilitator writes each
   group's on the board.
4. **Change one thing at a time.**
5. **Check all three tables, every time.** `insights_metadata`, `insights_raw`,
   `insights_by_period`. The stage that is broken is the one where rows stop
   appearing. This is the Insights equivalent of "read both containers' logs".
6. **Say what the customer lost.** If data from a gap is gone, the reply says so.
   Nothing in Insights backfills. Letting a customer hope for a backfill is the
   most common mistake in our Insights tickets.

**Report-back shape**, 4 minutes per group: 60s what you observed, 90s how you found
it, 60s the fix and the reply, 30s questions.

---

## Log in

Every stack ships with a pre-provisioned owner:

```
owner@example.com  /  InsightsLab2026
```

---

## Ports

| Stack | URL |
|---|---|
| `reference/` | http://localhost:5678 |
| `cases/01-banner-missing` | http://localhost:5701 |
| `cases/02-frozen-after-migration` | http://localhost:5702 |
| `cases/03-stopped-after-cleanup` | http://localhost:5703 |
| `cases/04-time-saved-is-zero` | http://localhost:5704 |
| `cases/05-more-than-the-executions-list` | http://localhost:5705 |
| `cases/bonus-a-wont-start` | http://localhost:5710 |
| `cases/bonus-b-days-behind` | http://localhost:5711 |

---

## Answers

`answers/` holds one `FIX-<case>.md` per case: the diagnostic path with real
output, the root cause, the exact fix, the reply we'd actually send, and the Plain
tickets and Linear issues where the same thing happened for real. The facilitator
removes that directory before distributing the repo and hands it out at the end.

---

## The committed `.env` files

Same policy as the Docker lab: every `.env` is committed and working, on purpose,
so pre-work stays two commands. Throwaway credentials, nothing reachable from the
internet. In real life `.env` goes in `.gitignore`. The bcrypt hash is single-quoted
for the same reason it was last time: Compose interpolates `$` in unquoted values.

---

## The one-page kit

[`CHEATSHEET.md`](CHEATSHEET.md): the Insights pipeline in one diagram, the four
queries, the two log lines, the real env vars with defaults, what counts as a
production execution, and the Insights-vs-billing table. Read it before you chase a
number.

---

## Cleaning up

```bash
./tools/teardown.sh
```

`docker compose down -v --remove-orphans` per stack, scoped by project name
(`inslab-*`). No `docker system prune`, ever.

---

## Layout

```
n8n-insights-lab/
├── README.md
├── CHEATSHEET.md
├── reference/                  the known-good stack, boot this first
│   ├── compose.yaml            commented: why each Insights setting is there
│   ├── .env
│   ├── verify.sh               fires a webhook and follows it through all three tables
│   └── workflows/              hello-webhook.json, imported on first boot
├── cases/
│   ├── 01-banner-missing/
│   ├── 02-frozen-after-migration/
│   ├── 03-stopped-after-cleanup/
│   ├── 04-time-saved-is-zero/           queue mode: adds redis + worker
│   ├── 05-more-than-the-executions-list/   nothing is broken; write the reply
│   ├── bonus-a-wont-start/              for fast finishers, 5 minutes
│   └── bonus-b-days-behind/             for fast finishers
├── answers/                    FIX-*.md, removed before distribution
└── tools/
    ├── lib.sh                  shared helpers: login, webhook, psql, wait-for-compaction
    └── teardown.sh
```

Each case directory holds the same files:

```
SYMPTOM.md   setup.sh   compose.yaml   .env   verify.sh   workflows/
HINT-1.txt   HINT-2.txt   HINT-3.txt
```

---

*This is Session 4. Session 2 (the Docker break/fix lab) and Session 3 (queue mode)
came before it, and case 04 assumes you remember what a worker is.*
