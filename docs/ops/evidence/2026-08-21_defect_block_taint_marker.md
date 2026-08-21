# Defect-block taint marker for pre-block work_items rows (2026-08-21)

**Router task:** `5343f90a-08f4-4733-a9a4-7e717e9f4c1d` (claude, ops_issue, priority 73)
**Authority:** Claude, BLOCKED-backlog review 2026-08-21
**Status:** implemented, independently re-verified, tests pass

## Problem

15 EAs were formally BLOCKED on 2026-08-16 for documented correctness
defects (host-slot magic conflation, unwired strategy inputs, framework
violations, stale exit/session wiring, and related build/review failures).
The block held — none of the 15 produced a single new `work_items` row
after their block event. But the gate rows they produced **before** the
block are still in `work_items` and read as ordinary evidence in every raw
count: funnel tables, the per-symbol swimlane on EA detail pages, and any
future cohort/candidate selection that scans `work_items` by verdict alone.

Nothing from this cohort reached the candidate register (`in_portfolio_candidates: 0`,
per the routing task's own prior measurement) and nothing passed beyond Q03 —
so there is no current book-selection exposure. The problem is structural:
the taint is invisible to anyone reading counts, not that anything has
already been mis-selected.

## The 15 EAs, independently re-verified

| ea_id | defect_class | blocked_at (UTC) | source_task_id |
|---|---|---|---|
| 10648 | host_slot_magic_conflation | 2026-08-16T21:23:09 | `5f1f643e-e343-41bd-a17c-6bc21ddeba47` |
| 10649 | host_slot_magic_conflation | 2026-08-16T21:23:09 | `3371d2a0-7569-46f6-8f08-a9c951ee1d3d` |
| 10973 | host_slot_magic_conflation | 2026-08-16T21:23:10 | `93481b8d-1a1d-4506-9064-12b0dc740c4e` |
| 11301 | spec_gate_and_smoke_schema | 2026-08-16T21:30:08 | `efe9876c-ca5d-4405-ae94-65d804e3c715` |
| 11302 | spec_gate_and_smoke_schema | 2026-08-16T21:30:08 | `dfc248dc-ce63-4b55-bbfb-1ff701db0d91` |
| 11689 | raw_series_noncanonical_symbol | 2026-08-16T21:30:10 | `b36ca851-5323-405b-9a22-f9c5a7c596ae` |
| 11897 | unwired_strategy_inputs | 2026-08-16T21:23:13 | `9cc2e6ea-bd05-4a95-9ea6-3e26a724769a` |
| 11898 | timeout_wallclock_and_missing_build_result | 2026-08-16T21:30:10 | `7ac78733-f755-445e-a36c-1e21f7d6b600` |
| 12352 | zero_trade_smoke_and_symbol_mismatch | 2026-08-16T21:30:10 | `23a6f9a0-0044-428d-af46-4774e028f60d` |
| 20070 | stale_framework_wiring | 2026-08-16T21:30:11 | `fe1f8186-798a-41f7-8909-ecdaa522581a` |
| 20071 | stale_framework_wiring | 2026-08-16T21:30:12 | `47666b69-24c3-48f1-a660-e74c7396c467` |
| 20179 | invalid_stop_out_of_charter | 2026-08-16T21:30:13 | `9df810a8-9783-4f10-9378-83989f69ac36` |
| 2076 | unwired_strategy_inputs | 2026-08-16T21:23:23 | `1e9d9d3e-2060-408a-8cc3-9025a49d021b` |
| 9354 | build_check_failures_and_state_mutation | 2026-08-16T21:30:13 | `982fe1f3-c9e2-430b-a080-093f59a5b012` |
| 9501 | time_sensitive_strategy_params_missing | 2026-08-16T21:26:18 | `037da632-6b8f-435f-b142-3829e442a2a9` |

Sources: `agent_tasks.review_close_verdict` on each cited task id, queried
directly against `D:\QM\strategy_farm\state\farm_state.sqlite`. Registry is
frozen in `tools/strategy_farm/defect_block_taint_view.py::DEFECT_BLOCKED_EAS`.

**Caveat, not a weakening of the finding:** three of these EAs (10648,
10973, 11897, plus 2076/9501/10649) were subsequently repaired and
re-APPROVED on 2026-08-16 23:53 under a separate consolidated task
(`c162c123-6264-4028-9f19-84cbd81cff48`, "Repair the 8 EAs blocked by the
2026-08-16 build-review battery") — then reconciled back to BLOCKED on
2026-08-21 for an unrelated administrative reason
(`pipeline_no_ea_binding`), not a correctness defect. Whether repaired or
not, **zero of the 15 produced a single new gate row after 2026-08-16** —
none has been re-tested since. The taint marker below flags rows by
"predates a documented defect-block event for this EA," which stays true
regardless of later repair status; it is not a claim that today's binary is
still defective.

## Independent verification

Re-derived directly from `work_items` (not from the router task's own prior
"measured" numbers, though they match exactly):

- **103 total `work_items` rows** across all 15 EAs (`Q02`=56, `Q03`=8, `Q04`=39).
- **44 PASS rows** (`Q02`=36, `Q03`=8, `Q04`=0 — matches "deepest_phase_reached:
  Q04, no Q04 PASS").
- **31 FAIL, 18 INFRA_FAIL, 9 ZERO_TRADES, 1 unclassified.**
- **0 rows created after 2026-08-16T21:23** (the earliest block timestamp in
  the cohort) — max `created_at` across all 103 rows is
  `2026-08-16T12:23:36+00:00`, ~9 hours *before* the first block event.
  The block held with zero exceptions.
- Full breakdown: `docs/ops/evidence/2026-08-21_defect_block_taint_marker_audit.json`,
  regenerable via `python tools/strategy_farm/defect_block_taint_view.py`.

## 1. Derived, query-only marker (acceptance criterion 1)

`tools/strategy_farm/defect_block_taint_view.py`, following the MNT-016
pattern (`work_item_clean_view.py`, commit `9d9259dec`) exactly:

- A frozen, source-cited Python dict (`DEFECT_BLOCKED_EAS`) is the only
  place the 15-EA list lives.
- `install_taint_view(connection)` registers two deterministic SQL
  functions and creates a **TEMP VIEW** `work_items_defect_block_taint`
  that left-projects `work_items` with five new columns:
  `defect_block_taint` (0/1), `defect_block_class`, `defect_block_source_task_id`,
  `defect_block_at`, `defect_block_summary`. Nothing in `work_items` itself
  is touched — the view is a query-time projection, dropped/rebuilt per
  connection.
- `open_taint_view_connection(db)` opens the source **read-only**
  (`?mode=ro`), installs the view, then asserts `PRAGMA query_only=ON` and
  fails closed if that assertion doesn't hold — an accidental write is
  structurally impossible through this path.
- `audit_taint_view(connection)` proves the after-block invariant (no
  tainted row's `created_at` postdates its `defect_block_at`) over the
  whole table and emits the counts above.
- 8 unit tests in `tools/strategy_farm/tests/test_defect_block_taint_view.py`
  cover: prefix stripping, registry hit/miss, view flags only registry EAs
  and never mutates the source table (including a raw `INSERT` into the
  view itself raising `sqlite3.OperationalError`), the after-block
  invariant catching a synthetic violation, and the read-only connection
  path. All pass (`pytest tools/strategy_farm/tests/test_defect_block_taint_view.py -q`
  → 8 passed).

## 2. Surfaces that currently include these rows unfiltered (acceptance criterion 2)

Grepped for raw `work_items`/`tasks` aggregation across `tools/strategy_farm/`.
Confirmed unfiltered inclusion in:

- **Funnel / per-symbol swimlane** — `tools/strategy_farm/dashboards/render_dashboards.py`,
  the per-symbol gate swimlane (`One row per symbol across all gates Q0x`,
  ~line 3729). Reads `detail.get("work_items")` directly and renders a green
  "✓ edge pass" / "✓ smoke pass" glyph for any `PASS` verdict, with no
  defect-block indicator. A reviewer skimming an EA detail page for one of
  the 15 sees clean-looking PASS marks with nothing distinguishing them
  from an untainted EA's evidence. Descriptive surface only — not itself a
  selection mechanism — left unchanged this pass; flagged here per the
  acceptance requirement to report, not silently patch every consumer.
- **Legacy scheduling/classification table (`tasks`)** — the same rows
  (by EA/phase/verdict) also exist in the older `tasks` table
  (`kind='backtest_q02'/'backtest_q03'/'backtest_q04'`), which is where the
  live classification loop in `farmctl.py` actually runs. This table is
  scanned identically without any defect-block filter today.
- **`farmctl.py health` counts** (`p_pass_stagnation`, `phase_invalid_rate_7d`,
  etc.) aggregate `work_items`/`tasks` by verdict/phase without EA-level
  disposition filtering — these 15 EAs' 44 PASS and 31 FAIL rows are inside
  those raw counts, indistinguishable from clean cohorts. Given the small
  absolute count (44 of tens of thousands of PASS rows farm-wide) this does
  not currently distort the health signal materially, but it is included.

No dashboard/report code was modified to filter these rows out of *display*
surfaces this pass — the acceptance criterion asked to **report** inclusion,
and a human-facing dashboard showing full history (clearly attributable via
the new view for anyone who queries it) is a materially different risk than
an automated *selection* path silently promoting them. That selection risk
is addressed directly below.

## 3. Selection-path check and fix (acceptance criterion 3)

**Yes — a live, unconditional selection path exists and was excluding
nothing.** `tools/strategy_farm/farmctl.py`, the backtest-classification
loop (`Auto-advance: PASS → enqueue next phase as a NEW pending task`,
previously ~line 20911/21553 depending on branch): whenever a `tasks` row
classifies as `verdict == "PASS"`, the code auto-enqueues the next phase
(`P2→P3→P3.5→P4`) unconditionally — no check against `agent_tasks` BLOCKED
state, no check against any defect registry. This is not hypothetical: the
`tasks` table shows this exact mechanism already fired historically for
this cohort before 2026-08-16 (e.g. EA 10973's `backtest_q03` PASS rows on
2026-08-10/12 auto-enqueued the `backtest_q04` rows that came back
`INFRA_FAIL`/`STRATEGY_FAIL`). If a stale row for one of these 15 were ever
reclassified (a re-run, a duplicate dispatch), it would auto-cascade with
no barrier.

**Fix applied** (both `C:/QM/repo/tools/strategy_farm/farmctl.py` — the
canonical checkout on `agents/board-advisor`, and the equivalent block in
this worktree's copy for local test parity): the auto-advance branch now
checks `defect_block_taint_record(ea_id)` before enqueuing. If the EA is in
the frozen registry, the cascade is **skipped by default** and the skip
reason (`defect_class`, `source_task_id`) is recorded in the task's
`actions` log instead of silently proceeding. **Named override:** a task
payload can set `allow_defect_blocked_auto_cascade: true` to resume normal
cascading for that EA — e.g. once a governed repair + rebuild has produced
a clean rebuild and a human/Codex reviewer explicitly re-authorizes it. No
existing BLOCKED state is touched and no verdict is rewritten — this only
gates a *convenience side-effect* (automatic phase advancement), matching
the hard constraint to derive/guard rather than un-block or rewrite.

Regression check: `pytest tools/strategy_farm/tests/test_farmctl_cascade.py
tools/strategy_farm/tests/test_defect_block_taint_view.py -q` → 38 passed,
6 subtests passed, in both the canonical checkout and this worktree.

## Files changed

- `tools/strategy_farm/defect_block_taint_view.py` (new)
- `tools/strategy_farm/tests/test_defect_block_taint_view.py` (new, 8 tests)
- `tools/strategy_farm/farmctl.py` (import + auto-cascade guard, ~15 lines)
- `docs/ops/evidence/2026-08-21_defect_block_taint_marker.md` (this file)
- `docs/ops/evidence/2026-08-21_defect_block_taint_marker_audit.json` (regenerated report)

## Verification commands

```
python tools/strategy_farm/defect_block_taint_view.py --db "D:\QM\strategy_farm\state\farm_state.sqlite"
python -m pytest tools/strategy_farm/tests/test_defect_block_taint_view.py -q
python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q
```
