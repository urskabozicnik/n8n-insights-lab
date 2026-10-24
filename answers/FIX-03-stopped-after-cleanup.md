# FIX: case 03, stopped after cleanup

## The cracking command

```bash
docker compose logs --since=1m n8n | grep -i 'saving insights'
# Error while saving insights metadata and raw data ... Could not find shared workflow for insight with workflowId InsLabNightly0003
```

every 5 seconds, same workflowId every time.

## The path

1. The customer's two facts: `insights_by_period` stops Tuesday 15:00 and
   `insights_raw` is "basically empty". An empty raw table while hundreds of
   executions run a day means nothing reaches the database at all. That's stage
   2/3, the flush, not compaction. (If compaction were dead, raw would be huge.)
2. Debug log, no grep, 30 seconds: the flush fires, fails, and the same error
   repeats on the next cycle. The message names a workflow it can't attribute.
3. `SELECT * FROM shared_workflow WHERE "workflowId"='InsLabNightly0003';` is
   empty. `SELECT name, active FROM workflow_entity WHERE id='InsLabNightly0003';`
   says it is active and runs every 10 seconds. The "orphaned rows" cleanup
   deleted the ownership row of a live workflow.
4. Why does one workflow stop everything? On 2.33.0 the flush writes the whole
   buffer in one go; when one event throws, the catch re-buffers the entire batch
   including the bad event, and the next flush fails the same way. Every new
   execution joins the stuck batch. This was fixed in 2.41.0 (PR #38518): the
   un-attributable event is dropped with one log line and the rest persists.
5. Fix, two steps, both needed on this version:
   - Restore attribution. Either put the row back
     (`INSERT INTO shared_workflow ("workflowId","projectId",role) SELECT 'InsLabNightly0003', id, 'workflow:owner' FROM project WHERE type='personal' LIMIT 1;`)
     or deactivate/delete the nightly workflow properly through the UI or
     `n8n update:workflow --id=InsLabNightly0003 --active=false`.
   - Restart main: `docker compose restart n8n`. The poisoned buffer lives in
     memory; fixing the data doesn't un-stick it.
6. `./verify.sh`.

## Can the compaction job be restarted without restarting n8n?

The compaction job isn't the problem, and no, nothing in Insights can be
restarted on its own. The buffer is in the main process. The honest answer to
their question is: a restart of main is required, it takes seconds, and the
nightly syncs on a schedule trigger will resume on their next tick.

## What the customer lost

Everything from Tuesday 15:00 until the restart. The stuck batch is in memory
and is discarded on restart; nothing after the first failure was ever written.
Executions list is intact, so if Finance needs the number they can count
`execution_entity` rows for the period, but Insights will show a gap forever.

## The reply

Your Tuesday cleanup removed the `shared_workflow` row for "nightly-sync", which
is still active, and from that moment every Insights write has failed with
"Could not find shared workflow for insight with workflowId …" (it's in your
logs every 30 seconds). On 2.33 one unattributable execution blocks the whole
batch, so nothing since Tuesday reached the database, and that data can't be
recovered from Insights; the executions list still has it if Finance needs a
count. Restore the row (statement below) or deactivate that workflow, then
restart the main process once; the buffer can't be cleared any other way. 2.41
and later drop the bad event instead of stalling, so updating removes the
sharp edge.

## Where this shows up for real

GOV-112 (deepki, LifeLoop T-88469, IP-Agency), LIGO-829, LIGO-1115 / GH #37788,
GOV-210 (Withings: whole weeks lost, now a billing dispute), T-62514 (Wayfair,
where the orphaned-rows advice came from), T-99860 (bunq). Krystian's reply on
T-88469 is the best written explanation of the mechanism.
