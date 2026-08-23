# rb-archive-v4 — Strategy Archive v4 reconciliation evidence

Date: 2026-08-23

Scope: ticket `rb-archive-v4` (T1–T4, T7 only)

Runtime DB: `D:/QM/strategy_farm/state/farm_state.sqlite`, opened read-only (`mode=ro`).

## Outcome

- Archive topology is manifest-derived and begins at the manifest's third top-level gate. The active v3 gate set/order remains `Q02,Q03,Q04,Q05,Q06,Q07,Q08,Q09,Q10,Q14,Q15,Q16,Q11,Q12,Q13`; the v4 draft fixture yields `Q02..Q17`. Implementation: `tools/strategy_farm/dashboards/archive_matrix.py:54-94`.
- Stored rows resolve by `(phase, gate_contract_version)` through `phase_qid`, `phase_label`, and the manifest advancement table. Matrix resolution is at `archive_matrix.py:140-147,357-425`; the EA-detail query and provenance label are at `archive_matrix.py:688-720,1087-1128`. `work_items_clean` now projects the optional version stamp at `tools/strategy_farm/work_item_clean_view.py:507`.
- The archive reuses the shared read-only operator frontier model, which overlays the governed planner CSV without cloning action policy (`tools/strategy_farm/operator_surfaces.py:108-153`; planner action function `tools/strategy_farm/backfill_planner.py:335-363`).
- Work-item-backed gap chips are exactly planner `FILL_MISSING`, `RERUN_INFRA`, or `REBIND_STALE`; the action word is in each tooltip. `STOP_ECONOMIC_FAIL` forces the economic FAIL chip, while `STOP_NOT_APPLICABLE` remains empty (`archive_matrix.py:479-503`).
- The informational news/portfolio lane no longer advances the contiguous-valid frontier (`tools/strategy_farm/rebaseline_census.py:258-313,349-358`). Consequently, `PASS_PORTFOLIO` alone produces the news prerequisite action and never licenses a successor gap.
- Ranking uses the shared `highest_contiguous_valid_gate`, not the greatest observed PASS. Later retirement/stale rows no longer suppress planner work; STOP semantics control the result (`archive_matrix.py:511-560`).
- OWNER/manual gates are visibly grouped as `Buch/Betrieb (OWNER)` and never receive gap chips. Card-frontmatter targets remain a separate state labelled `nie getestet (Card-Ziel)` (`archive_matrix.py:63-94,501-510,593-613`).
- Every rendered chip tooltip contains verdict, date, and full work-item ID; every expanded empty cell receives a derived reason. The footer prints resolved gate tokens only (`archive_matrix.py:564-613,1293-1458`).
- F4 stale-pass rendering was not built. Its warning/fallback remains in place pending SH-2, as required.

No gate threshold, criterion, verdict row, queue row, factory state, backtest enqueue, or `T_Live` path was changed.

## Read-only render evidence

Command:

```text
python tools/strategy_farm/dashboards/archive_matrix.py --db D:/QM/strategy_farm/state/farm_state.sqlite --output C:/QM/worktrees/rb-archive-v4/.scratch/rb-archive-v4/strategy_archive.html
```

Result:

```text
output: C:\QM\worktrees\rb-archive-v4\.scratch\rb-archive-v4\strategy_archive.html
bytes: 17,383,445
sha256: 03F88B7E59D3BA94B2C113EC139F2CE67CE409D7D53F364CCC569AD1917EAA80
cards: 2,984
stored gate groups: 25,052
actionable gaps: 6,118
collect time: 5.61 s
legacy P[0-9] matches: 0
```

The scratch output is ignored/uncommitted. No file under `D:/QM/strategy_farm/dashboards` was overwritten.

## Archive/backfill reconciliation

Command:

```text
python docs/ops/rebaseline/reconcile_archive_backfill.py
```

Result:

```text
archive work-item gap pairs: 6,118
  FILL_MISSING 5,018; RERUN_INFRA 1,016; REBIND_STALE 84
backfill actionable pairs: 6,131
intersection: 6,118
exact gate+action: 6,118
mismatch: 0
archive-only: 0
backfill-only: 13
  12 relic-symbol Q02/RERUN_INFRA rows excluded by archive F7
  1 harness-fixture Q02/FILL_MISSING row with no manifest-gate/card row
Card-target second-source gaps: 656
```

Documented delta from the pre-ticket reconciliation (`archive-only=696`, `backfill-only=357` for its narrower FILL-only comparison): archive-only work-item gaps are now zero; the remaining 13 backfill-only rows are intentional archive scope exclusions. The 656 Card-target rows are no longer mixed into work-item gap deltas.

## Tests

Focused tests for all touched modules and contract-version consumers:

```text
python -m pytest -q tools/strategy_farm/tests/test_archive_matrix_v4.py tools/strategy_farm/tests/test_rebaseline_census.py tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py tools/strategy_farm/tests/test_backfill_planner.py tools/strategy_farm/tests/test_work_item_clean_view.py tools/strategy_farm/tests/test_gate_contract_version.py tools/strategy_farm/tests/test_pipeline_view_work_items.py tools/strategy_farm/tests/test_mission_control_v2_data.py
75 passed, 1 skipped in 5.91s
```

Archive/dashboard and manifest regressions unaffected by the known Pipeline Books binding issue:

```text
python -m pytest -q tools/strategy_farm/tests/test_archive_admission_cache.py tools/strategy_farm/tests/test_custom_history_archive_admission.py tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py tools/strategy_farm/tests/test_render_cockpit_cohorts.py tools/strategy_farm/tests/test_render_cockpit_v2.py tools/strategy_farm/tests/test_website_archive_contract.py tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_optimization_track_manifest_v2.py tools/strategy_farm/tests/test_activate_gate_manifest_v4.py
131 passed, 2 skipped in 5.28s
```

The broader dashboard-name sweep produced `151 passed, 2 skipped, 30 failed`. All 30 failures are outside the touched archive path and share one pre-existing governed binding error: the FTMO rulepack expects snapshot SHA `60f94e0d...84b72`, while its checked-out source validates as `5c0763bb...1bad`. The failing modules are `test_pipeline_books_dashboard_status.py` and `test_render_cockpit_pipeline_books.py`. This ticket did not alter that rulepack, its source snapshot, or its hash binding.

New regression coverage is in `tools/strategy_farm/tests/test_archive_matrix_v4.py:72-192` and the informational-lane census test is at `tools/strategy_farm/tests/test_rebaseline_census.py:78-92`.

## Risks and rollback

- F4 remains blocked on SH-2; latest-verdict fallback can still show a stale PASS as current, with the existing visible warning.
- Live archive gap equality is bound to the governed dated planner artifact `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv`. If that artifact is absent, the shared model falls back to the planner's public census-action classifier; the page stays read-only but should be reconciled again after a new governed plan is published.
- The full HTML is 16.58 MiB. This is within the prototype's expected range but remains a client-side payload risk.
- Roll back code and tests with `git revert --no-edit <this-ticket-commit>`. The scratch HTML is not tracked and may be removed independently; no runtime DB/dashboard rollback is needed because neither was written.
