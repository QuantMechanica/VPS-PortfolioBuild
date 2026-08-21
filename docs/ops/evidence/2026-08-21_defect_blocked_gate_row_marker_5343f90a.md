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
  moment. This tags **all** such pre-block rows, of any verdict — **103** rows in
  production, of which **44** are PASS (the rest FAIL / INFRA_FAIL / ZERO_TRADES,
  including the INFRA_FAIL residue the magic-conflation defect itself produced).
  The origin doc's headline "44" is the PASS subset; the column deliberately
  covers the wider 103 (the INFRA/FAIL rows are just as much tainted evidence). A
  row *after* the block moment is `0` — a block leak (separate incident), not
  pre-block evidence.
- `defect_block_reason` — the defect class for a cohort EA
  (`host_slot_magic_conflation`, `unwired_strategy_inputs`,
  `withdrawn_mechanical_approval`), else `NULL`. Set for **every** cohort-EA row
  (EA-membership), independent of the time gate.
- `defect_block_schema` — `qm.work_items.defect_block_cohort.2026-08-16.v1` for a
  cohort EA, else `NULL`.

Derivation is pure: the columns are computed from `work_items.ea_id` /
`work_items.updated_at` against a frozen, hard-coded allow-list
(`DEFECT_BLOCK_COHORT`, a settled historical fact in the same style as the
existing `INFRA_REASON_TOKENS`). No join to `agent_tasks`, no stored `work_items`
row touched. The block moments were looked up live from each EA's latest
2026-08-16 `agent_tasks` BLOCKED transition (`build_ea` and/or `review_ea`).

### Correction after peer selection-path audit

The clean-view columns above are **display-only insulation**. A peer audit
correctly flagged that they do **not** gate the build-decision **promotion /
expansion pumps** in `farmctl.py`, which read the **raw** `work_items` table with
no BLOCKED exclusion, so a cohort EA's PASS row could be re-promoted today. My
first-pass conclusion — "no selection path can pick these rows" — was wrong: it
only checked the display/cohort surfaces, not the pumps. Five raw-`work_items`
pump queries are now gated (see criterion 3), each behind a default-`False`
`include_defect_blocked_evidence` override.

Building the pump gate also surfaced a subtlety: `updated_at` is **mutable** (the
ablation spawner bumps it when it spawns children), so a time-gated predicate can
be silently defeated. The pump gate therefore keys on **EA-membership** in the
open-defect-block cohort (`work_item_clean_view.defect_block_ea_predicate_sql`),
not on the time-gated column — no row of a currently-blocked defective EA may
advance regardless of when it was produced. In production the two predicates
select the same rows today (the blocks held; zero rows post-block), so the audit
numbers are unchanged; EA-membership is simply robust to later mutation.

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
generation it measured ~110,130 source rows (the DB grows live), 0 invariant
violations, and the cohort figures above.

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

## Acceptance criterion 3 — selection paths that could pick these rows

**Yes — five raw-`work_items` pump queries could pick them. All five are now
gated by default; each takes a named `include_defect_blocked_evidence` override.**

Two paths were already safe and needed no change:

- `sweep_enqueue_built_eas.py` (enqueue) is gated by `review_entry_gate.build_index`
  (E3), which bars any EA with a live `BLOCKED`/`FAILED`/`RECYCLE`/`OPS_FIX_REQUIRED`
  task. Verified live: all 15 cohort EAs are in that index
  (`reason=review_fail_or_blocked, task_state=BLOCKED`); pinned by
  `test_review_entry_gate_already_excludes_the_cohort`.
- `portfolio_candidates` (book selection) holds **zero** cohort rows and is
  structurally unreachable (deepest phase Q04; admission is at Q11).

But the **build-decision promotion / expansion pumps** in `farmctl.py` read the
**raw** `work_items` table with no BLOCKED exclusion, so a cohort EA's PASS row
would be re-promoted on the next pump cycle. These are the real gaps (all
confirmed against current line numbers):

1. Cascade promoter (`cascade_phase_map`, incl. `Q03→Q04`), `farmctl.py`
   ~L16930: cohort's 8 **Q03 PASS** rows → Q04. **Highest risk.**
2. Q02/P2 → Q03/P3 promoter (`_base_q`), ~L16768: cohort's 36 **Q02 PASS** rows.
3. Q02 → Q04 early probe, ~L17088: cohort's Q02 PASS rows → Q04.
4. Q08 → Q09_PORTFOLIO feeder (`_promote_q08_soft_fails_to_q09_portfolio`),
   ~L14892: reachable only if a cohort EA left a Q08 PASS/FAIL_SOFT row — it
   didn't (residue is Q02/Q03/Q04) — covered **defensively**.
5. **Ablation spawner** (§10a P2-PASS → random variants), ~L16711 — found while
   building the fix: it also selects the cohort's Q02 PASS rows, spawns children,
   **and bumps `updated_at`**. This is why the gate is EA-membership based, not
   time-gated (a time gate would be silently un-tagged by this very path).

Fix: a shared default-on `_defect_block_exclusion_clause(...)` injects
`AND NOT (<ea-membership predicate>)` from
`work_item_clean_view.defect_block_ea_predicate_sql` into all five queries. The
override threads as `include_defect_blocked_evidence: bool = False` through
`pump(root, ...)` → `_pump_unlocked(...)` →
`_promote_q08_soft_fails_to_q09_portfolio(...)`; passing `True` restores the old
behaviour. Default posture excludes; the operator must name the flag to include.

Display surfaces (criterion 2) are unchanged: they read `work_items_clean` and
can now filter on the derived columns (`defect_block_reason IS NULL` for
EA-membership, or `defect_blocked_at_production_time=0` for the time-gated
subset). Rewriting the cockpit's published funnel/pass-rate counts remains a
statistics-editorial decision left to Claude/OWNER, not silently changed here.

## Verification

```text
python -m py_compile tools/strategy_farm/work_item_clean_view.py tools/strategy_farm/farmctl.py \
  tools/strategy_farm/tests/test_defect_block_cohort_marker.py tools/strategy_farm/tests/test_farmctl_cascade.py
# COMPILE OK

python -m pytest -q tools/strategy_farm/tests/test_defect_block_cohort_marker.py \
  tools/strategy_farm/tests/test_work_item_clean_view.py \
  tools/strategy_farm/tests/test_render_cockpit_cohorts.py \
  tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py
# 36 passed

python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py::DefectBlockExclusionTests
# 4 passed, 2 subtests passed

python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py
# 30 passed, 6 subtests passed  (no regression in the existing pump/cascade suite)
```

The marker test proves: the cohort is exactly the documented fifteen; the
time-gated column tags pre/at-block rows and not post-block; `derive_work_item`
and the SQL view expose the fields without restamping PASS merit; the view stays
query-only and does not rewrite the source; the audit reproduces 44 PASS /
`block_held=True`; and the review-entry gate already excludes the whole cohort.
The `DefectBlockExclusionTests` prove each pump excludes the cohort's tainted
rows by default and includes them only under the named override, while clean
(non-cohort) EAs always promote.

No factory, terminal, scheduled task, T_Live, AutoTrading, backtest, work-item,
or historical verdict state was started, stopped, rewritten, or advanced. The 15
blocks were not touched — they remain live and correct; rebuilds are out of scope
(covered by the drain classifier).

## Review disposition

This artifact remains in **REVIEW** for Claude/OWNER close-out. It does not
self-approve or advance pipeline state.
