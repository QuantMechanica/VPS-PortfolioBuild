# Codex build evidence — WP-5 and WP-7

Date: 2026-07-25

Branch: `agents/board-advisor`

Builder: Codex

Required reviewer: Claude

## Scope and safety

I read Revision 2 of
`docs/ops/2026-07-25_gate_repair_programme_PLAN.md` before building. WP-1 is
withdrawn as written and I did not build it.

This build did not:

- run a backtest;
- start or stop `terminal64.exe`, a worker, the pump, or a factory script;
- write to `C:\QM\mt5\T_Live`;
- enable AutoTrading;
- access or mutate `D:\QM\strategy_farm\state\farm_state.sqlite`; or
- commit, switch branches, touch `main`, or revert other work packages.

The final process check showed only the already-running permitted process
`C:\QM\mt5\T_Live\MT5_Base\terminal64.exe`. There were no strategy-farm
workers, pump processes, Q07 phase runners, or `metatester64.exe` processes.

## WP-5 — shared cold-cache retry

### What changed

`framework/scripts/_phase_utils.py`

- Generalised `run_with_launch_fault_retry` from DLL-init-only recovery to a
  bounded classifier for:
  `BARS_ZERO`, `M0_1970_PERIOD`, `NO_HISTORY`/`NO_HISTORY_LOG`,
  `INCOMPLETE_RUNS`, `EMPTY_EXPERT`, `EMPTY_SYMBOL`,
  `RUN_STATUS_INVALID`, `HISTORY_CONTEXT_INVALID`, and
  `<SYMBOL>: history synchronization error`.
- Kept the existing default bound of two total subprocess attempts and the
  30-second backoff. Callers can lower or raise the finite bound explicitly.
- Logs every retry with `attempt=x/y`, `matched_signature`, exit code,
  backoff, and next attempt. Exhaustion logs `action=exhausted`.
- Classifies only a failed attempt. For file-backed stdout, it reads only the
  bytes appended by that attempt, so a first-attempt cold-cache marker cannot
  contaminate a later genuine strategy result.
- Treats the latest readable `run_smoke.summary` as authoritative. A PASS, a
  completed `status=OK` run, or a strategy/setup reason such as
  `MIN_TRADES_NOT_MET`, `NON_DETERMINISTIC`, `ONINIT_FAILED`, `LOG_BOMB`, or
  `TIMEOUT` is not retried even if the summary retains an older invalid
  warm-up row.
- Exposed `cold_cache_summary_signature()` so the detached Q02/Q03 worker path
  uses the same structured classifier.

The direct `run_smoke` launch paths now use the helper in:

- `framework/scripts/q03_plateau_runner.py`
- `framework/scripts/q04_walkforward.py`
- `framework/scripts/q05_stress_medium.py` (already adopted before this WP)
- `framework/scripts/q06_stress_harsh.py` (already adopted before this WP)
- `framework/scripts/q07_multiseed.py` (already adopted; its unrelated WP
  edits were not changed)
- `framework/scripts/q08_5_neighborhood_runner.py`
- `framework/scripts/q08_davey/aggregate.py`
- `framework/scripts/q09_news_mode.py`
- `framework/scripts/q10_confirmation.py`

`tools/strategy_farm/terminal_worker.py`

- Q02 is launched directly by the detached worker rather than by a Python gate
  runner, so there is no subprocess call site at which to use the helper.
  Q02/P2 and Q03/P3 completed summaries now pass through the same classifier.
- A classified cold-cache summary is requeued with a 30-second cooldown,
  terminal avoidance, a visible JSON log event, `verdict_reason`, and the
  existing hard cap of three total work-item attempts.
- Cap exhaustion is terminal `INFRA_FAIL`; a completed strategy FAIL is graded
  immediately and does not consume a retry.

`framework/scripts/q03_plateau_runner.py`

- While running the existing gate suite, the Q03 exclusive lock was found to
  be created mode `0444` and therefore not unlinkable on Windows. That left the
  lock held after a successful run. Cleanup now retries the exact lock path
  after applying `S_IWRITE` only when `unlink()` raises `PermissionError`.
  This is narrowly limited to lock cleanup and preserves the read-only
  immutable-lock contract.

`framework/scripts/q05_stress_medium.py` and
`framework/scripts/q08_5_neighborhood_runner.py`

- Explicit `run_smoke.summary` markers are emitted by the subprocess being
  graded and remain exact-identity checked. They no longer depend on a
  sub-millisecond filesystem mtime comparison that is unstable on Windows.
- Directory-scan fallback candidates remain strictly freshness-gated, so this
  does not admit an unmarked stale sibling summary.

`framework/scripts/q06_stress_harsh.py` and
`framework/scripts/q10_confirmation.py`

- Corrected both stale docstrings from `DD < 15%` to the enforced `DD < 25%`.
  Revision 2 confirms both files needed correction.

### Design decision

A raw substring retry was rejected because a valid strategy FAIL summary can
retain cold-cache markers from an earlier warm-up run. The structured summary
therefore wins over raw output, and any completed `status=OK` strategy run
terminates retry classification. Raw signatures are used only when no readable
summary was emitted.

No `.DWX` history is imported or rewritten. This is a bounded recovery
mechanism, not a claim that contention caused the incidents. The recorded
five-of-eight recovery occurred despite worker contention, so retry is
justified as a mitigation for transient cold-start outcomes but does not prove
or remove their underlying cause.

### WP-5 test files

- `tools/strategy_farm/tests/test_phase_utils_retry_wp57.py`
- `tools/strategy_farm/tests/test_gate_summary_marker_wp57.py`
- `tools/strategy_farm/tests/test_q04_exact_evidence_binding.py`
  (detached-worker retry cases)

The tests cover retry-then-success, all requested signatures, the timestamped
tester synchronization line, bounded exhaustion, current-attempt isolation,
and a genuine strategy FAIL containing an older invalid warm-up row.

## WP-7 — Q04 durable evidence and fold hardening

### What changed

`framework/scripts/q04_walkforward.py`

- `--report-root` is the durable evidence root. In factory dispatch the exact
  output is:

  `D:/QM/reports/pipeline/QM5_<id>/Q04/<symbol>__<work_item_id>/aggregate.json`

- Added `--scratch-root` for volatile tester output and `--evidence-key` for
  collision-free per-work-item durable leaves. Manual runs fall back to the
  source setfile SHA prefix.
- Raw tester reports, injected fold setfiles, and logs remain below the
  scratch/work-item root. Only durable fold summaries and the aggregate are
  published in the pipeline tree.
- Before each fold, a read-only preflight verifies:
  - the source setfile exists and is non-empty;
  - the exact repo `.ex5` resolves and is non-empty; and
  - every required OOS-year `.hcc` file exists and is non-empty for the runner,
    host, and basket symbols.
- The preflight records setfile, EX5, symbol, year, and HCC evidence. It never
  imports or mutates history.
- Every controlled fold outcome is atomically written to the deterministic
  `folds/<fold_id>/summary.json` path with schema `q04_fold/v2`,
  `status`, `verdict_reason`, and `invalid_reason`.
- Classifiable failure reasons include `SETFILE_NOT_RESOLVED`,
  `EX5_NOT_RESOLVED`, `OOS_HISTORY_NOT_WARM`, `FOLD_TIMEOUT`,
  `RUN_SMOKE_LAUNCH_ERROR`, `SOURCE_SUMMARY_MISSING`,
  `stream_and_selfreport_missing`, and `FOLD_ERROR_<TYPE>`.
- Strategy outcomes are separately labelled
  `STRATEGY_ZERO_TRADES`, `STRATEGY_MIN_TRADES_NOT_MET`,
  `STRATEGY_PF_AT_OR_BELOW_FLOOR`, or `FOLD_COMPLETE`.
- A missing EA no longer exits before evidence publication; it produces
  deterministic invalid fold summaries and an aggregate.
- The last `run_smoke.summary` marker is selected after a retry, so a successful
  second attempt is not shadowed by the first invalid marker.
- `aggregate.json` is atomically published with schema `q04_aggregate/v2`,
  source setfile and EX5 hashes, immutable evidence key/leaf, fold records, and
  `verdict_reason`.

`tools/strategy_farm/farmctl.py`

- Q04 dispatch now sends the durable pipeline root as `--report-root`, keeps the
  work-item directory as `--scratch-root`, and sends the work-item ID as
  `--evidence-key`.
- The spawn record carries the exact expected durable aggregate path.

`tools/strategy_farm/terminal_worker.py`

- The worker reads the exact Q04 aggregate path and fails closed if it is
  missing or invalid; it does not fall back to a sibling work item's aggregate.
- Evidence already beneath the canonical durable phase directory is not
  redundantly mirrored into its ancestor.
- The expected path survives dispatch and is removed with other stale runtime
  payload keys before a new attempt.

No aggregate exclusion had to be added to
`tools/strategy_farm/prune_workitem_logs.py`: that purge already selects old
`.log` files below `raw/run_*`, not JSON. Moving Q04 aggregates outside the
volatile work-item tree removes them from work-item deletion, and the
regression test invokes the real pipeline-log purge to prove the aggregate
remains readable while an adjacent old raw log is removed.

### WP-2 coordination

The durable path exactly matches WP-2's existing discovery glob:

`D:/QM/reports/pipeline/QM5_*/Q04/*/aggregate.json`

The regression test also asserts discovery with that exact shape.

However, the current uncommitted WP-2
`tools/strategy_farm/ingest_phase_aggregates.py::_resolve_setfile()` is still
Q10-specific: it requires one top-level `report_htm` and an adjacent
`tester.ini`. A Q04 aggregate has three fold reports and now carries its
immutable top-level `setfile_path` plus `setfile_sha256`. WP-2 will discover the
new Q04 files but will refuse to ingest them.

Before Q04 ingestion is enabled, WP-2 needs a reviewed Q04 resolver branch that
accepts `setfile_path` only when its current bytes match `setfile_sha256`, and
then validates the EA and logical/runner-symbol identities from the Q04
aggregate/fold evidence. I did not edit that untracked WP-2 file because it is
another package's build and the user required disjoint hunks.

### Q08 immutable aggregate identity

`framework/scripts/q08_davey/aggregate.py`

- Upgraded new aggregates to `q08_aggregate/v2`.
- The emitted `portfolio_stream` now uses
  `q08_portfolio_stream/v2` and records:
  - durable stream SHA-256, size, and parsed row count;
  - host-copy SHA-256 and size;
  - the actual source artifact kind, path, SHA-256, and size;
  - source report and run-summary paths/hashes when those artifacts exist; and
  - run-smoke EX5, setfile, and MQ5 source paths/hashes when available.
- A canonical `identity_sha256` binds EA, symbol, `n`, row count, stream,
  host-copy, source, report, build, setfile, and MQ5 hashes.
- Host-copy mismatch is explicitly invalid. A stream that was not persisted
  receives no invented identity hash.
- When a recorded source has no report artifact, the aggregate explicitly says
  `source_report_binding=not_available_for_recorded_source`; it does not invent
  provenance.
- Baseline metadata selects the latest completed `status=OK` run rather than an
  earlier invalid warm-up run.

This belongs in WP-7. Only the Q08 producer can hash the bytes at emission time;
WP-6 cannot reconstruct cryptographic provenance after a volatile source or
report has disappeared. The change is future-facing: historical aggregates
that never recorded these hashes cannot be upgraded honestly from path and
count alone.

### WP-7 test files

- `framework/scripts/tests/test_q04_walkforward.py`
- `tools/strategy_farm/tests/test_q04_durable_evidence_wp57.py`
- `tools/strategy_farm/tests/test_q04_exact_evidence_binding.py`
- `tools/strategy_farm/tests/test_q04_latest_full_year_payload.py`
- `tools/strategy_farm/tests/test_q08_aggregate_identity_wp57.py`

## Test results

No test below starts MT5 or a strategy-farm worker.

### New WP-5/WP-7 and farm-integration tests

Command:

```text
python -m pytest tools/strategy_farm/tests/test_phase_utils_retry_wp57.py tools/strategy_farm/tests/test_gate_summary_marker_wp57.py tools/strategy_farm/tests/test_q04_durable_evidence_wp57.py tools/strategy_farm/tests/test_q08_aggregate_identity_wp57.py tools/strategy_farm/tests/test_q04_exact_evidence_binding.py tools/strategy_farm/tests/test_q04_latest_full_year_payload.py tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_q02_evidence_binding.py tools/strategy_farm/tests/test_prune_workitem_logs.py -q
```

Verbatim result:

```text
..........................................................           [100%]
58 passed, 4 subtests passed in 10.54s
```

### Safe terminal-worker finish tests

Command:

```text
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q -k finish_work_item
```

Verbatim result:

```text
..                                                                       [100%]
2 passed, 49 deselected in 0.29s
```

### Existing gate-runner suites

Command:

```text
python -m pytest framework/scripts/tests/test_q03_plateau_runner.py framework/scripts/tests/test_q04_walkforward.py framework/scripts/tests/test_q05_q07_verdicts.py framework/scripts/tests/test_q08_davey_subgates.py framework/scripts/tests/test_q09_news_mode.py framework/scripts/tests/test_q10_confirmation.py -q
```

Verbatim final results from two consecutive invocations:

```text
........................................................................ [ 38%]
........................................................................ [ 77%]
..........................................                               [100%]
186 passed in 4.92s

........................................................................ [ 38%]
........................................................................ [ 77%]
..........................................                               [100%]
186 passed in 5.06s
```

Two pre-fix combined invocations exposed a Windows file-timestamp boundary in
the explicit-marker paths. Their verbatim failure summaries were:

```text
_____ Q05Q07VerdictTests.test_q06_accepts_fresh_matching_run_smoke_marker _____
E       AssertionError: None != 'C:\\Users\\ADMINI~1\\AppData\\Local\\Tem[55 chars]json'
1 failed, 185 passed in 5.24s

FAILED framework/scripts/tests/test_q05_q07_verdicts.py::Q05Q07VerdictTests::test_q06_accepts_fresh_matching_run_smoke_marker
FAILED framework/scripts/tests/test_q08_davey_subgates.py::Q08DaveySubGateSemanticsTests::test_q08_neighborhood_reads_run_smoke_timestamp_summary
2 failed, 184 passed in 5.07s
```

The fix trusts only an explicit path marker captured from the current child,
still requires the complete EA/expert/symbol/period/terminal identity match,
and leaves unmarked directory scans mtime-gated. Three deterministic tests set
the marked file mtime to epoch time and prove marked acceptance plus stale
directory-fallback rejection. The complete gate suite then passed twice as
shown above.

### Q08 aggregate identity plus existing Q08 suite

Command:

```text
python -m pytest tools/strategy_farm/tests/test_q08_aggregate_identity_wp57.py framework/scripts/tests/test_q08_davey_subgates.py -q
```

Verbatim result:

```text
........................................................................ [100%]
72 passed in 1.32s
```

### Additional Q04 report-guard and Q08 equity-scope tests

Command:

```text
python -m pytest tools/strategy_farm/tests/test_audit_q04_native_report_guard.py framework/scripts/tests/test_q08_equity_stream_scope.py -q
```

Verbatim result:

```text
.........                                                                [100%]
9 passed in 0.46s
```

### Syntax and diff hygiene

`python -m py_compile` completed with exit code 0 and no output for all changed
Python sources and tests. `git diff --check` completed with exit code 0; its
only output was the repository's existing LF-to-CRLF conversion warnings.

The intentionally broad
`tools/strategy_farm/tests/test_basket_work_items.py` suite was not run because
the session constraint identifies three tests there that spawn real workers.

## Human migration

None. WP-5/WP-7 add no database schema or data migration, and no command should
be run against the live farm database for this build.

The WP-2 Q04 resolver change described above is a code-review dependency, not a
WP-5/WP-7 migration. Q04 aggregate ingestion must wait until that change is
built and reviewed.

## What could not be done

- No live MT5 run, cold-cache reproduction, real fold, or real purge-cycle
  execution was performed because the session explicitly prohibits backtests,
  terminal starts, and factory activity. Acceptance is covered with simulated
  child processes, temporary histories/binaries, and the real purge function
  against temporary paths.
- This WP does not establish that concurrency causes the cold-cache class. The
  supplied timing evidence contradicts that clean causal claim. Bounded retry
  improves recoverability, while Q04 preflight prevents launches against
  obviously absent source artifacts; neither is a structural cure for MT5
  synchronization behaviour.
- Current WP-2 code can discover but cannot yet authenticate/ingest Q04's
  three-fold aggregate form. That other package needs the matching resolver
  change stated above.
- Historical Q08 aggregates cannot gain report/build/setfile hashes
  retroactively. New aggregates are cryptographically bound where the producer
  has those artifacts and explicitly mark unavailable provenance otherwise.

## Dirty-worktree separation

The repository already contained uncommitted work from other packages. I did
not revert, reorganise, or clean it. In particular, the Q08 identity additions
do not alter WP-6's stream-persistence hardening. One required `run_all`
insertion is immediately adjacent to WP-6's existing
`_persist_durable_sleeve_stream(...)` call because WP-7 must hash the object
that call emits; it may therefore display in the same unified-diff hunk, but no
WP-6 line was rewritten or restructured. The existing Q07, Q10-baseline,
basket-order, portfolio, setfile, ingester, and requeue changes were left
intact. No commit was created so Claude can review the build as a separate
reviewer.
