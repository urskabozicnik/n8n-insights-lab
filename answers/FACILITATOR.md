# Facilitator notes

Read this before the dry run. The lab was written against 2.33.0 from the
documented behaviour, the n8n source on master and the tickets, and it has not
yet been run end to end on a laptop. Do a full dry run a week before the session
and expect to adjust the items below.

## Dry run checklist

1. `reference/verify.sh` passes. If step 6 or 7 fails, the column names in
   `tools/lib.sh` are wrong for 2.33.0. Check them with
   `docker compose exec postgres psql -U n8n -d n8n -c '\d insights_raw'` and
   `'\d insights_by_period'`, `'\d insights_metadata'`. The scripts assume
   `metaId`, `type`, `value`, `timestamp`, `periodUnit`, `periodStart`,
   `workflowId`, `workflowName`.
2. Case 03: confirm the flush on 2.33.0 fails with
   `Error while saving insights metadata and raw data` when `shared_workflow`
   is missing for an active workflow. If 2.33.0 handles it differently (for
   example only logs a warning and continues), the case needs a different
   poison: deleting the `project` row instead, or deleting the workflow row
   directly in SQL while it is active. The mechanism (one bad event re-buffers
   the batch) is in versions before 2.41.0; the exact trigger may vary.
3. Case 04: confirm on 2.33.0 that a dynamic run in queue mode records 0 (GOV-286
   says the regression is from 2.27.0, reproduced on 2.43.4). Then confirm the
   `EXTERNAL_HOOK_FILES` no-op `workflow.postExecute` hook makes it 15. If the
   hook doesn't work, keep the case and make the Fixed-mode switch the only
   accepted fix; `verify.sh` already allows it.
4. Case 02: the seeded history insert uses `generate_series`; it takes a few
   seconds. Confirm compaction fails with the PK name
   `PK_b606942249b90cc39b0265f0575`; if the constraint name differs on 2.33.0,
   update HINT-2 and the cheatsheet.
5. Case 05: `EXECUTIONS_DATA_PRUNE_SOFT_DELETE_INTERVAL` and
   `..._HARD_DELETE_INTERVAL` are in minutes. Confirm pruning actually trims
   the list to ~50 within the 75-second wait in `setup.sh`; if not, raise the
   sleep or lower the count.
6. Bonus B: confirm `MAX_BATCHES_PER_RUN=1` with `BATCH_SIZE=1` is accepted
   (no zod validation rejecting it on 2.33.0) and that the backlog genuinely
   doesn't drain.
7. `import_workflows` in `tools/lib.sh` imports via `n8n import:workflow
   --separate --input=/workflows` and activates with `n8n update:workflow`.
   Confirm imported workflows land in the owner's personal project; if not,
   add `--userId` with the owner's id from `SELECT id FROM "user"`.
8. Time budget: cases 02, 03 and 05 need 1 to 2 minutes of waiting inside
   `setup.sh`. Have everyone run `./setup.sh` for their assigned case during
   the intro.

## Optional licence

`N8N_LICENSE_ACTIVATION_KEY` in `reference/.env` and uncomment the line in
each `compose.yaml` (or just the reference). With an Enterprise trial key the
browser shows the full dashboard, which makes case 02's "frozen line" and case
04's zero visible without SQL. Nothing in `verify.sh` needs it.

## Distribution

Delete this directory before sharing the repo. Zip it separately with a
password per case if you want the Docker-lab workflow, or just hand it out at
the end.

## Session plan (fits the 60-minute agenda in the proposal)

0:00 reference stack up, everyone, while the intro runs (10 min talk)
0:10 pairs assigned to cases 01 to 05 (two pairs on 03 and 04, they're the
     ones that generate tickets right now); `./setup.sh` immediately
0:12 work; hints at +5, +10, +15
0:32 report-backs, 4 min each, cracking query on the board
0:52 open bugs and Q&A with Guillaume
1:00 done; bonus cases and answers go out afterwards
