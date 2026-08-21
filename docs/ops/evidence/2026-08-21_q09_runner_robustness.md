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

## Addendum 2026-08-21 (Claude, board-advisor) — two precise runner additions

Building on `fa49b2c84` (continue-on-cell-failure + K=2 transient retry). ROT untouched:
`q09_news_contract.py` `adjudicate()` remains byte-for-byte unchanged; both changes below are
retry-**routing** / evidence-**retention** only — no gate threshold, no adjudication rule.

### Item 1 — semi-transient FAIL summaries route into the K=2 retry lane

`_production_dispatch_cell` previously split a `run_smoke` child exit-1 two ways: **no** fresh
tester summary → `TransientCellError` (retry lane); a fresh summary present → `RunnerError`
(recorded-and-continue, no retry). A cold-cache `BARS_ZERO`/`NO_HISTORY` or a `TIMEOUT` often
**does** publish a fresh FAIL summary, so those first-attempt flakes were recorded failed without
ever retrying.

Now, when a fresh FAIL summary is present, the runner reads its `reason_classes`
(`_summary_reason_classes`) and, if the list is non-empty **and every entry** is within the
transient/infra set `Q09_TRANSIENT_REASON_CLASSES = {TIMEOUT, BARS_ZERO, INCOMPLETE_RUNS,
NO_HISTORY, MODEL4_MARKER_REQUIRED}` (`_fail_summary_is_transient`), it raises `TransientCellError`
→ the same bounded K=2 per-cell retry lane (terminal-clear + capacity + EX5 re-verify between
attempts). Any other/unknown class (genuine zero-signal, `MIN_TRADES_NOT_MET`, `NON_DETERMINISTIC`,
PF-missing validation, a mixed list containing a non-transient class) stays `RunnerError`:
recorded-and-continue, **no** retry. An empty/unclassified `reason_classes` is treated as
non-transient (a FAIL with no explained class is a real result, not a flake). `reason_classes`
comes from `run_smoke.ps1`'s `run_smoke/v2` summary top-level.

### Item 2 — the immutable failure snapshot survives the ops `*.log` retention sweep

The task premise ("the copy skips `.log`") is corrected by the evidence: the copy never skipped
them. In the pilot `cba63d44` cell `policy_on__m1__c1__s7`, `cell_failure.json` lists 10 artifacts
with correct `size_bytes`/`sha256`, including three logs — a 2.00 MB tester journal
(`raw/run_01/20260820.log`), a 1.16 MB EA logger `.log`
(`pre_run_logger_archive/000_QM5_11294_ea-11294.log`), and `runs/selection/run_smoke.log`.
`_snapshot_failure_artifacts` builds that manifest **from the copied files** (`snapshot_root /
snapshot_name`, `stat()` + `sha256_file`), so every listed file existed in
`failure_attempts/attempt_0001` at write time. They are absent now because the snapshot copies
kept their `.log` suffix and were later deleted by the ops retention job
`tools/strategy_farm/reports_log_purge.ps1` (`Get-ChildItem D:\QM\reports\work_items -Recurse
-File -Filter *.log … Remove-Item -Force`), which recurses **into** `failure_attempts/`. Only the
non-`.log` copies (`.set/.jsonl/.json/.htm/.ini`) — including a 673 KB `.jsonl` — survived, proving
it is extension-specific, not a size cap. `tester_cache_purge.ps1` only sweeps `bar*.tmp` under the
Tester agent temp dirs and is not involved.

Fix (in the snapshot naming, `_failure_snapshot_artifact_name`): a new layout
`FLAT_INDEXED_SHA256_V2` renames a copy whose source extension is purge-swept
(`PURGE_SWEPT_SNAPSHOT_SUFFIXES = {.log}`) to a neutral, never-swept suffix
(`.evidence`) so `reports_log_purge.ps1`'s `*.log` filter can no longer match and delete the
immutable evidence. Bytes are unchanged and the true origin stays authenticated via each
artifact's `source_relative_path`. `_authenticated_cell_failure` accepts **both** layouts
(`CELL_FAILURE_SNAPSHOT_LAYOUTS`) and recomputes the expected name with the sidecar's recorded
layout, so V1 sidecars still authenticate unchanged and only new writes use V2. No size cap
exists; the copy is unconditional, so no truncation is needed. (A hardening follow-up in
`reports_log_purge.ps1` to skip `failure_attempts/` entirely is worth an OWNER-noted GRÜN item,
but is out of this file's scope.)

### Tests (`test_q09_news_runner_v2.py`, full file: 31 passed, was 27)

- `test_transient_reason_class_fail_summary_routes_to_retry_lane` — (i): FAIL summary
  `reason_classes=[TIMEOUT]` drives the real `_production_dispatch_cell` fork (patched
  `subprocess.run` returns rc=1 + a fresh FAIL summary); the target selection window is
  re-dispatched `DEFAULT_CELL_RETRY_BUDGET + 1` times, then recorded failed
  (`TransientCellError`); run continues → 39 authenticated + 1 failed, `REVIEW_REQUIRED`.
- `test_unknown_reason_class_fail_summary_is_not_retried` — (ii): `reason_classes=[MIN_TRADES_NOT_MET]`
  → dispatched exactly once (`RunnerError`, no retry), recorded-and-continue → 39 + 1, one sidecar.
- `test_mixed_reason_classes_with_one_unknown_is_not_retried` — a `[TIMEOUT, NON_DETERMINISTIC]`
  mix is not all-transient → no retry (`RunnerError`).
- `test_failure_snapshot_copies_log_artifact_byte_true_and_purge_safe` — (iii): a `run_smoke.log`
  source is copied byte-true into the attempt snapshot (`read_bytes()` equality, `size_bytes` +
  `sha256` match), the copy name does **not** end in `.log` and ends in `.evidence` (purge-safe),
  layout is V2, and it authenticates.

The pre-existing unrelated failure in `test_q09_live_news_diagnostic.py` (Windows 8.3 short-path
`ADMINI~1` vs `Administrator` tempdir normalization) is unchanged by this work.

### Append-only pilot rerun of `cba63d44` (QM5_11294 / XAUUSD Q09_NEWS) — raised sealed timeout

Research only; commands verified against `--help`/source, **not executed**. GELB basis: "raise
timeout budgets to phase median for rows already timeout-killed without verdict." The pilot was
sealed at `q09_cell_timeout_sec=3600` per window (DB payload of `cba63d44`). Per-window duration is
not cleanly measurable from the artifacts (the `run_smoke/v2` summary has no duration field; the
only proxy — run-dir start-name → `summary.json` mtime, n=72 windows — reads a median ≈ 8030 s and
max ≈ 10832 s, but those exceed the 3600 s the pilot actually ran under, i.e. the proxy is
contaminated by queue/archival idle and overstates true tester time). Because a clean measurement
is not available, use the task's specified fallback **`--cell-timeout-sec 10800`** (3 h): 3× the
pilot's sealed 3600 s, comfortably below the runner guard (`q09_news_runner.py:579`,
`60 ≤ cell_timeout_sec ≤ 28800`).

```powershell
cd C:\QM\repo
$oldWid = "cba63d44-ca33-4c64-990d-a1c2ea63eaca"   # terminal REVIEW_REQUIRED Q09_NEWS row (preserved)
$ex5Sha = (Get-FileHash -LiteralPath <current repo QM5_11294 .ex5> -Algorithm SHA256).Hash.ToLowerInvariant()

# 1. ENQUEUE — create a fresh *pending* Q09_NEWS rerun row; the old terminal row stays as evidence.
#    append-only-rerun requires an exact predecessor (--from-work-item-id) and an audit reason;
#    the target verdict is REVIEW_REQUIRED (not INFRA_FAIL) so the current-EX5 binding is required.
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_11294 --phase Q09_NEWS `
  --append-only-rerun-of $oldWid `
  --from-work-item-id $oldWid `
  --rerun-reason "rerun 40-cell v2 pilot under fixed runner fa49b2c84 + this addendum; raised sealed per-cell timeout (GELB, timeout-killed rows)" `
  --expected-current-ex5-sha256 $ex5Sha
# -> prints created[].id = $rerunWid  (a new pending row held Q09_AWAITING_SEALED_PLAN,
#    Q08 input dependency re-added). Capture $rerunWid from the JSON `created` list.
```

Then seal an immutable plan for `$rerunWid` (identical to the `q09_news_runner.py plan` step in
the section above, `--work-item-id $rerunWid`), compute `$planSha`, and bind it with the raised
timeout:

```powershell
# 2. BIND — hash-bind the sealed plan to the pending rerun row with the raised per-cell timeout.
python tools/strategy_farm/farmctl.py bind-q09-plan `
  --work-item-id $rerunWid --plan $plan --plan-file-sha256 $planSha `
  --cell-timeout-sec 10800
# releases the Q09_AWAITING_SEALED_PLAN hold -> activation_state RUNNABLE_BOUND.
```

3. DISPATCH pickup — no manual `execute`. The running factory pump / terminal-worker
(`QM_StrategyFarm_TerminalWorkers`; `farmctl pump`) claims the `RUNNABLE_BOUND` pending `Q09_NEWS`
row on a free T1–T10 terminal, `assert_factory_capacity` re-verifies the sealed dispatch binding
(plan path + `plan_file_sha256` + `q09_cell_timeout_sec`), and spawns the fixed executor
(`q09_news_runner.py execute --plan … --expected-plan-file-sha256 … --output-root …`), passing
`10800` to each window's `run_smoke -TimeoutSeconds`. Under the fixed runner a first-attempt
transient (now including a transient-classed FAIL summary) is retried K=2 and a genuinely failing
cell is recorded-and-continued, so the rerun ends with a maximal-authenticated aggregate instead
of aborting.
