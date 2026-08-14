# Gate-compliant execution route for the pattern-permission fixture runner — task 50d5752c

Date: 2026-08-14
Router task: `50d5752c-daf2-412f-86b5-ce4d9eca1cad` (priority 90, effort max)
Branch: `agents/board-advisor`
Verdict: `IMPLEMENTED_UNIT_TESTED_LIVE_E2E_PENDING_NEXT_WORKER_RESTART`

## Authority and scope

This closes items `R1_execution_route` and `R2_result_collection` from the routed
ticket. Mission: give Claude's pattern-permission fixture harness (231 hand-built
fixtures across 77 predicates, `framework/tests/QM_pattern_permission_fixture_runner.mq5`)
a lawful way to run against the real `QM_PP_Evaluate`, without weakening
`custom_history_smoke_admission.py`'s fail-closed Custom-history isolation gate.
OWNER directive (2026-08-13): *"keine Abkuerzung, nichts auslassen"* — no shortcuts.

No production `work_items` row was created (all testing used scratch/tmp DB roots).
No gate file was touched — `git diff --stat` against
`custom_history_smoke_admission.py`, `custom_history_gate.py`,
`custom_history_copy_on_claim.py`, `custom_history_lease.py`,
`custom_history_contract.py`, `custom_history_migration.py` is **empty**. No
terminal was launched by this work, T_Live/FTMO/AutoTrading were untouched, and no
active T1-T10 backtest was interrupted.

## R1 — the three options, and why (a)

The ticket asked to evaluate three routes and justify the choice:

- **(a) a first-class "harness" work-item class** the terminal_worker claims and
  runs exactly like a backtest.
- **(b) a documented DEV1/DEV2 route.**
- **(c) a farmctl subcommand that wraps the whole thing.**

**Chose (a), exposed through (c).** Evidence for (a):

- The fixture-runner EA's own header comment already says why it is an EA, not a
  script: *"the fixture suite has to run through the sanctioned ad-hoc tester
  harness on a free terminal... All work happens in OnInit... the run costs one
  bar of tester time."* It was built to run exactly like a backtest — Model 4,
  one short window, `OnTester` returns a flat `0.0`. Route (a) is what the EA was
  already designed for.
- (b) DEV1/DEV2 was ruled out per the ticket's own instruction: a non-interactive
  run acquiring the isolated `QMDev1` identity needs an OWNER credential step, and
  storing/forging that is explicitly forbidden. This was confirmed independently —
  the earlier blocker evidence in this ticket's payload already shows
  `run_smoke.ps1 -Terminal DEV1` refusing because the session runs as
  Administrator, not `WIN-B95G5LPSJ1O\QMDev1`.
- (c) alone (a bare CLI wrapper) would still need *something* underneath it to
  satisfy `custom_history_smoke_admission.py`'s `reserve` call, which hard-requires
  an `expected_work_item_id` bound to a genuinely `status='active'`,
  `claimed_by=<terminal>` row (`custom_history_smoke_admission.py:79-83`,
  `:92-98`). There is no bypass for that short of forging `QM_WORK_ITEM_ID` —
  exactly what the ticket forbids. So (c) is only meaningful as a thin, convenient
  entry point *onto* (a), not an alternative to it. That's what was built:
  `farmctl.py enqueue-pattern-fixture-harness` is the one-command runbook; it does
  nothing the gate wouldn't also accept from a hand-built row.

### Design

- New `work_items.kind = 'harness'` (schema already anticipated this: the column
  comment says *"'backtest' (more kinds later)"*, `kind='analytic'` for Q16 is the
  existing precedent). A harness item is claimed by the exact same generic,
  phase-agnostic CAS claim loop every backtest uses
  (`terminal_worker.py::claim_atomic`) — nothing about claiming was touched.
- `phase = 'HARNESS_PP_FIXTURE'` — deliberately outside both
  `REAL_PHASE_RUNNER_PHASES` and `SUPPORTED_BACKTEST_PHASES`, so dispatch takes
  the plain `run_smoke.ps1` branch rather than the phase-runner branch, and no
  Q02/P2-specific compile-gate/window/basket logic (none of which applies to a
  harness) ever executes.
- `symbol = 'EURUSD.DWX'` by default — verified against the *live* Custom-history
  activation manifest (`D:\QM\strategy_farm\artifacts\ops\...\archive_manifest_owner_approved.json`,
  loaded via the activation state at
  `D:\QM\strategy_farm\state\custom_history_isolation_activation.json`): EURUSD.DWX
  is one of the 37 symbols the current manifest covers. This matters because
  privatization is **activation-gated, not phase-gated** — it fires for any
  claimed symbol the manifest covers, regardless of `kind`/`phase`. Picking a
  covered symbol means the isolation gate reports `PASS_ISOLATED` /
  `PASS_SERIALIZED_ROLLBACK` honestly instead of the run silently skipping
  privatization because the symbol happened not to be governed.

### Implementation (all in `tools/strategy_farm/`, `framework/scripts/`; no gate file touched)

- `farmctl.py`: `HARNESS_WORK_ITEM_KIND`, `HARNESS_PP_FIXTURE_*` constants,
  `COMMON_FILES_ROOT` (hardcoded — see bug note below).
- `farmctl.enqueue_pattern_fixture_harness(root, *, symbol=..., ...)` — the one
  command: verifies the fixture `.ex5` and the repo's canonical bundle CSV
  (`framework/tests/fixtures/pattern_permission/_bundle/pattern_fixtures.csv`)
  exist, deploys that bundle into the shared MQL5 `Common\Files\QM\pattern_fixtures.csv`
  the runner EA reads (FILE_COMMON), then inserts one `pending` `work_items` row.
  Also exposed as `farmctl.py enqueue-pattern-fixture-harness` (added to
  `_STATE_MUTATING_COMMANDS` so the canonical-checkout worktree guard applies to
  it like every other state-mutating subcommand).
- `farmctl._spawn_harness_run_smoke_for_work_item(root, item_row, terminal)` — a
  dedicated spawn path (not a branch threaded through the ~350-line
  `_spawn_run_smoke_for_work_item`, to keep this change auditable and to avoid
  any interaction with the SHA-bound evidence-identity / compile-gate / basket
  machinery a real strategy backtest needs and a harness does not). Stages the
  fixture `.ex5` into the target terminal's `MQL5\Experts\QM\` itself (the
  fixture EA lives under `framework/tests/`, not `framework/EAs/`, so
  `Deploy-ExpertBinaryToTerminal`'s convention doesn't apply — confirmed it fails
  safe there: source-missing under `framework\EAs\` is a logged no-op, never a
  throw, `run_smoke.ps1:577-583`), then calls `run_smoke.ps1` with `-Expert`,
  `-SkipExpertDeploy`, `-MinTrades 0`, `-Model 4`, `-Runs 1`,
  `-AllowMissingRealTicksLogMarker`, and the real `-ExpectedExpertSha256` of the
  staged binary. `QM_WORK_ITEM_ID` / `QM_WORK_ITEM_TERMINAL` are set exactly as
  the real backtest path sets them — `custom_history_smoke_admission.py`'s
  `reserve` call inside `run_smoke.ps1` is unmodified and unaware anything is
  different.
- `_spawn_run_smoke_for_work_item` gets exactly one added line routing
  `kind == 'harness'` to the dedicated path, guarded with
  `"kind" in item_row.keys()` so it doesn't break the handful of existing tests
  that hand-build a minimal dict without a `kind` key.
- `terminal_worker.py`: `_finish_harness_work_item(...)` — a harness never trades,
  so the generic `summary.json` / min-trades verdict pipeline
  (`_derive_verdict_from_summary`) does not apply; a harness's `OnTester` returns
  a flat `0.0` and there is no tester report worth classifying. Instead it calls
  the R2 collector (below) and records `HARNESS_OK` / `HARNESS_FAIL` with a
  concrete reason. `_finish_work_item` gets one added line routing
  `kind == 'harness'` before it ever looks for a `summary.json`.

### A bug this design caught before it shipped

The first implementation resolved the shared MQL5 `Common\Files` root from
`%APPDATA%`. A dry run against the real repo bundle proved this wrong: the
calling shell's `APPDATA` resolved to the *SYSTEM* profile
(`C:\Windows\system32\config\systemprofile\...`), not
`C:\Users\Administrator\...` where the factory terminals actually read
`Common\Files` from (confirmed via `analyze_ftmo_costs.py`, `health.py`,
`repair.py`, `isolated_work_item_runner.py`, `dxz_truth_chain.py` — every other
consumer in this codebase hardcodes that exact path for this exact reason). The
row-count mismatch between the deployed file (25 lines, an old stub) and the
real bundle (3813 lines) is what surfaced it. Fixed to `COMMON_FILES_ROOT`, a
hardcoded constant matching the rest of the codebase; the stray SYSTEM-profile
artifact from the buggy dry run was deleted. Re-verified: `enqueue_pattern_fixture_harness`
now deploys the correct 3813-line/456,050-byte bundle to
`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\pattern_fixtures.csv`.

## R2 — result collection

`framework/scripts/collect_pattern_fixture_harness_results.py`:

- `collect_results(source_csv, bundle_csv, dest_csv)` — copies the runner's
  verdict CSV from `Common\Files\QM\pattern_fixture_results.csv` to
  `framework/tests/fixtures/pattern_permission/_bundle/pattern_fixture_results.csv`
  (the exact path `test_pattern_fixture_coverage.py` already reads and is
  `skipif`-gated on). **Staleness guard**: if the results file's mtime predates
  the bundle CSV's mtime, raises `StaleResultsError` — a hard error, never a
  silent pass, per the R2 acceptance criterion. Returns row count and a
  verdict-count breakdown.
- `purge_report_root_journal(report_root)` — deletes `.log` files under a
  harness work item's own `D:\QM\reports\work_items\<id>\` directory after a
  successful collection. Scoped deliberately conservative: this directory is
  created fresh per work item and shared with nothing else, so purging it cannot
  affect any other in-flight run. It does **not** touch the terminal's shared
  per-day tester journal (`<Tn>\Tester\logs\`) that other concurrent dispatches
  on that terminal still need — deleting *that* is what actually caused the
  2026-07-06/07 multi-GB T8 incidents the ticket referenced, and doing it wrong
  here risked repeating that class of bug rather than fixing it. Flagged in the
  evidence below as a scoped, not a complete, fix — see Known limitation.
- `terminal_worker._finish_harness_work_item` calls both automatically; the
  script is also directly runnable/testable standalone.

### Test results

```
framework/scripts/tests/test_collect_pattern_fixture_harness_results.py .......  (7 passed)
tools/strategy_farm/tests/test_pattern_fixture_harness_dispatch.py ..            (2 passed)
```

Per the ticket's acceptance criteria: stale results rejected ✅, fresh results
accepted with correct row/verdict counts ✅, two consecutive runs byte-identical
(idempotent) ✅, journal purge scoped to report_root only ✅ (a sibling
report_root's `.log` is proven untouched), missing report_root is a no-op ✅.

Full regression pass (unrelated existing suites this change's two one-line
dispatch branches could plausibly affect):

```
framework/scripts/tests/test_pattern_fixture_coverage.py
tools/strategy_farm/tests/test_basket_work_items.py
tools/strategy_farm/tests/test_ftmo_book3_q02_dispatch.py
tools/strategy_farm/tests/test_news_calendar_claim_gate.py
tools/strategy_farm/tests/test_phase_runner_process_lineage.py
tools/strategy_farm/tests/test_terminal_worker_adoption.py
tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py
tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py
tools/strategy_farm/tests/test_terminal_worker_identity.py
tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py
tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py
= 168 passed, 2 skipped (pre-existing, no results.csv yet), 4 subtests passed
```

One real regression was caught and fixed during this pass: several
`test_ftmo_book3_q02_dispatch.py` cases hand-build a work-item as a plain
`dict` missing the `kind` key; the new dispatch check now guards with
`"kind" in item_row.keys()` so it degrades safely for both `sqlite3.Row` and
plain-dict callers instead of raising `KeyError`.

## Why live end-to-end execution did NOT run this cycle

The ticket's acceptance criterion for R1 wants the runner to actually execute
end to end and `test_runner_results_all_pass` / `test_runner_covered_every_bundled_fixture`
to stop skipping. That did not happen in this cycle, for a structural reason, not
a shortcut:

`terminal_worker.py` is a long-running daemon (10 alive, confirmed via
`farmctl.py health` at cycle start) that imports `farmctl` once at process
start and never reloads it — this is a standing, previously-documented finding
(2026-08-04: *"Worker ohne Self-Reload → farmctl-Änderung braucht OFF/ON"*).
Since the actual `claim → privatize → spawn` call
(`terminal_worker.py:3786 farmctl._spawn_work_item_runner`) runs in-process
inside those daemons, my new `kind='harness'` dispatch code cannot execute on
the live farm until the daemons restart and re-import current `farmctl.py`. This
ticket explicitly instructs: *"factory is ON -- do NOT run Factory_OFF/ON (that
is Claude's chain)"* — restarting the daemons was out of scope for this cycle.

A second, secondary dispatch path exists (`farmctl.dispatch_work_items`, invoked
by `farmctl.py pump` — a fresh short-lived process that *would* pick up new code
without a restart). It was deliberately **not** exercised live this cycle:
`dispatch_work_items`'s own Phase 1 (completion polling) does not yet know about
`kind='harness'` — it unconditionally looks for a `summary.json` a harness never
produces — so a harness item claimed through that path would eventually be
misclassified as timed-out/failed rather than collected correctly. Given the
live factory is currently running real backtests across the T1-T10 fleet, and
this path's current production activity level and terminal-busy interaction were
not fully verified in the time available, invoking it manually was judged higher
risk than the value of a same-cycle live proof. This is a real, currently
unaddressed gap for that path — see Known limitations.

**Concrete next action** (single command, once authorized): after the next
legitimate `terminal_worker` restart —

```
python tools/strategy_farm/farmctl.py enqueue-pattern-fixture-harness
```

— then watch for the item to reach `status='done'` with `verdict='HARNESS_OK'`,
and run `pytest framework/scripts/tests/test_pattern_fixture_coverage.py -k runner_results`
to confirm the two currently-`skipif`'d tests go live and pass.

## Known limitations / follow-ups

1. `dispatch_work_items` (the `pump`-driven secondary dispatch path) does not
   have a `kind='harness'` branch in its own Phase 1 completion polling. If a
   harness item is ever claimed through that path instead of a
   `terminal_worker.py` daemon, it will not be collected correctly today. Not
   fixed in this pass — scope was the primary daemon path the ticket's own
   blocker evidence was about.
2. Journal purge is scoped to the per-work-item `report_root` copy only (see R2
   above) — it does not address any shared per-terminal-per-day journal growth
   from repeated harness runs. If this route is reused often (the mission text
   anticipates "any future MQL5 unit harness"), that shared-journal question
   should get its own look before high-frequency reuse.
3. Live E2E proof (item 4 above) is the one acceptance-criterion gap remaining
   before this can honestly be called fully done.

## Commands run

```
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/terminal_worker.py \
    framework/scripts/collect_pattern_fixture_harness_results.py
python -m pytest framework/scripts/tests/test_collect_pattern_fixture_harness_results.py \
    tools/strategy_farm/tests/test_pattern_fixture_harness_dispatch.py \
    framework/scripts/tests/test_pattern_fixture_coverage.py \
    tools/strategy_farm/tests/test_basket_work_items.py tools/strategy_farm/tests/test_ftmo_book3_q02_dispatch.py \
    tools/strategy_farm/tests/test_news_calendar_claim_gate.py tools/strategy_farm/tests/test_phase_runner_process_lineage.py \
    tools/strategy_farm/tests/test_terminal_worker_adoption.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py \
    tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py \
    tools/strategy_farm/tests/test_terminal_worker_identity.py tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py \
    tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py -q
git diff --stat -- tools/strategy_farm/custom_history_smoke_admission.py tools/strategy_farm/custom_history_gate.py \
    tools/strategy_farm/custom_history_copy_on_claim.py tools/strategy_farm/custom_history_lease.py \
    tools/strategy_farm/custom_history_contract.py tools/strategy_farm/custom_history_migration.py   # empty
```

## Files changed

- `tools/strategy_farm/farmctl.py` (+~230 lines: constants, `enqueue_pattern_fixture_harness`,
  `_spawn_harness_run_smoke_for_work_item`, one dispatch-routing line, CLI subcommand)
- `tools/strategy_farm/terminal_worker.py` (+~70 lines: `_finish_harness_work_item`, one dispatch-routing line)
- `framework/scripts/collect_pattern_fixture_harness_results.py` (new)
- `framework/scripts/tests/test_collect_pattern_fixture_harness_results.py` (new, 7 tests)
- `tools/strategy_farm/tests/test_pattern_fixture_harness_dispatch.py` (new, 2 tests)

## Risks / blockers

- Live E2E execution unproven this cycle (see above); everything downstream of
  a successful run (results collection, staleness guard, journal purge) is
  unit-tested but not yet exercised against a real MQL5 tester report.
- `dispatch_work_items`'s secondary path is not harness-aware (limitation 1).

## Recommended next step

Codex review of the diff, focused on: (a) confirming the gate-file diff really
is empty (already checked mechanically above, worth a second pair of eyes given
the ticket's explicit "never weaken this gate" instruction), (b) the
`dispatch_work_items` gap (limitation 1) — either patch it symmetrically with
`terminal_worker.py`'s fix or explicitly document the harness route as
daemon-only until it is. Then, at the next legitimate `terminal_worker` restart,
run the one concrete-next-action command above for the actual live proof.
