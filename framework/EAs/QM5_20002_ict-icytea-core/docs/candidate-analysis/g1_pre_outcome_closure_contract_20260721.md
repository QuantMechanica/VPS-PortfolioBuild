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
- `D:\QM\reports\qm20002\short_ny_reverse_time\runs\20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5\g1_pre_outcome_quiescence_anchor.json`
- `D:\QM\reports\qm20002\short_ny_reverse_time\runs\20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5\g1_pre_outcome_closure_receipt.json`

All three are sealed by the frozen G1 control-path helper and published with
create-if-absent hard-link semantics (`replace=False`). An existing artifact is
accepted only when its strict schema and every immutable binding are identical.

The intent binds OWNER authorization, the closure utility and task-helper
bytes, the frozen runtime files, commit
`9f258f9fa2cc84746c34f76859888274ca60cf15`, the exact PRE/auth/consumption/job,
the original state SHA-256
`7aa51ce458420431db4cac94e500d3da07b82261312ba334cb80a7b420433ce7`, and a
read-only proof that the exact task was `Ready`, enabled, never run, and had
zero non-null triggers. It also retains the complete original launch-state
payload; its canonical bytes must reproduce the bound path, size, and SHA-256.

The quiescence anchor is created after a fresh `AwaitQuiesced` proof but before
the final state is published or the task is unregistered. It retains the full
canonical `QUIESCE_PENDING` state payload and binding, the complete disabled
task evidence, task contract/XML, helper/principal, both full-probe hashes, and
the durable race disposition. The CLOSED terminal binds both the anchor file
SHA-256 and the canonical SHA-256 of its path/size/hash binding. Thus recovery
after task removal cannot manufacture a new final quiescence explanation from
mutable terminal hash strings.

The PRE is validated as the exact historical byte snapshot identified by its
fixed SHA-256, including its closed schema, outcome fence, canonical four-cell
plan, recorded binding shapes, and control-path ACL. The procedure deliberately
does not rerun PRE against later versions of unused runner inputs: no runner is
executed during closure, and a subsequent repository update must not rewrite a
sealed historical launch decision. The G1 auditor, scheduled-task helper, and
control-path helper used by this closure are nevertheless rehashed separately
against their exact historical bindings at every durable boundary.

Every PRE binding below `C:\QM\repo` is also checked against Git provenance.
Twenty-seven bindings must equal the raw blob at freeze commit
`9f258f9fa2cc84746c34f76859888274ca60cf15`. There is one deliberately narrow
exception for `framework/scripts/run_smoke.ps1`: the reviewed freeze captured
mixed-EOL worktree bytes (115860 bytes,
`634fd4a012135372b9c9e73b522978ba8cc54453051f1d7204443a124839575a`), which
Git normalization did not preserve byte-for-byte. That exception is accepted
only when the exact committed freeze manifest repeats those values, names
commit `adf26cd8b1ea61a306c9949217aad139a9971ab9`, that commit is an ancestor of
the freeze commit, its raw blob is exactly 113224 bytes with SHA-256
`92c324dad414deae95f453d77d2c4d2aa12d27292caf590c972c9c168d181c84`, and
`git cat-file --filters` yields exactly 115894 bytes with SHA-256
`665f392c5923e9f5002792b5984df01dce1437c3d2ba3e0cc6081e1fc45bbfe4`.
No other path, commit, size, hash, or normalization exception is permitted.

## Transition and lock order

1. Verify all immutable bindings and both one-byte lock files.
2. Acquire `authorization/.launch.global.lock`, then the run's
   `.launch_state.json.terminal.lock`.
3. Require the exact `PENDING`, `resume_count=0` state with null worker,
   active cell, outcome timestamp, terminal, and empty cells. The `worker`
   tree and `post_receipt.json` must be absent; only path metadata is queried.
4. Publish or validate the immutable OWNER intent.
5. Re-prove the exact scheduled task and compare-and-swap the original state
   to a schema-valid `QUIESCE_PENDING` terminal `REJECT` while both locks are
   still held. The pre-terminal probe accepts only exact `Ready` or `Running`
   state with unchanged identity/XML/contract and zero triggers. This one
   pre-terminal probe may retain stable observed DEV1 owner/root inventory.
   Only `Ready` plus `never_run=true` is classified as no
   race; `Running`, or `Ready` plus `never_run=false` after a very short start,
   is durably classified as a start race before either lock is released. The
   terminal carries the complete canonical pre-terminal probe as URL-safe
   Base64 JSON plus its SHA-256 and already has
   `outcome_fence_crossed=false` and `no_resume=true`.
6. Disable the exact task under those locks. A concurrently started exact task
   blocks on the state lock and, after release, can only observe the already
   durable terminal REJECT. The complete successful Quiesce transition probe
   is appended atomically to the pending terminal as canonical Base64 JSON plus
   SHA-256 before the locks are released. A recovery that finds the task
   already disabled can re-run this transition idempotently.
7. Wait outside the locks until the task is disabled and non-running. Reacquire
   both locks, publish or exactly validate the immutable quiescence anchor, then
   finalize the terminal with the anchor binding, canonical quiesced-evidence
   SHA, disabled XML SHA, task-contract SHA, and explicit race disposition.
8. Revalidate every immutable original state field plus Job/Auth/Scheduler/PRE
   and the anchor, release both locks, unregister only that exact disabled task,
   and prove it absent with the inference basis selected by the durable race
   disposition.
9. Reacquire the same global-to-state lock order, reassert all historical
   bytes, the exact DEV1 pre-launch run inventory, intent/state, and
   anchor. Obtain a new native absence probe and publish the immutable closure
   receipt. An existing receipt must contain exactly that fresh probe, not just
   a self-consistent recomputed wrapper hash.

Artifact ordering is checked before any later-phase mutation. Untouched
`PENDING` permits neither anchor nor receipt, even when recovering a valid
after-intent crash. `QUIESCE_PENDING` forbids a receipt and permits an anchor
only when its complete pending-state/evidence payload validates exactly.
`CLOSED` requires its bound anchor; a pre-existing receipt is accepted only
when the task is already absent and the receipt recursively matches a fresh
absence proof. A foreign early receipt therefore cannot cause task removal
before it is detected.

The receipt binds state before and after, the intent, all historical artifacts,
ready/quiesced task and XML proofs, the final absence proof, and explicitly
records `outcome_data_read=false`.

The ready proof always records `never_run=true`. The quiesced proof records
`never_run=true` only when `task_start_race_observed=false`; if the exact task
started during the Ready-to-disable race, both the durable terminal disposition
and receipt record `task_start_race_observed=true` and quiesced
`never_run=false`. Any disagreement between the native quiesced evidence,
terminal disposition, and receipt is rejected.

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

One narrow exception applies to the pre-terminal `Ready`-or-`Running` probe
while the caller holds the state lock: a racing task may already have created a
DEV1 process. That probe records stable nonnegative owner/root counts, native
identity hash, method, and double-snapshot proof without rejecting before the
durable terminal state is published. The complete evidence is canonically
retained inside the full pre-terminal probe in `QUIESCE_PENDING`. Quiesce,
AwaitQuiesced, final-state, absence, and receipt validation continue to require
exact zero DEV1-owner/root counts. The full pre-terminal and successful Quiesce
probe payloads and their SHA-256 values are carried unchanged from
`QUIESCE_PENDING` into the CLOSED terminal error. The anchor and receipt bind
those hashes, so finalization cannot discard the race-time inventory, forget a
Quiesce-only race, or downgrade its race disposition.

## Crash recovery

Recovery is idempotent at every durable boundary:

| Crash boundary | Recovery action |
| --- | --- |
| Intent published | Validate intent, then quiesce |
| Preliminary REJECT published | Disable/drain the task; no instance can pass the state lock |
| Task disabled before Quiesce proof publication | Re-run idempotent Quiesce and append its full probe |
| Quiesce proof published, terminal pending | Decode/revalidate both full probes and await exact quiescence |
| Quiescence anchor published | Validate its full pending-state/evidence payload, then finalize REJECT |
| Final REJECT state published | Validate the bound anchor, then unregister |
| Task unregistered | Revalidate state and anchor, obtain a fresh race-aware absence proof, publish receipt |
| Receipt published | Validate bytes and return `ALREADY_CLOSED` |

Recovery tests restart with a fresh runtime object containing only persistent
scheduler properties; no prior probe payload or in-memory race flag is needed.
Concurrent identical invocations serialize on the global/state locks. A race
after lock release is accepted only if the loser can prove the exact task is
already absent. Any byte, schema, ACL, artifact phase, task, state, process, or
outcome-path drift fails closed.

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
