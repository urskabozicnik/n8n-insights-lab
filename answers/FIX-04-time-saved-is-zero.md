# FIX: case 04, time saved is zero

## The cracking command

There isn't a log line for this one. It's a comparison:

```bash
docker compose ps                    # n8n (main) and n8n-worker both running: queue mode
docker compose exec n8n printenv EXECUTIONS_MODE   # queue
```

plus query D on both workflows: `hello-webhook` (fixed) writes a type-0 row with
value 10, `invoice-matching` (dynamic) writes a type-0 row with value 0, every
time, even though the execution shows the Time Saved node ran on 5 items.

Then Linear: search "dynamic time saved queue mode" → **GOV-286**.

## Root cause (GOV-286, open, Urgent)

In queue mode the worker runs the execution and the main process records
Insights. Since 2.27.0 main rebuilds the finished run from the worker's
`JobFinishedProps`, which carries an empty `runData` unless something on main
needs the full execution data. Fixed time saved comes from the workflow
*settings*, which main has. Dynamic time saved comes from the Time Saved nodes'
*run data*, which main no longer loads. `extractTimeSavedFromNodes` finds no
nodes, records 0. Regression from PR #30969. Reproduced on 2.43.4. Not the
customer's fault, not the node's.

## The two options

1. **Workaround (keeps Per Item, the honest fix until the bug ships).** Make
   main load full execution data after every run by registering a no-op
   external hook. File `hooks/insights-workaround.js`:

   ```js
   module.exports = {
     workflow: {
       postExecute: [async function () { /* no-op: forces main to load full run data */ }],
     },
   };
   ```

   Mount it and set `EXTERNAL_HOOK_FILES=/hooks/insights-workaround.js` on the
   **main** service. `docker compose up -d`, run `/webhook/invoices`, query D
   shows 15. Cost: main reads full execution data for every run, which is what
   it did before 2.27 anyway. From Flaky's triage comment on GOV-286; test it
   on the customer's exact version before recommending.

2. **Fallback.** Switch the workflow's Estimated time saved to Fixed with an
   average per-run value (they said ~15). Works today, loses per-item accuracy.
   `verify.sh` passes with a note.

Either way: link GOV-286, say it's a confirmed regression, and ask them to
watch the release notes.

## What the customer lost

Dynamic time saved since September reads 0 and will stay 0. Execution counts
and runtimes are fine. If the board number matters, they can reconstruct it from
`execution_entity` (runs × average items × 3 min) for the quarter.

## The reply

You didn't do anything wrong: this is a confirmed regression in n8n since 2.27
(our tracking ID GOV-286) where, in queue mode, the main process no longer sees
the per-node data that dynamic time saved is calculated from, so it records 0
while the fixed-minutes setting keeps working. Until the fix ships you have two
options: add a tiny external hook on the main process (file and env var below),
which makes main load the full execution data again and brings Per Item back,
or switch invoice-matching to a fixed ~15 minutes per run for the quarter. The
zeros since September can't be corrected inside Insights, but the quarter's
number can be reconstructed from the execution count, and I can help with that
query.

## Where this shows up for real

GOV-286, T-A8914 (Able Aerospace), T-A10537 (Oyster, Daniel's reply has the
explanation), T-A10805 (AEB). Three tickets in the week of 16–22 Oct 2026.
