# Defect-blocked gate-row marker — 2026-08-16 cohort

Date: 2026-08-21  
Router task: `5343f90a-08f4-4733-a9a4-7e717e9f4c1d` (`ops_issue`, self-commissioned by Claude during the 2026-08-21 BLOCKED-backlog review)  
Branch: `agents/board-advisor`  
Source database: `D:/QM/strategy_farm/state/farm_state.sqlite` (read-only, `mode=ro`)  
Origin: `docs/ops/evidence/2026-08-21_blocked_backlog_review.md` — section "Finding: defect-blocked EAs left evidence behind".

## Outcome

Fifteen EAs were BLOCKED on 2026-08-16 for known correctness defects. The blocks
held: none produced a gate row after the block. But the gate rows they produced
*before* the block are still in `work_items` and are indistinguishable from clean
evidence in every count. This task makes that taint **visible** without
rewriting a single stored row.

The MNT-016 clean-view module (`tools/strategy_farm/work_item_clean_view.py`) is
extended with three derived, query-only columns on the existing `work_items_clean`
TEMP view:

- `defect_blocked_at_production_time` — integer `0/1`; `1` when the row's EA is
  in the frozen cohort AND its `updated_at` is at or before that EA's block
  moment (the pre-block evidence). A row *after* the block moment is deliberately
  `0` — that would be a block leak (a separate incident), not pre-block evidence.
- `defect_block_reason` — the defect class for a cohort EA
  (`host_slot_magic_conflation`, `unwired_strategy_inputs`,
  `withdrawn_mechanical_approval`), else `NULL`.
- `defect_block_schema` — `qm.work_items.defect_block_cohort.2026-08-16.v1` for a
  cohort EA, else `NULL`.

Derivation is pure: the columns are computed from `work_items.ea_id` /
`work_items.updated_at` against a frozen, hard-coded allow-list
(`DEFECT_BLOCK_COHORT`, a settled historical fact in the same style as the
existing `INFRA_REASON_TOKENS`). No join to `agent_tasks`, no stored `work_items`
row touched. The block moments were looked up live from each EA's latest
2026-08-16 `agent_tasks` BLOCKED transition (`build_ea` and/or `review_ea`).

## Derived marker definition

Schema: `qm.work_items.defect_block_cohort.2026-08-16.v1`

The frozen cohort (EA → block moment → defect class):

| EA | Blocked at (UTC) | Reason |
|---|---|---|
| QM5_10648 | 2026-08-16T21:23:09 | host_slot_magic_conflation |
| QM5_10649 | 2026-08-16T21:23:09 | host_slot_magic_conflation |
| QM5_10973 | 2026-08-16T21:23:10 | host_slot_magic_conflation |
| QM5_11897 | 2026-08-16T21:30:09 | unwired_strategy_inputs |
| QM5_2076 | 2026-08-16T21:30:13 | unwired_strategy_inputs |
| QM5_11301 | 2026-08-16T21:30:08 | withdrawn_mechanical_approval |
| QM5_11302 | 2026-08-16T21:30:08 | withdrawn_mechanical_approval |
| QM5_11689 | 2026-08-16T21:30:10 | withdrawn_mechanical_approval |
| QM5_11898 | 2026-08-16T21:30:10 | withdrawn_mechanical_approval |
| QM5_12352 | 2026-08-16T21:30:10 | withdrawn_mechanical_approval |
| QM5_20070 | 2026-08-16T21:30:11 | withdrawn_mechanical_approval |
| QM5_20071 | 2026-08-16T21:30:12 | withdrawn_mechanical_approval |
| QM5_20179 | 2026-08-16T21:30:13 | withdrawn_mechanical_approval |
| QM5_9354 | 2026-08-16T21:30:13 | withdrawn_mechanical_approval |
| QM5_9501 | 2026-08-16T21:26:18 | withdrawn_mechanical_approval |

`defect_blocked_at_production_time(row) = 1` ⇔ `row.ea_id ∈ cohort` AND
`row.updated_at ≤ cohort[row.ea_id].blocked_at` (a missing `updated_at` fails
safe to `1`, since the cohort produced nothing after its block).

## Live read-only audit (own reproduction)

Before building anything I reproduced the origin numbers directly against
`farm_state.sqlite` (`mode=ro`), and then re-measured through the derived view.
Both agree with the origin doc's 44 / 36 / 8:

- cohort EA count: **15**; EAs with `work_items` rows: **15**;
- rows tagged `defect_blocked_at_production_time=1`: **103**
  (Q02 = 56, Q03 = 8, Q04 = 39);
- of those, PASS rows: **44** (Q02 = **36**, Q03 = **8**) — matches origin exactly;
- deepest phase reached: **Q04**, with **no Q04 PASS**;
- rows updated strictly after the block moment: **0** — the block held;
- `portfolio_candidates` rows for the cohort: **0** — confirmed.

By defect class the 103 tagged rows split 42 magic-conflation / 13 unwired-inputs
/ 48 withdrawn-approval.

Machine report: `docs/ops/evidence/2026-08-21_defect_blocked_gate_row_marker_5343f90a_audit.json`
(the full clean-view audit with the `defect_block_cohort` block appended). At
generation it measured 110,129 source rows, 0 invariant violations, and the
cohort figures above.

Command:

```text
python tools/strategy_farm/work_item_clean_view.py --db D:/QM/strategy_farm/state/farm_state.sqlite --output docs/ops/evidence/2026-08-21_defect_blocked_gate_row_marker_5343f90a_audit.json
```

Exit code 0. The command opens SQLite with `mode=ro`, creates only a TEMP view,
and switches the connection to `query_only`.

## Acceptance criterion 2 — surfaces that include these rows today

The 103 pre-block rows (44 PASS) are read undifferentiated as ordinary evidence
by the **count/statistics** surfaces in `tools/strategy_farm/render_cockpit.py`,
all of which read `work_items_clean`:

- the **funnel** BUILT / P2 / ROBUST / pass stages
  (`SELECT COUNT(DISTINCT ea_id||'|'||symbol) ... WHERE verdict='PASS' ...`);
- the **pass-rate / frontier** counts
  (`COUNT(DISTINCT ea_id) ... WHERE verdict='PASS'`);
- the **adjacent-cohort snapshot** (`pipeline_cohort_snapshot`, Q02→Q03→Q04 …);
- the **daily throughput** and `status`-grouped tiles;
- `dashboards/render_dashboards.py` `collect_archive_v2` (the per-cell archive
  grid) surfaces their PASS cells.

`portfolio_candidates` — the book-selection surface — holds **zero** rows for the
cohort, so there is no book exposure today. These are all statistics/display
reads; none of them *acts on* (promotes, enqueues, admits) the rows.

## Acceptance criterion 3 — can any selection path pick these rows?

**No selection path can currently pick them, and none required a code change.**

- The only active enqueue-selection path, `sweep_enqueue_built_eas.py`, is already
  gated by `review_entry_gate.build_index` (E3), which bars any EA carrying a
  live `BLOCKED`/`FAILED`/`RECYCLE`/`OPS_FIX_REQUIRED` `build_ea`/`review_ea`
  task. I verified live that all 15 cohort EAs are in that index with
  `reason=review_fail_or_blocked, task_state=BLOCKED`. A regression test
  (`test_review_entry_gate_already_excludes_the_cohort`) pins this.
- The book-selection path (`portfolio_candidates`) is structurally unreachable:
  the cohort's deepest phase is Q04, promotion into `portfolio_candidates`
  happens at Q11, and the blocks (live and correct) prevent any advance. Zero
  cohort rows exist in `portfolio_candidates`.

Because the guidance is explicit — *if NO selection path can currently pick them,
state that and do not invent a fix for a non-existent path* — I did **not** modify
any selection query. The new marker is provided so every surface that reads
`work_items_clean` can now exclude the taint (`WHERE
defect_blocked_at_production_time=0`), and so any **future** cohort selector must
name the override to include it. Rewriting the cockpit's published funnel/pass-rate
counts is a statistics-editorial decision left to Claude/OWNER, not silently
changed here.

## Verification

```text
python -m py_compile tools/strategy_farm/work_item_clean_view.py tools/strategy_farm/tests/test_defect_block_cohort_marker.py
# COMPILE OK

python -m pytest -q tools/strategy_farm/tests/test_defect_block_cohort_marker.py tools/strategy_farm/tests/test_work_item_clean_view.py tools/strategy_farm/tests/test_render_cockpit_cohorts.py tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py
# 36 passed
```

The new test file proves: the cohort is exactly the documented fifteen; the
marker is time-gated (pre/at-block tagged, post-block not); `derive_work_item`
and the SQL view expose the three fields without restamping PASS merit; the view
stays query-only and does not rewrite the source; the audit reproduces the PASS
counts and `block_held=True`; and the review-entry gate already excludes the
whole cohort.

No factory, terminal, scheduled task, T_Live, AutoTrading, backtest, work-item,
or historical verdict state was started, stopped, rewritten, or advanced. The 15
blocks were not touched — they remain live and correct; rebuilds are out of scope
(covered by the drain classifier).

## Review disposition

This artifact remains in **REVIEW** for Claude/OWNER close-out. It does not
self-approve or advance pipeline state.
