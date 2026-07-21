# QM20002 G1 pre-outcome closure contract (2026-07-21)

## Scope

This utility closes only the untouched G1 launch
`20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5`. It exists because the
registered scheduled task has a null trigger collection. That is an exact
zero-trigger task, but it violates the scheduler helper's collection-shape
contract. The durable reason code is
`SCHEDULER_TRIGGER_NULL_COLLECTION_CONTRACT_DEFECT`.

The closure does not launch or resume the worker, invoke MT5, open a worker
artifact, inspect a report, run POST, or read strategy outcomes. The frozen G1
auditor, scheduler helper, control-path helper, PRE, authorization,
authorization consumption, launch job, and runtime-freeze bytes are read-only.

## Exact artifacts

The only run artifacts created by this procedure are:

- `D:\QM\reports\qm20002\short_ny_reverse_time\runs\20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5\g1_pre_outcome_closure_intent.json`
- `D:\QM\reports\qm20002\short_ny_reverse_time\runs\20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5\g1_pre_outcome_closure_receipt.json`

Both are sealed by the frozen G1 control-path helper and published with
create-if-absent hard-link semantics (`replace=False`). An existing artifact is
accepted only when its strict schema and every immutable binding are identical.

The intent binds OWNER authorization, the closure utility and task-helper
bytes, the frozen runtime files, commit
`9f258f9fa2cc84746c34f76859888274ca60cf15`, the exact PRE/auth/consumption/job,
the original state SHA-256
`7aa51ce458420431db4cac94e500d3da07b82261312ba334cb80a7b420433ce7`, and a
read-only proof that the exact task was `Ready`, enabled, never run, and had
zero non-null triggers.

## Transition and lock order

1. Verify all immutable bindings and both one-byte lock files.
2. Acquire `authorization/.launch.global.lock`, then the run's
   `.launch_state.json.terminal.lock`.
3. Require the exact `PENDING`, `resume_count=0` state with null worker,
   active cell, outcome timestamp, terminal, and empty cells. The `worker`
   tree and `post_receipt.json` must be absent; only path metadata is queried.
4. Publish or validate the immutable OWNER intent.
5. Re-prove the exact scheduled task, disable it under both locks, and prove
   `Disabled`, never-run, zero-trigger quiescence.
6. Compare-and-swap the exact original state to a state-schema-valid `REJECT`.
   Its terminal has `outcome_fence_crossed=false`, `no_resume=true`, and an
   error string binding the intent SHA, canonical quiesced-evidence SHA,
   disabled task XML SHA, and task-contract SHA.
7. Release both locks. Re-prove the disabled task, unregister only that exact
   task, and prove it is absent.
8. Reacquire the same global-to-state lock order, reassert the intent/state and
   absence proof, then publish the immutable closure receipt.

The receipt binds state before and after, the intent, all historical artifacts,
ready/quiesced task and XML proofs, the final absence proof, and explicitly
records `outcome_data_read=false`.

## Process proof

The task helper does not request or emit process command lines and does not use
WMI owner-method calls. It snapshots processes through native process handles,
opens each token for its SID, obtains the native image path, and requires two
stable relevant snapshots. A process that exits before handle capture is
treated as exited, not as an owner-query failure. The Windows Registry kernel
pseudo-process is recognized only by its exact name, SYSTEM SID, and native
no-user-image behavior.

Direct evidence is reported for DEV1-owner and DEV1-root image counts. The
matching-worker count is clearly labeled as an inference from the task's exact
never-run/non-running history plus those direct zero counts; it is not presented
as a command-line match.

## Crash recovery

Recovery is idempotent at every durable boundary:

| Crash boundary | Recovery action |
| --- | --- |
| Intent published | Validate intent, then quiesce |
| Task disabled, original state retained | Re-prove disabled task, publish REJECT CAS |
| REJECT state published | Read task/XML proof hashes from terminal error, unregister |
| Task unregistered | Prove absence, publish receipt |
| Receipt published | Validate bytes and return `ALREADY_CLOSED` |

Concurrent identical invocations serialize on the global/state locks. A race
after lock release is accepted only if the loser can prove the exact task is
already absent. Any byte, schema, ACL, task, state, process, or outcome-path
drift fails closed.

## Invocation freeze

After code review, calculate the SHA-256 of both closure files and invoke the
utility with a fresh OWNER UTC and those exact hashes:

```powershell
python framework\EAs\QM5_20002_ict-icytea-core\tools\candidate_analysis\close_qm20002_g1.py `
  --authorized-utc <fresh-owner-utc-with-Z> `
  --expected-utility-sha256 <frozen-utility-sha256> `
  --expected-task-helper-sha256 <frozen-task-helper-sha256>
```

This document does not authorize execution. The utility must be reviewed and
its exact hashes communicated before the OWNER-bound closure is run.
