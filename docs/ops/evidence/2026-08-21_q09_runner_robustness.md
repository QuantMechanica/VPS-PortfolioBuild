# Q09_NEWS runner robustness — a single failing cell no longer aborts the experiment

Date: 2026-08-21
Author: Claude (Orchestrator)
Scope: `tools/strategy_farm/q09_news_runner.py` (executor loop + collection accounting) and
its test suite `tools/strategy_farm/tests/test_q09_news_runner_v2.py`.
ROT untouched: `q09_news_contract.py` `adjudicate()` and all v2 adjudication semantics are
byte-for-byte unchanged (verified: `git status --porcelain q09_news_contract.py` is empty).

## Problem

`execute_run_plan` aborted the whole 40-cell experiment at the **first** failing cell:

- A non-transient tester error (`RunnerError` from the dispatcher) wrote a single
  `execution_failure.json` pointer and `return`ed — 1 cell failed, the other 39 reported
  `missing`, the run over.
- A transient cell (`TransientCellError` = child exit-1 without a fresh tester summary) got
  exactly **one** in-attempt retry; a second transient either raised `CapacityError` to
  requeue the entire work item, or (at the work-item attempt ceiling) adjudicated-and-aborted.

Consequence: one flaky cell out of forty threw away the (potentially) 39 authenticated cells
that could still have run, and a wholesale-but-transient wedge bounced the whole item through
the requeue lane instead of producing a truthful maximal-evidence aggregate.

## Fix (core requirement)

The executor now treats each planned cell independently and **continues** past failures:

- **Bounded per-cell retry.** A transient class is retried up to `DEFAULT_CELL_RETRY_BUDGET`
  (=2) attempts *beyond the first* (3 attempts total). Each retry first waits for the exact
  claimed terminal root to clear and re-asserts factory capacity (and, on the diagnostic lane,
  re-verifies the staged expert EX5) before re-dispatch — the same safety the single retry had.
- **Record-and-continue.** After the retry budget is exhausted (transient) or on a
  non-transient tester/authentication error (no retry), the cell's immutable `cell_failure`
  sidecar is written and the loop moves on to the remaining planned cells.
- **`CapacityError` still aborts.** Genuine claim/host loss (capacity refusal) re-raises so the
  ordinary worker can requeue the whole item — that is infrastructure, not a cell result.
- **Pre-existing receipts never abort.** An already-present receipt is left for the terminal
  collector to classify (authenticated if valid, `cell_receipt_invalid` if contradictory)
  instead of aborting the run at the loop head.
- **No single-cell `execution_failure.json` is written any more.** The collector's per-cell
  `cell_failure` authentication path (previously the "backward-compatible" branch) is now the
  primary multi-failed path; the `execution_failure.json` *reader* is retained for old runs.

The run always ends by calling `collect_run_plan_status` → `adjudicate` → persist sidecar.
With incomplete/failed/invalid evidence the collector never calls the selector: it emits the
fail-closed non-locking verdict (`REVIEW_REQUIRED` / `INVALID_EVIDENCE`) exactly as before, so
the OWNER-facing adjudication semantics are unchanged.

## Accounting (matrix scope)

`collect_run_plan_status` now returns an explicit reconciliation so a partial run can never
silently drop a cell from the aggregate. Every planned cell lands in exactly one bucket:

```
authenticated + failed + missing + invalid == planned_cell_count
```

exposed as `accounted_cell_count` and `accounting_reconciled` on the result (derived; not added
to the hash-bound `aggregate.json` adjudication). `failed` authenticates each cell's own
`cell_failure.json`; `invalid` splits into `invalid_failure_cells` (bad sidecar →
`cell_failure_manifest_invalid`) and `invalid_receipt_cells` (bad receipt →
`cell_receipt_invalid`); `missing` is a receiptless cell with no failure sidecar.

## Tests

`python -m pytest tools/strategy_farm/tests/test_q09_news_runner_v2.py -q` → **27 passed**.

New / rewritten coverage:

- `test_single_transient_cell_exhausts_budget_then_run_continues` — requirement (i): one cell
  fails K+1 times; run continues; aggregate = 39 authenticated + 1 failed; verdict path
  unchanged (`REVIEW_REQUIRED` / `cell_execution_failed`); target dispatched exactly
  `budget+1` times with one terminal-exit wait per retry.
- `test_transient_cell_retry_succeeds_inside_same_attempt` — requirement (ii): transient then
  success on retry → 40 authenticated, `CONFIG_LOCKED`.
- `test_collect_status_reconciles_mixed_partial_buckets` — requirement (iii): 37 authenticated
  + 1 failed + 1 invalid receipt + 1 missing reconciles to 40 planned and fails closed
  (`INVALID_EVIDENCE` / `cell_receipt_invalid`); removing the invalid receipt → 38/1/0/1 and
  `REVIEW_REQUIRED` / `cell_execution_failed`.
- `test_failed_cell_authenticates_distinct_attempt_snapshots` — distinct immutable attempt
  snapshots per occurrence; tampering the authenticated occurrence-1 snapshot fails closed to
  `cell_failure_manifest_invalid`.
- `test_one_nontransient_cell_fails_while_the_rest_authenticate` — a non-transient cell is not
  retried; the run still completes all 40 cells → 39 authenticated + 1 failed.
- `test_all_transient_cells_recorded_failed_without_requeue` — a wholesale transient wedge no
  longer raises/requeues; every cell is retried within budget, recorded failed, aggregate
  written with exact accounting.
- `test_terminal_wait_timeout_fails_cell_closed_without_spawning_smoke` — updated: a
  claimed-terminal exit-wait timeout recurs per cell and records all 40 as failed without ever
  spawning run_smoke.

Unrelated pre-existing failure (NOT caused by this change; fails identically on the baseline):
`test_q09_live_news_diagnostic.py::…accepts_only_review_sidecar` compares a Windows 8.3
short-path (`ADMINI~1`) against the long path (`Administrator`) — a tempdir normalization
quirk in that diagnostic test only.

## Risk / follow-up

- Wedge-recovery latency: a genuine terminal wedge that surfaces as a per-cell `RunnerError`
  (e.g. exit-wait timeout) now fails all 40 cells one-by-one before the aggregate, instead of
  the old fast abort+requeue. This is truthful (maximal accounting, fail-closed verdict) and
  the orchestrator recovers via an append-only rerun, but if wedge latency becomes a concern a
  follow-up could reclassify the exit-wait timeout as a `CapacityError` (abort+requeue). Not
  done here to stay within the stated requirement.
- `WORK_ITEM_ATTEMPT_CEILING` is retained (still equals `terminal_worker.MAX_WORK_ITEM_RETRIES`)
  but is no longer consulted by the executor loop.

## Append-only pilot rerun under the fixed runner

The runner is claimed by the ordinary factory pump; there is no manual `execute` step. To rerun
the 40-cell v2 pilot append-only (a fresh, unclaimed pending `Q09_NEWS` rerun row is required —
the prior work item's `q09_news_tests` evidence is immutable and blocks re-binding the same id):

```powershell
# 1. Seal an immutable plan for the rerun row (same sealed inputs as the reference pilot).
python tools/strategy_farm/q09_news_runner.py plan `
  --work-item-id $rerunWid `
  --candidate-lineage-key $lineageKey `
  --deployment-target DXZ `
  --q08-work-item-id $q08 --q08-evidence $q08Evidence `
  --baseline-setfile $baseline --ex5 $ex5 --include-closure $includeClosure `
  --calendar-manifest $calendarManifest `
  --calendar-common-relative-path "QM/q09_news/$bundleId/events.csv" `
  --full-from-utc 2019-01-01T00:00:00Z --full-to-utc 2025-12-31T23:59:59Z `
  --selection-from-utc 2019-01-01T00:00:00Z --selection-to-utc 2023-12-31T23:59:59Z `
  --holdout-from-utc 2024-01-01T00:00:00Z --holdout-to-utc 2025-12-31T23:59:59Z `
  --complete-months 60 --holdout-complete-months 24 `
  --tester-model REAL_TICKS --cost-profile DXZ_CANONICAL_REAL_TICKS_V1 `
  --output-root $planRoot
$plan = "$planRoot\run_plan.json"
$planSha = (Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash.ToLowerInvariant()

# 2. Hash-bind the sealed plan to the pending rerun row (append-only; the old row stays as evidence).
python tools/strategy_farm/farmctl.py bind-q09-plan `
  --work-item-id $rerunWid --plan $plan --plan-file-sha256 $planSha --cell-timeout-sec 3600
```

After binding, the pump/terminal worker claims the pending `Q09_NEWS` row and runs the fixed
executor. A single flaky cell now yields a maximal-authenticated + precise-failed/missing
aggregate (`REVIEW_REQUIRED`) rather than aborting the rerun.
