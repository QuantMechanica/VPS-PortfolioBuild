# Factory Population Reconciliation — 2026-09-16 (mc-reconcile)

**Agent:** Kimi under Kimi's interim OWNER delegation, branch `agents/board-advisor`.
**Read-model:** `tools/strategy_farm/factory_population.py` (schema
`qm.factory-population/v1`) → `D:/QM/reports/state/factory_population.json`.
**Legacy contract kept working:** the same pass re-emits
`factory_three_numbers.json` (`qm.factory-three-numbers/v1`, byte-shape
compatible) via `factory_three_numbers.build_document`.
**Tests:** `tools/strategy_farm/tests/test_factory_population.py` (13 hermetic
tests) + 2 new render tests in `test_render_cockpit_v2.py` — all green.

## Phase 1 — the exact MC computation behind "981 open / 2011 parked"

Mission Control = `D:\QM\strategy_farm\dashboards\cockpit.html`, rendered by
`tools/strategy_farm/render_cockpit_v2.py`:

1. **Data** — `mission_control_v2_data.build_queue()`
   (`tools/strategy_farm/mission_control_v2_data.py:769-879`):
   `SELECT c.phase, gate_contract_version, COUNT(*) … FROM work_items_clean c
   LEFT JOIN work_items w ON w.id=c.id WHERE c.status='pending' GROUP BY phase`.
   Rows split by `normalize_phase_id(phase) in MT5_TESTER_PHASES`
   (`mission_control_v2_data.py:144-150`: Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q10 +
   legacy P2..P8) into **pending_executable** vs **pending_parked**.
   `work_items_clean` is the MNT-016 TEMP clean-view (`work_item_clean_view.py`);
   for pending rows it passes status through unchanged (verified: raw and clean
   censuses identical at every check).
2. **Render** — `render_cockpit_v2.queue_breakdown()` (lines 197-215) and
   `_render_control_strip` Queue cell (lines ~334-340): main number =
   `pending_executable`, subline "+{pending_parked} parked · {active} active ·
   Σ {queue_total}". This is the whole "open / parked" display.

**Reproduction:** at 2026-09-16T12:06Z the live DB returned
executable=**981**, parked=**2,811** (OPT_CENSUS 2,555 + Q12 106 + Q10_NEWS 56
+ Q09_NEWS 55 + COMPILE_EA 33 + Q09 6 + Q14 2) — the "981 open" matched the
OWNER's observation exactly. The rendered `cockpit.html` (13:42 local) shows
Queue 981 · +2.811 parked · Σ 3.792. The OWNER-observed "2011 parked" does not
match any measured state (09-13 preview snapshot: 3,084; 12:06Z: 2,811): the
parked census is dominated by the OPT_CENSUS `PRESCREEN_SKIPPED` cohort
(created 2026-08-22…09-03, retired by design per CEO-DEC-PATTERN-REPAIR-20260909)
and moves by hundreds as census programs materialize/drain; every non-OPT_CENSUS
parked row sums to only a few hundred. **Both captured** in
`factory_population.json → mission_control.computation` (owner_observed_display
981/2011 + freshness_note).

## Phase 2/3 — classification (exactly once, sums exact)

Deterministic classifiers in `factory_population.py`
(`classify_open_row` / `classify_parked_row`), precedence-ordered:

OPEN (selector = `farmctl.pending_claim_order_sql` = "Level 1"; Q08 adds
`dsr_cohort.claimability_precheck`, watchdog fail-open semantics): ACTIVE_NOW →
selector+precheck-clean ∧ RAM-feasible → RUNNABLE_NOW (RAM-infeasible claimable →
RESOURCE_BLOCKED/ram_infeasible_now) → precheck-rejected (reason token →
BUILD_IDENTITY / GOVERNANCE / DSR_CONTEXT) → SUPERSEDED → quarantine
(REQUEUE_EXCLUDED) → hold-code classes (RAM_* → RESOURCE; Q08_DSR*/SIBLING_* →
DSR_CONTEXT; ARTIFACT_BINDING* → ARTIFACT_BINDING; COMPILE*/SOURCE_REPAIR →
COMPILE_OR_BUILD; REVIEW_*/MONITOR_BUDGET/OWNER_D5/EXCLUSIVE_LANE/FTMO_BOOK3/
SPLIT_FIX/WITHHELD → GOVERNANCE; CUSTOM_HISTORY → DATA_OR_HISTORY; else OTHER)
→ catch-all OTHER (never reached in the live run).

PARKED: governed-analytic (kind=analytic ∧ GOVERNED_ANALYTIC_DISPATCH) via the
2026-09-16 all-106 dry-run receipt (`D:/QM/reports/
dl089_matrix_service_dryrun_20260916_all106.json`: REBIND_REFUSED →
INTENTIONALLY_INERT/duplicate; missing _opt sibling → REQUIRES_NEW_OWNER_DECISION
per program; blocking hold → binding lane / owner 44GB window / review lane) →
diagnostic_non_admission → INTENTIONALLY_INERT → superseded → INTENTIONALLY_INERT
→ hold classes (PRESCREEN_SKIPPED → INTENTIONALLY_INERT per
CEO-DEC-PATTERN-REPAIR-20260909; NEWS_CALENDAR_TAINTED → REQUIRES_NEW_OWNER_DECISION
= the 99-hold OWNER E1-C package; COMPILE_EA_WORKER_ROLLOUT_PENDING →
RECOVERABLE_WITHOUT_OWNER; NEWS_RUNNER_SPAWN_SILENT_ABORT → RECOVERABLE_WITHOUT_OWNER;
Q09_AWAITING_SEALED_PLAN → RECOVERABLE_WITHOUT_OWNER) → unheld selector-claimable
(fresh OPT_CENSUS cells) → RECOVERABLE_WITHOUT_OWNER
/claimable_now_no_repair_needed → catch-all REQUIRES_NEW_OWNER_DECISION (never
reached in the live run).

**Snapshot 2026-09-16T12:37Z** (the fleet was live-repairing while this ran:
D1 batch-2 dispositions applied 11:57:58Z; D4/D5 decided and executed —
QM5_11731 compiled→Q02 PASS→Q04 FAIL/INFRA_FAIL; QM5_41478 compiled→Q02 PASS→
1,078 census cells materialized 12:10Z):

- OPEN_PIPELINE_ROWS **987** = RUNNABLE_NOW 4 · RESOURCE_BLOCKED 441 ·
  GOVERNANCE 70 · DSR_CONTEXT 39 · ARTIFACT_BINDING 9 · COMPILE_OR_BUILD 13 ·
  REQUEUE_EXCLUDED 33 · DATA_OR_HISTORY 6 · SUPERSEDED_REPAIR 358 · OTHER 14.
- PARKED **3,885** = RECOVERABLE_WITHOUT_OWNER 1,088 (incl. 1,073 claimable
  fresh census cells needing no repair) · RECOVERABLE_WITH_EXISTING_AUTHORITY 13
  · REQUIRES_NEW_OWNER_DECISION 32 · RESOURCE_BLOCKED 5 · INTENTIONALLY_INERT
  2,747 · ECONOMICALLY_TERMINAL 0 · OTHER 0.
- Four counts: TRUE_CLAIMABLE_WORK **1,080** (of SELECTOR 1,085; 5 Q08
  precheck-rejected), RESOURCE_FEASIBLE_RUNNABLE_WORK **4** (free RAM 30.0 GB of
  63.1 GB with 3 active testers; Q06 37.9 GB class needs 51.9 GB),
  ACTIVE_ECONOMIC_BACKTESTS **3**.
- Forecast: RUNNABLE_NOW_HOURS 1.77 + EXPECTED_UNLOCK_HOURS 81.11
  (ram_44gb 46.41 + news_spawn 18.38 + q08_dsr_context 10.87 + sealed_plan 4.08
  + binding 0.78 + compile_rollout 0.50 + second_chance 0.09) =
  **FORECAST_RUNNABLE_HOURS 82.88** → FACTORY_BUFFER_LOW GREEN, health RUNNING.

## Phase 5 — Mission Control labels (dashboard-only)

`render_cockpit_v2.py`: Queue cell label is now "Queue · OPEN_PIPELINE_ROWS"
(the raw census stays, explicitly named); new **Fabrik-Population** cell in the
control strip shows TRUE_CLAIMABLE/RESOURCE_FEASIBLE/ACTIVE + forecast + parked
split; the Queue section footer prints the "Factory Population:" line. All
values come from `factory_population.json` via fail-soft `load_factory_population()`;
when the file is absent the page renders exactly as before. No gate/verdict
semantics touched.

## Verification

- `pytest tools/strategy_farm/tests/test_factory_population.py` — 13 passed.
- `pytest tools/strategy_farm/tests/test_render_cockpit_v2.py
  test_factory_three_numbers.py test_mission_control_v2_data.py` — 63 passed.
- Live runs of `factory_population.py` and `render_cockpit_v2.py` (receipts in
  `D:/QM/reports/state/factory_population.json`, `cockpit.html`).
