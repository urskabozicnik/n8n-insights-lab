# FIX: case 02, frozen after migration

## The cracking command

```bash
docker compose logs --since=2m n8n | grep -i 'duplicate key'
# ... duplicate key value violates unique constraint "PK_b606942249b90cc39b0265f0575"
```

or the query that explains it:

```sql
SELECT last_value FROM insights_by_period_id_seq;      -- 1
SELECT MAX(id) FROM insights_by_period;                -- 1500-ish
```

## The path

1. The customer said `insights_raw` "has loads of rows". That's stage 3 working
   (flush is fine). The dashboard reads `insights_by_period`. Query B from the
   cheatsheet: raw_rows growing, `last_hour_bucket` stuck on the migration day.
   So stage 4, compaction, is the broken one.
2. Compaction runs every minute in the lab. `docker compose logs --since=2m n8n | grep -i insight`
   shows the run starting and failing with the PK violation. The customer
   grepped for "insights" and "fail"; the error line contains neither word in a
   way their grep caught, or they only looked at the tail.
3. Compaction inserts into `insights_by_period` using the id sequence. The
   migration copied rows (ids up to ~1500) but not the sequence position, which is
   still at 1. Every insert collides.
4. Fix:
   ```sql
   SELECT setval(pg_get_serial_sequence('insights_by_period','id'), (SELECT MAX(id) FROM insights_by_period));
   ```
   No restart needed. The next compaction run succeeds and starts eating the
   backlog.
5. `./verify.sh`.

## Root cause

Postgres identity sequence on `insights_by_period` behind `MAX(id)` after a
SQLite → Postgres data copy. LIGO-285 (Coupa, Engel & Völkers), GOV-112's
sequence-drift variant (IP-Agency), T-83013 (Guesty). On Cloud this happens
after Enterprise Scaling migrations and the customer can't run the fix; Support
or medic does.

## What the customer lost

Nothing. This is the one case in the lab where the gap is recoverable: the raw
rows for all eleven days were persisted, compaction just couldn't fold them.
Once the sequence is fixed the backlog compacts and the dashboard fills in. Check
after a few minutes: query C per day shows the eleven days.

## The reply

The live data did come over: `insights_raw` has every execution since the 13th.
What the migration didn't bring is the position of the id sequence on
`insights_by_period`, so every hourly compaction run since then has failed with a
duplicate-key error (you can see it in the logs with `grep "duplicate key"`),
and the dashboard only reads the compacted table. Run the `setval` statement
below once, no restart needed, and within an hour the eleven days will appear on
the dashboard; nothing was lost.

## Where this shows up for real

LIGO-285, GOV-112, T-59635, T-83013, T-85817, community thread 245912. KB:
"Enterprise Scaling Migration – Stale Postgres Identity Sequences".
