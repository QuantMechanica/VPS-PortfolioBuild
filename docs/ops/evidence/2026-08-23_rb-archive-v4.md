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

## Review fixes (2026-08-23, FIX_REQUIRED closure on the v4-active merged tree)

Reviewer verdict `FIX_REQUIRED` was raised because the branch was cut under the v3
contract while the factory now runs v4 (`agents/board-advisor`). `agents/board-advisor`
was merged into this branch and the fixes below applied. **v4 is the active contract**
on the merged tree (`DEFAULT_MANIFEST = gate_manifest.v4.json`, `ACTIVE_GATE_CONTRACT_VERSION == "v4"`).

### P0 — legacy historical rows mislabelled under v4 numbering (`phase_ids.py`) — FIXED
- Root cause confirmed: the live DB stamps 111,369 historical rows `gate_contract_version='legacy'`
  (21 `v3`, 390 `v4` at fix time), and `_normalise_contract_version` maps `'legacy'->None`,
  so `_resolve_versioned_phase` did **no** v3->v4 translation for them. Renumbered gates
  collided (v3 Q10 Incumbent rendered in the v4 Q10 News column; v3 Q14/Q15 optimization
  rows mislabelled; v3 `Q09_NEWS`/`Q09_PORTFOLIO` dropped as `skipped_phase`).
- Fix (finding option **b**): in `phase_ids._resolve_versioned_phase`, an **explicit**
  `legacy` stamp is now read under v3 numbering and translated forward through the v4
  manifest's `contract_equivalence` table, carrying an explicit `(v3:<id>)` provenance
  suffix — the old id is never silently reinterpreted (OWNER: "historical rows are never
  re-read with v4 semantics"). Unchanged gates (Q02–Q08), P-key aliases, and utility
  phases keep their historical pass-through. A genuinely absent/empty stamp keeps the
  graceful active pass-through (the live DB holds no such rows); this bounds the blast
  radius to the real `legacy`-stamped corpus and leaves the queue/pipeline surfaces that
  model current rows as NULL unchanged.
- Verified against the LIVE DB (`mode=ro`): work-item `788d2371` (v3 Q10 Incumbent PASS,
  stamped `legacy`) now resolves to the **Q11** column and labels
  `Q11 Incumbent Full-History Confirmation (v3:Q10)`. `resolved_gate('Q10','legacy') == 'Q11'`.
- New regression test: `tools/strategy_farm/tests/test_archive_matrix_v4.py::test_legacy_stamped_incumbent_renders_in_v4_incumbent_column`
  loads v4 as active and asserts a `legacy` Q10 PASS renders in the v4 Q11 column with
  `(v3:Q10)` provenance and never in the v4 Q10 (News) column.

### P1 — merge add/add conflict in `reconcile_archive_backfill.py` — FIXED
- Resolved to HEAD's dict-based version (`am.collect()`, `cell["state"] == am.ST_HOLE`,
  `cell["symbol_index"]`, `cell["action"]`, `card["symbols"]`). board-advisor's dead-API
  variant (`am.COLUMNS`, bit-packed `packed & 7` / `packed >> 3`) was discarded — that API
  was removed by this PR and would raise `AttributeError`.
- Verified it runs against the LIVE DB on the merged tree (exit 0): archive gap pairs 6,118
  (FILL_MISSING 5,018; RERUN_INFRA 1,016; REBIND_STALE 84); intersection 6,118; mismatch 0;
  archive-only 0; backfill-only 13 (12 relic-symbol F7 exclusions + 1 harness fixture) — matching
  the pre-review reconciliation above.

### P1 — primary regression suites pinned to v3-active — FIXED
- `test_archive_matrix_v4.py`: columns test now asserts the ambient (v4) topology is linear
  `Q02..Q17` and pins `V3_MANIFEST` for the v3 fork order; `resolved_gate('Q10','v3')=='Q11'`,
  `resolved_gate('Q10','v4')=='Q10'`, `resolved_gate('Q10','legacy')=='Q11'`; the fixture's
  v3 Incumbent asserts the v4 Q11 column with `(v3:Q10)` provenance and the native v4
  `Q10_NEWS`/`Q17` rows assert no cross-contract suffix; detail-page provenance updated to v4.
- `test_rebaseline_census.py`: `canonical_gate` assertions made version-explicit for v4
  (`Q10_NEWS/v4 -> NEWS_GATE`, `Q09_NEWS/v3 -> NEWS_GATE`, `Q10/v3 -> Q11`, `Q11/v3 -> None`);
  the full-chain and terminal-requalification tests use the v4 terminal (`Q14`); the fixture
  DDL/insert now stamp `gate_contract_version` (default `v4`) so v4 gate ids are read under v4.

### P2 — native v4 NEWS pass mis-classed as legacy-only (`rebaseline_census.build_pairs`) — FIXED
- The `raw.startswith("Q09")` heuristic tagged a current v4 `Q10_NEWS` pass as
  `valid_legacy`. Replaced with a manifest-independent provenance split: only a legacy
  `P*`/`G0` alias (`raw in LEGACY_ALIAS`) is `valid_legacy`; any Qxx-form phase that
  resolved onto the chain — ordinary gate or native NEWS lane in either contract — is
  `valid_canonical`.

### v4-activation test debt exposed by the merge (fixed where in this ticket's surfaces)
- `test_pipeline_view_work_items.py::test_pipeline_view_folds_mixed_case_legacy_suffix_phases`:
  the v4 manifest's `legacy_aliases` map `P9B -> Q16` (v3 was `P9B -> Q12`); `pipeline_view`
  resolves P-keys through the active manifest, so the fold is now `Q16`. Test updated to v4
  (independent of the P0 fix — fails identically with the P0 change reverted).
- `test_render_cockpit_cohorts.py::test_cohort_renderer_labels_mixed_era_chips_and_q09_q10_contracts`:
  `LIFETIME_PASS_CHIP_LABEL` is manifest-derived from `Q_DISPLAY_ORDER`; under v4 it reads
  `Q00-Q17` (v3 was `Q00-Q16`). Test now derives the range and pins the v4 terminal.

### Re-run tests on the v4-active merged tree
Primary suite (evidence command):
```text
python -m pytest -q tools/strategy_farm/tests/test_archive_matrix_v4.py \
  tools/strategy_farm/tests/test_rebaseline_census.py \
  tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py \
  tools/strategy_farm/tests/test_backfill_planner.py \
  tools/strategy_farm/tests/test_work_item_clean_view.py \
  tools/strategy_farm/tests/test_gate_contract_version.py \
  tools/strategy_farm/tests/test_pipeline_view_work_items.py \
  tools/strategy_farm/tests/test_mission_control_v2_data.py
76 passed, 1 skipped
```
Archive/dashboard/manifest regressions:
```text
python -m pytest -q tools/strategy_farm/tests/test_archive_admission_cache.py \
  tools/strategy_farm/tests/test_custom_history_archive_admission.py \
  tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py \
  tools/strategy_farm/tests/test_render_cockpit_cohorts.py \
  tools/strategy_farm/tests/test_render_cockpit_v2.py \
  tools/strategy_farm/tests/test_website_archive_contract.py \
  tools/strategy_farm/tests/test_gate_manifest.py \
  tools/strategy_farm/tests/test_optimization_track_manifest_v2.py \
  tools/strategy_farm/tests/test_activate_gate_manifest_v4.py
133 passed, 2 skipped
```

### Re-run render on the v4-active merged tree
```text
python tools/strategy_farm/dashboards/archive_matrix.py --db D:/QM/strategy_farm/state/farm_state.sqlite \
  --output <scratch>/strategy_archive_v4.html
bytes: 17,720,034 (16.90 MiB)
sha256: 1b71b0d153491328307a73b0c7ff213d928edbb5ccc996fe2b64145fa82adf27
legacy P[0-9] leaks: 0
skipped_phase: no longer contains Q09_NEWS/Q09_PORTFOLIO (both now resolve to the v4 Q10 column)
collect_s: 855.4 (heavy live-DB write contention from the running factory; unrelated to this change)
```
The HTML exceeds the 16 MB Artifact ceiling; this is a disk dashboard under `D:/QM`, not an
Artifact publish, so the ceiling does not apply. Payload size remains a client-side risk (noted above).

### Out of scope — pre-existing v4-activation test debt inherited from `agents/board-advisor`
Running the broader phase-resolution consumers surfaced 32 failures in
`test_q09_news_runner_v2.py` (27) and `test_q10_confirmation_contract_v2.py` (5). These are
**not** caused by this ticket: they fail identically with the P0/P2 source edits reverted.
`agents/board-advisor` changed `q09_news_schema.py` for v4 activation without updating those
suites (the test files are byte-identical to merge-base on both branches; the contract now
requires the v4 `Q11` incumbent phase). They belong to the gate-contract domain (ROT:
gate-contract criteria), outside this archive ticket's scope (T1–T4, T7), and are left for the
v4-activation owner to resolve.
