# Q09_NEWS activation and Q10 predecessor-contract repair

**Date:** 2026-08-04

**Router task:** `b0bbc95d-1b16-4211-99fc-88dd9bfa872b`

**Disposition:** `REVIEW` — the enqueue/claim race and misleading Q10 refusal
are fixed and tested. Production Q09/Q10 work remains fail-closed because the
exact governed Q09 inputs and the required same-lineage Q09_PORTFOLIO evidence
do not yet exist. No pipeline verdict is inferred by this document.

## Outcome

The historical 18-row stall and the suspected verdict mismatch are two
different findings:

1. The stall was real. The ordinary `terminal_worker.py` process should claim a
   Q09_NEWS row and obtain its command through
   `farmctl._spawn_phase_runner_for_work_item`; the command invokes
   `q09_news_runner.execute`. On 2026-07-31 the executor/binding path was not yet
   available. The worker claimed each row, found no runnable phase command, and
   terminalized it as `done/PENDING_RUNNER` with
   `verdict_reason="phase runner not implemented yet -- skipping for now"`.
   Adding the executor later did not revive terminal rows.
2. The suspected permanently unsatisfiable Q10 verdict literal was not present
   in the current canonical code. Both the Q09 contract and the Q10 predecessor
   query already use `CONFIG_LOCKED` as the only governed good Q09_NEWS verdict.
   The refusal string was hard-coded to say `PASS`, so the operator-facing
   diagnostic contradicted the query. The repair centralizes the literal and
   makes the diagnostic print the actual accepted verdict.

There was also an enqueue-to-bind race after the executor landed: enqueue
created a normal pending Q09_NEWS row, while plan creation and binding were
separate later operations. A resident worker could claim the row between those
operations and park it as `PENDING_RUNNER` before a sealed plan existed.

## State evidence

A read-only query of
`D:\QM\strategy_farm\state\farm_state.sqlite` during this task found:

- exactly 18 Q09_NEWS rows;
- all 18 are `done/PENDING_RUNNER`;
- their creation/update window is 2026-07-31 06:03Z–06:19Z;
- none has an evidence path;
- `q09_news_tests` contains zero rows.

The task's two historical Q09 rows are:

| EA | Historical Q09_NEWS | Historical Q08 input | State |
|---|---|---|---|
| QM5_11422 / USDCAD.DWX | `87af2578-b9ba-4010-9776-07faa4e729d5` | `6f2bc654-3a18-40d8-9959-e4984591c6d3` | `done/PENDING_RUNNER`, no evidence |
| QM5_13036 / GDAXI.DWX | `7efd8e39-4d1c-4b6d-8cfd-637122aad25f` | `85aadb10-6860-43df-bfb4-8c164246efc2` | `done/PENDING_RUNNER`, no evidence |

The current-binary Q08 inputs requested by the task are valid terminal PASS
rows:

| EA | Fresh Q08 PASS | Current EX5 SHA-256 | Evidence |
|---|---|---|---|
| QM5_11422 | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | `D:\QM\reports\work_items\9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270\QM5_11422\Q08\USDCAD_DWX\aggregate.json` |
| QM5_13036 | `fb3f0e20-1982-4f51-9e4b-52da2629a5ac` | `2cd0f7270572d37bd67ca0d1f724eaad95d756b4af18859d2dd0203d0045b0be` | `D:\QM\reports\work_items\fb3f0e20-1982-4f51-9e4b-52da2629a5ac\QM5_13036\Q08\GDAXI_DWX\aggregate.json` |

No Q09_PORTFOLIO row depends on either fresh Q08 row. The only historical
portfolio rows are `99ab79c9-1c13-40ff-8b71-0b72fd05db91`
(`QM5_11422`, `PASS_PORTFOLIO`, legacy/no fresh dependency) and
`6655a7d3-ac3c-458e-b374-a06ef5e5d01f`
(`QM5_13036`, `FAIL_PORTFOLIO`, legacy/no fresh dependency). Q10's schema gate
requires a `PASS_PORTFOLIO` sibling bound to the same Q08 input as the
`CONFIG_LOCKED` news row. The old rows cannot satisfy that requirement.

Read-only Q10 enqueue probes against the two historical PENDING_RUNNER rows
made no rows and returned the corrected governed requirement:

```text
No done Q09_NEWS CONFIG_LOCKED work_items found for QM5_11422 matching predecessor 87af2578-b9ba-4010-9776-07faa4e729d5
No done Q09_NEWS CONFIG_LOCKED work_items found for QM5_13036 matching predecessor 7efd8e39-4d1c-4b6d-8cfd-637122aad25f
```

## Fail-closed repair

The repair is additive and preserves old work-item interpretation:

- Every new or explicitly requeued Q09_NEWS row is created with
  `q09_activation_state=AWAITING_SEALED_PLAN` and a non-restart-releasable
  `Q09_AWAITING_SEALED_PLAN` database hold in the same transaction as its Q08
  dependency.
- `bind-q09-plan` authenticates and writes the complete self-hashed dispatch
  binding, changes the state to `RUNNABLE_BOUND`, and releases only that exact
  activation hold in the same transaction. A different active hold is never
  overwritten or released.
- The generic pending-claim selector independently refuses Q09_NEWS rows that
  lack the complete binding version, plan path, plan-file hash, and dispatch
  binding hash. This is defense in depth for the next worker load.
- A pre-repair pending row with a complete binding and no activation-hold row
  remains bind-compatible. Historical terminal rows are not mutated or revived.
- Pump cascade and explicit enqueue now share the single
  `Q09_NEWS_SUCCESS_VERDICTS = {CONFIG_LOCKED}` contract. A plain `PASS` remains
  rejected; `REVIEW_REQUIRED` and `INVALID_EVIDENCE` remain non-locking.
- The no-predecessor response renders the real accepted verdict instead of the
  hard-coded word `PASS`.

### Pump versus resident-worker effect

The activation hold is immediately effective for already-running terminal
workers because those processes already consult the generic
`work_item_holds.active` database contract on every claim. No worker restart is
required to close the enqueue-to-bind race. After a successful bind, releasing
that hold makes the row eligible to the resident worker, whose loaded code
already includes the Q09 executor. The additional JSON-binding predicate in
the claim SQL takes effect when workers next load this version; it is a second
guard, not a reason to restart active T1–T10 work.

No worker, tester, or terminal was stopped or started for this repair.

## Runtime-decision and activation state

`tools/strategy_farm/farmctl.py` is part of the Factory runtime-decision source
binding. This additive edit deliberately does not rewrite or pretend to satisfy
that OWNER decision. A read-only validation after the edit fails closed:

```text
RuntimeActivationError: tools/strategy_farm/farmctl.py SHA-256 mismatch:
expected=739dd0afe996f2ad7cff14d4f11dd03d7ad013f05f2ab6294995f1c1bd4e97f3
actual=15861ebd617a6e7b51f87b42463598511c0fe1f599cd50f442245f00d584dbf6
```

The currently running Factory was not restarted. A future intentional Factory
activation/restart requires a fresh OWNER-ratified runtime decision that binds
the landed source bytes.

The Q09 executor and effective-calendar-input implementation exist and have
completed separate review, but the broad W7 migration/apply programme is still
recorded in
`docs/ops/MASTER_PIPELINE_BOOKS_IMPLEMENTATION_PLAN_2026-07-29.md` as
`DRY_RUN_SOURCE_IMPLEMENTED_OWNER_APPLY_BLOCKED`. No OWNER-approved Q09 v2
`q09cal-*` bundle manifest or reviewed current-EX5 recursive include-closure
manifest was found for these two candidates. The current general calendar
publication at `D:\QM\data\news_calendar` is not silently promoted to that
different contract. Therefore this task does not claim W-program activation
and did not fabricate the missing hashes or manifests.

## Governed bridge for the two requalification chains

The append-only bridge is explicit and stops on every refusal or non-good
pipeline verdict:

1. OWNER ratifies the exact content-addressed Q09 v2 calendar bundle derived
   from the governed current calendar publication, and review produces the
   exact recursive include-closure manifest for each current EX5.
2. Enqueue one Q09_NEWS append-only rerun from fresh Q08
   `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270`, citing historical Q09
   `87af2578-b9ba-4010-9776-07faa4e729d5`. The activation hold prevents claim
   until its authenticated run plan is bound. Let the ordinary worker produce
   the verdict and sidecar evidence.
3. Produce a fresh same-Q08 Q09_PORTFOLIO row and require pipeline
   `PASS_PORTFOLIO`. If the news verdict is not `CONFIG_LOCKED`, or the
   portfolio verdict is not `PASS_PORTFOLIO`, stop the chain.
4. Only when both dependencies pass, enqueue a Q10 append-only rerun of
   `6f9400fa-9ca2-4835-9fcf-e1087289f9b1` and let the pipeline produce its
   evidence.
5. Repeat serially for fresh Q08
   `fb3f0e20-1982-4f51-9e4b-52da2629a5ac`, historical Q09
   `7efd8e39-4d1c-4b6d-8cfd-637122aad25f`, and historical Q10
   `788d2371-4a37-42c3-b9b1-18d9fb09bd3f`, again requiring a same-lineage
   `PASS_PORTFOLIO` sibling.

Steps 2–5 were not executed in this task. Doing so without the ratified bundle
and include closure would weaken the sealed-input gate; enqueuing Q10 without
same-lineage `PASS_PORTFOLIO` would bypass the paired dependency gate. The
historical QM5_13036 portfolio verdict is a further warning, not evidence for a
new verdict.

## Verification

Syntax and focused contract suite:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/q09_news_schema.py \
  tools/strategy_farm/q09_news_runner.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py

19 passed in 8.48s
```

Expanded Q09 calendar/schema/runner/farmctl/Q10/terminal-worker suite:

```text
97 passed, 1 deselected in 42.70s
```

Coverage includes an unbound row being unclaimable, transactional creation of
the explicit hold, bind-time state transition and hold release, rejection of a
plain Q09 `PASS`, the exact `CONFIG_LOCKED` diagnostic, and the existing Q09/Q10
binding and sidecar contracts. `git diff --check` reported no whitespace
errors. The one deselected case is the unrelated pre-existing watchdog
PowerShell string-position assertion; its uncurated run was the sole failure
while all selected Q09/Q10 tests passed.

The backtest risk/news guardrails were not changed: Q09 still requires
`RISK_FIXED > 0`, `RISK_PERCENT = 0`, and
`qm_news_stale_max_hours <= 336`. No T_Live or AutoTrading setting was touched,
no `terminal64.exe` was started manually, and no active T1–T10 backtest was
interrupted.
