# Gate-Name / Phase-Key Census - 2026-08-23

**Author:** Claude (Orchestrator) - **Branch:** agents/board-advisor - **Read-only inventory** (no code/verdict/vault edits).
**Directive:** vault `03 Pipeline/Pipeline Rebaseline Directive 2026-08-23.md` sec.3 (linear gate renumbering) + sec.7.1 (Ist-Gate/Code-drift inventory).
**Runtime contract:** `tools/strategy_farm/config/gate_manifest.v3.json` (ACTIVE 2026-08-23; gates Q00..Q16). Thresholds/criteria are ROT - this census maps *where identifiers live*, it does not propose new numbers.

## 0 - Scope & method

Scanned line-by-line for gate identifiers (`Q00..Q16`, compounds `Q09_NEWS`/`Q09_PORTFOLIO`/`Q10A`/`Q11_DXZ`/`Q11_FTMO`/`Q08_INPUT`/`Q08_10`) and legacy storage keys (`G0`,`P1`..`P10`,`P3.5`,`P5B`,`P5C`,`P9B`) across the renumbering-relevant surfaces: `tools/strategy_farm/**` (`.py .ps1 .json .sql`), `scripts/**` (`.py .ps1`), `public-data/**` (`.json`). Docs and vault pages are enumerated at file level only (immutable evidence / human surfaces - not renumbered by code).

**Code/contract scope: 5127 occurrences across 329 files.**

| kind | occurrences |
|---|---|
| hardcoded literal | 3851 |
| hardcoded legacy-P literal | 586 |
| manifest/schema/contract | 408 |
| DB constraint/query | 232 |
| hardcoded literal (ps1) | 50 |
| **total** | **5127** |

Docs (`docs/**/*.md`) containing gate ids: **2213 files** (informational; historical evidence, not renumbered).

## 1 - Manifest-resolved vs hardcoded: the safety classification

The single source of gate numbering/names is the manifest loader chain: `config/gate_manifest.v3.json` -> `gate_manifest.py::load_gate_manifest()` -> `phase_ids.py` (`PHASE_ORDER`, `PHASE_NAME`, `PHASE_NEXT`, `phase_label()`, `phase_qid()`, `LEGACY_P_TO_Q`).

**SAFE for renumbering (names/order flow from the manifest automatically):**

- `tools/strategy_farm/config/gate_manifest.v3.json` - the contract itself: change gate `id`/`name`/`next`/`legacy_aliases`/`extension_topology` here and every downstream *display* follows. Historical rows keep meaning via `gate_contract_version`; `legacy_policy=READ_AND_MIGRATION_ONLY`, `write_policy=CANONICAL_ONLY`.
- `tools/strategy_farm/gate_manifest.py` + `tools/strategy_farm/phase_ids.py` - the resolver. Contains *hardcoded fixture/guard literals* (schema-version pins, `REQUIRED_LEGACY_ALIASES`, `ACTIVATION_REVIEW_REFS`, v1/v2 `PHASE_IDS` tuples, Q10A guard strings) that DO need editing when the topology changes, but they are the intended single edit point.
- Dashboard *display* paths that call `phase_label()`/`PHASE_NAME` on a runtime `phase` value (not a literal): names re-render from the manifest with zero edits.

Resolver-consumer files (import the loader / `phase_ids`):
- `tools/strategy_farm/dashboards/render_dashboards.py` - 160 tokens, phase_label/PHASE_NAME uses=82
- `tools/strategy_farm/farmctl.py` - 836 tokens, phase_label/PHASE_NAME uses=10
- `tools/strategy_farm/gate_manifest.py` - 120 tokens, phase_label/PHASE_NAME uses=0
- `tools/strategy_farm/mission_control_v2_data.py` - 30 tokens, phase_label/PHASE_NAME uses=5
- `tools/strategy_farm/phase_ids.py` - 47 tokens, phase_label/PHASE_NAME uses=18
- `tools/strategy_farm/render_cockpit.py` - 283 tokens, phase_label/PHASE_NAME uses=8
- `tools/strategy_farm/tests/test_gate_manifest.py` - 79 tokens, phase_label/PHASE_NAME uses=10

**Fully safe (import the resolver, ZERO hardcoded gate literals - render entirely from the manifest):** `tools/strategy_farm/website_archive_contract.py` (uses `PHASE_NAME.get(gate, gate)`, `phase_qid`) and `tools/strategy_farm/work_identity.py` (uses `phase_qid()`). These need no edits on renumber; they do not appear in the per-file table below precisely because they carry no literal.

**MUST CHANGE (hardcoded literals in logic/SQL/contracts - numbering does NOT flow):** Even inside resolver-consumer files, any literal `'Q08'`/`'P2'` used in an SQL `WHERE phase IN (...)`, a set/list of phases, a branch (`if phase == 'Q09_NEWS'`), or a JSON contract is a hardcoded coupling that must be edited on renumbering.

## 2 - Per-file census (renumbering surfaces, count desc)

`rc`=resolver-consumer (imports manifest/phase_ids). `plu`=phase_label/PHASE_NAME uses in file. A high `rc=1` file with hardcoded-literal kinds still needs edits in its SQL/branch logic.

| file | count | rc | plu | kinds |
|---|--:|:--:|--:|---|
| `tools/strategy_farm/farmctl.py` | 836 | 1 | 10 | hardcoded literal:582, hardcoded legacy-P literal:201, DB constraint/query:53 |
| `tools/strategy_farm/render_cockpit.py` | 283 | 1 | 8 | hardcoded literal:201, DB constraint/query:53, hardcoded legacy-P literal:29 |
| `tools/strategy_farm/q09_news_runner.py` | 190 | 0 | 0 | hardcoded literal:188, DB constraint/query:2 |
| `tools/strategy_farm/dashboards/render_dashboards.py` | 160 | 1 | 82 | hardcoded literal:115, hardcoded legacy-P literal:45 |
| `tools/strategy_farm/gate_manifest.py` | 120 | 1 | 0 | hardcoded literal:105, hardcoded legacy-P literal:15 |
| `scripts/build_pipeline_state.py` | 118 | 0 | 2 | hardcoded legacy-P literal:64, hardcoded literal:54 |
| `tools/strategy_farm/config/gate_manifest.v3.json` | 108 | 0 | 0 | manifest/schema/contract:108 |
| `tools/strategy_farm/health.py` | 99 | 0 | 0 | hardcoded literal:74, DB constraint/query:17, hardcoded legacy-P literal:8 |
| `tools/strategy_farm/tests/test_farmctl_cascade.py` | 97 | 0 | 0 | hardcoded literal:79, DB constraint/query:11, hardcoded legacy-P literal:7 |
| `tools/strategy_farm/tests/test_candidate_repair_enqueue.py` | 90 | 0 | 0 | hardcoded literal:90 |
| `tools/strategy_farm/q09_news_schema.py` | 89 | 0 | 0 | hardcoded literal:77, DB constraint/query:12 |
| `tools/strategy_farm/config/gate_manifest.v2.json` | 89 | 0 | 0 | manifest/schema/contract:89 |
| `tools/strategy_farm/tests/test_requeue_stranded_infra.py` | 82 | 0 | 0 | hardcoded literal:82 |
| `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py` | 82 | 0 | 0 | hardcoded literal:62, hardcoded legacy-P literal:20 |
| `tools/strategy_farm/tests/test_gate_manifest.py` | 79 | 1 | 10 | hardcoded literal:76, hardcoded legacy-P literal:3 |
| `tools/strategy_farm/ea_metrics.py` | 70 | 0 | 1 | hardcoded literal:68, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/requeue_stranded_infra.py` | 70 | 0 | 0 | hardcoded literal:70 |
| `tools/strategy_farm/analyze_q04_survivor_cohort.py` | 62 | 0 | 5 | hardcoded literal:56, DB constraint/query:6 |
| `tools/strategy_farm/config/gate_manifest.v1.json` | 59 | 0 | 0 | manifest/schema/contract:59 |
| `tools/strategy_farm/tests/test_ingest_phase_aggregates.py` | 57 | 0 | 0 | hardcoded literal:57 |
| `tools/strategy_farm/tests/test_q09_news_farmctl_integration.py` | 48 | 0 | 0 | hardcoded literal:39, DB constraint/query:7, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/phase_ids.py` | 47 | 1 | 18 | hardcoded literal:33, hardcoded legacy-P literal:14 |
| `tools/strategy_farm/sweep_enqueue_built_eas.py` | 46 | 0 | 4 | hardcoded literal:43, DB constraint/query:2, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/terminal_worker.py` | 45 | 0 | 0 | hardcoded literal:33, hardcoded legacy-P literal:12 |
| `tools/strategy_farm/tests/test_render_cockpit_cohorts.py` | 45 | 0 | 0 | hardcoded literal:45 |
| `tools/strategy_farm/schemas/gate_manifest.v3.schema.json` | 44 | 0 | 0 | manifest/schema/contract:44 |
| `tools/strategy_farm/tests/test_optimization_track_manifest_v2.py` | 42 | 0 | 0 | hardcoded literal:39, DB constraint/query:3 |
| `tools/strategy_farm/tests/test_ultracode_wsa_claim.py` | 40 | 0 | 0 | hardcoded literal:40 |
| `tools/strategy_farm/tests/test_q09_news_schema_v2.py` | 36 | 0 | 0 | hardcoded literal:26, DB constraint/query:10 |
| `tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py` | 36 | 0 | 0 | hardcoded literal:30, hardcoded legacy-P literal:4, DB constraint/query:2 |
| `tools/strategy_farm/analyze_mistested_ea_rescue_queue.py` | 34 | 0 | 0 | hardcoded literal:33, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/mission_control_v2_data.py` | 30 | 1 | 5 | hardcoded literal:21, hardcoded legacy-P literal:9 |
| `tools/strategy_farm/q10_confirmation_contract.py` | 29 | 0 | 0 | hardcoded literal:29 |
| `tools/strategy_farm/portfolio/portfolio_q08_contribution.py` | 29 | 0 | 0 | hardcoded literal:29 |
| `tools/strategy_farm/q09_live_news_backfill.py` | 28 | 0 | 0 | hardcoded literal:28 |
| `tools/strategy_farm/tests/test_pipeline_view_work_items.py` | 27 | 0 | 0 | hardcoded literal:25, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/backfill_setfile_strategy_params.py` | 26 | 0 | 0 | hardcoded literal:26 |
| `tools/strategy_farm/optimization_dashboard_status.py` | 25 | 0 | 0 | hardcoded literal:25 |
| `tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py` | 25 | 0 | 0 | hardcoded literal:24, DB constraint/query:1 |
| `scripts/export_public_snapshot.ps1` | 25 | 0 | 0 | hardcoded literal (ps1):25 |
| `tools/strategy_farm/tests/test_mission_control_v2_data.py` | 24 | 0 | 0 | hardcoded literal:24 |
| `public-data/public-snapshot.schema.json` | 24 | 0 | 0 | manifest/schema/contract:24 |
| `tools/strategy_farm/schemas/gate_manifest.v2.schema.json` | 23 | 0 | 0 | manifest/schema/contract:23 |
| `tools/strategy_farm/tests/test_health_vacuousness.py` | 23 | 0 | 0 | hardcoded literal:23 |
| `tools/strategy_farm/screen_pool_2p2.py` | 21 | 0 | 0 | hardcoded literal:21 |
| `tools/strategy_farm/portfolio/ftmo_cost_adjusted_export.py` | 21 | 0 | 0 | hardcoded literal:21 |
| `scripts/qm_pipeline_summary.py` | 21 | 0 | 0 | hardcoded legacy-P literal:21 |
| `tools/strategy_farm/isolated_work_item_runner.py` | 20 | 0 | 0 | hardcoded literal:20 |
| `tools/strategy_farm/near_miss_register.py` | 17 | 0 | 0 | hardcoded literal:17 |
| `tools/strategy_farm/q08_v3_migration_inventory.py` | 16 | 0 | 0 | hardcoded literal:14, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/repair.py` | 16 | 0 | 0 | hardcoded literal:7, hardcoded legacy-P literal:6, DB constraint/query:3 |
| `tools/strategy_farm/portfolio/book_builder_common.py` | 16 | 0 | 0 | hardcoded literal:16 |
| `tools/strategy_farm/portfolio/ftmo_qualification.py` | 16 | 0 | 0 | hardcoded literal:13, DB constraint/query:3 |
| `tools/strategy_farm/tests/test_cascade_chain_p2_to_p8.py` | 16 | 0 | 0 | hardcoded legacy-P literal:16 |
| `tools/strategy_farm/tests/test_render_cockpit_v2.py` | 16 | 0 | 0 | hardcoded literal:13, hardcoded legacy-P literal:3 |
| `tools/strategy_farm/monitor_intraday_edges.py` | 15 | 0 | 0 | hardcoded literal:15 |
| `tools/strategy_farm/morning_brief.py` | 15 | 0 | 0 | hardcoded literal:15 |
| `tools/strategy_farm/portfolio/ftmo_requalification_binding.py` | 15 | 0 | 0 | hardcoded literal:15 |
| `tools/strategy_farm/tests/test_basket_work_items.py` | 15 | 0 | 0 | hardcoded literal:14, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/ingest_phase_aggregates.py` | 14 | 0 | 0 | hardcoded literal:14 |
| `tools/strategy_farm/phase_runner_allowlist.v1.json` | 14 | 0 | 0 | manifest/schema/contract:14 |
| `tools/strategy_farm/plausibility_scan.py` | 14 | 0 | 0 | hardcoded literal:14 |
| `tools/strategy_farm/portfolio/requeue_q09_stranded_sleeves.py` | 14 | 0 | 0 | hardcoded literal:13, DB constraint/query:1 |
| `tools/strategy_farm/tests/test_cascade_real_phase_runners.py` | 14 | 0 | 0 | hardcoded legacy-P literal:9, hardcoded literal:5 |
| `tools/strategy_farm/tests/test_health_q02_stranded.py` | 14 | 0 | 0 | hardcoded literal:10, hardcoded legacy-P literal:4 |
| `tools/strategy_farm/tests/test_opt_census_dispatch.py` | 14 | 0 | 0 | hardcoded literal:14 |
| `tools/strategy_farm/tests/test_q09_live_news_diagnostic.py` | 14 | 0 | 0 | hardcoded literal:14 |
| `tools/strategy_farm/tests/test_website_archive_contract.py` | 14 | 0 | 0 | hardcoded literal:10, hardcoded legacy-P literal:4 |
| `tools/strategy_farm/agent_router.py` | 13 | 0 | 0 | hardcoded literal:9, hardcoded legacy-P literal:2, DB constraint/query:2 |
| `tools/strategy_farm/portfolio/challenge_two_phase.py` | 13 | 0 | 0 | hardcoded literal:8, hardcoded legacy-P literal:5 |
| `tools/strategy_farm/portfolio/ftmo_p1_mc.py` | 13 | 0 | 0 | hardcoded literal:13 |
| `tools/strategy_farm/portfolio/gen_dxz24b_20260726.py` | 13 | 0 | 0 | hardcoded literal:13 |
| `public-data/public-snapshot.json` | 13 | 0 | 0 | manifest/schema/contract:13 |
| `tools/strategy_farm/evidence_cascade_driver.py` | 12 | 0 | 0 | hardcoded literal:12 |
| `tools/strategy_farm/opt_census.py` | 12 | 0 | 0 | hardcoded literal:9, DB constraint/query:2, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/portfolio/audit_activity_criterion.py` | 12 | 0 | 0 | hardcoded literal:11, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/portfolio/ftmo_daily_net_export.py` | 12 | 0 | 0 | hardcoded literal:12 |
| `tools/strategy_farm/tests/test_q09_news_runner_v2.py` | 12 | 0 | 0 | hardcoded literal:9, DB constraint/query:3 |
| `tools/strategy_farm/prioritize_intraday_ftmo.py` | 11 | 0 | 0 | hardcoded literal:11 |
| `tools/strategy_farm/set_priority_track.py` | 11 | 0 | 0 | hardcoded literal:11 |
| `tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py` | 11 | 0 | 0 | hardcoded literal:11 |
| `tools/strategy_farm/tests/test_ftmo_qualification.py` | 11 | 0 | 0 | hardcoded literal:11 |
| `tools/strategy_farm/tests/test_progress_aware_reaper.py` | 11 | 0 | 0 | hardcoded literal:11 |
| `tools/strategy_farm/tests/test_q10_confirmation_contract_v2.py` | 11 | 0 | 0 | hardcoded literal:7, DB constraint/query:4 |
| `tools/strategy_farm/dxz_as_live_requal.py` | 10 | 0 | 0 | hardcoded literal:10 |
| `tools/strategy_farm/q04_pf_plausibility_reclassify.py` | 10 | 0 | 0 | hardcoded literal:10 |
| `tools/strategy_farm/q07_zero_seed_outlier_reclassify.py` | 10 | 0 | 0 | hardcoded literal:10 |
| `tools/strategy_farm/strategy_card_v3.py` | 10 | 0 | 0 | hardcoded literal:9, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/portfolio/challenge_book_60d.py` | 10 | 0 | 0 | hardcoded literal:8, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/portfolio/portfolio_periodic_report.py` | 10 | 0 | 0 | hardcoded literal:9, DB constraint/query:1 |
| `tools/strategy_farm/tests/test_levelup_cohort0.py` | 10 | 0 | 0 | hardcoded literal:10 |
| `tools/strategy_farm/tests/test_mnt039_limbo_contract.py` | 10 | 0 | 0 | hardcoded literal:7, hardcoded legacy-P literal:3 |
| `tools/strategy_farm/q08_v3_migration_plan.py` | 9 | 0 | 0 | hardcoded literal:8, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/portfolio/challenge_as_deployed.py` | 9 | 0 | 0 | hardcoded literal:9 |
| `tools/strategy_farm/portfolio/challenge_defensible.py` | 9 | 0 | 0 | hardcoded literal:9 |
| `tools/strategy_farm/portfolio/challenge_final.py` | 9 | 0 | 0 | hardcoded literal:9 |
| `tools/strategy_farm/portfolio/challenge_firstpassage.py` | 9 | 0 | 0 | hardcoded literal:9 |
| `tools/strategy_farm/tests/test_defect_block_taint_view.py` | 9 | 0 | 0 | hardcoded literal:9 |
| `tools/strategy_farm/tests/test_p2_full_dwx_fanout.py` | 9 | 0 | 0 | hardcoded legacy-P literal:8, hardcoded literal:1 |
| `tools/strategy_farm/tests/test_phase_runner_process_lineage.py` | 9 | 0 | 0 | hardcoded literal:7, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py` | 9 | 0 | 0 | hardcoded literal:7, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/classify_recovery_pending.py` | 8 | 0 | 0 | hardcoded literal:4, hardcoded legacy-P literal:2, DB constraint/query:2 |
| `tools/strategy_farm/heartbeat_snapshot.py` | 8 | 0 | 0 | DB constraint/query:4, hardcoded literal:4 |
| `tools/strategy_farm/invalidate_unprofitable_cascade.py` | 8 | 0 | 0 | hardcoded legacy-P literal:7, DB constraint/query:1 |
| `tools/strategy_farm/prepare_book_q08_regeneration.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/requeue_false_progress_reap.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/config/opt_program.v1.json` | 8 | 0 | 0 | manifest/schema/contract:8 |
| `tools/strategy_farm/portfolio/challenge_campaign_capped.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/portfolio/challenge_campaign_mae.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/portfolio/challenge_overlay.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/portfolio/dormancy_exposure.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/portfolio/ftmo_bar_joint_book_sim.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/portfolio/sleeve_speed.py` | 8 | 0 | 0 | hardcoded literal:5, DB constraint/query:3 |
| `tools/strategy_farm/tests/test_ftmo_requalification_binding.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/tests/test_isolated_work_item_runner.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/tests/test_q04_latest_full_year_payload.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/tests/test_q16_head_to_head.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/tests/test_retire_approved_cards.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/tests/test_summary_missing_classification.py` | 8 | 0 | 0 | hardcoded literal:8 |
| `tools/strategy_farm/audit_q04_native_report_guard.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/classify_q02_stranded_pairs_report.py` | 7 | 0 | 0 | DB constraint/query:4, hardcoded literal:2, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/dxz_cost_evidence.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/mnt_closure_drift.py` | 7 | 0 | 0 | hardcoded literal:6, DB constraint/query:1 |
| `tools/strategy_farm/q09_news_migration.py` | 7 | 0 | 0 | hardcoded literal:4, DB constraint/query:3 |
| `tools/strategy_farm/portfolio/audit_family_asset_matrix.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/portfolio/build_book_ftmo.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/portfolio/gen_dxz23_20260726.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/portfolio/runner_satellite_composer.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/portfolio/survivor_skew.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/tests/test_p2_prescreen_policy.py` | 7 | 0 | 0 | hardcoded literal:6, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_portfolio_q08_contribution.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/tests/test_priority_track_new_q02.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/tests/test_q04_exact_evidence_binding.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/tests/test_ultracode_wsh_q08_reason.py` | 7 | 0 | 0 | hardcoded literal:7 |
| `tools/strategy_farm/gen_spec_md.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/ws0_notifier.py` | 6 | 0 | 0 | DB constraint/query:2, hardcoded literal:2, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/portfolio/audit_invalidation_count.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/portfolio/build_joint_sim_manifest.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/portfolio/economic_strategy_clustering.py` | 6 | 0 | 0 | hardcoded literal:5, DB constraint/query:1 |
| `tools/strategy_farm/portfolio/ftmo_q09_admission.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/portfolio/portfolio_admission.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/portfolio/swap_scenario.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/schemas/mnt_closure_drift_report_v1.schema.json` | 6 | 0 | 0 | manifest/schema/contract:6 |
| `tools/strategy_farm/tests/test_opt_census.py` | 6 | 0 | 0 | hardcoded literal:4, DB constraint/query:2 |
| `tools/strategy_farm/tests/test_q09_news_migration_v2.py` | 6 | 0 | 0 | hardcoded literal:6 |
| `tools/strategy_farm/tests/test_q15_freeze_check.py` | 6 | 0 | 0 | hardcoded literal:4, DB constraint/query:2 |
| `tools/strategy_farm/classify_summary_missing.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/factory_watchdog.ps1` | 5 | 0 | 0 | hardcoded literal (ps1):5 |
| `tools/strategy_farm/ftmo_admission_census.py` | 5 | 0 | 0 | hardcoded literal:4, DB constraint/query:1 |
| `tools/strategy_farm/opt_census_select.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/q02_disposition_repair.py` | 5 | 0 | 0 | hardcoded literal:3, DB constraint/query:2 |
| `tools/strategy_farm/q08_recovery_lineage.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/q09_news_contract.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/portfolio/audit_ev_funded_account.py` | 5 | 0 | 0 | hardcoded legacy-P literal:5 |
| `tools/strategy_farm/portfolio/build_11422_preset_FINAL24b.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/portfolio/ftmo_phase1_mae.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/portfolio/ftmo_stream_reconciliation.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/schemas/q08_v3_migration_inventory_v1.schema.json` | 5 | 0 | 0 | manifest/schema/contract:5 |
| `tools/strategy_farm/tests/Test-FactoryProcessScope.ps1` | 5 | 0 | 0 | hardcoded literal (ps1):5 |
| `tools/strategy_farm/tests/test_agent_router.py` | 5 | 0 | 0 | hardcoded literal:4, hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_emit_q16_lineage.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/tests/test_mnt_closure_drift.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/tests/test_p2_p3_profit_filter.py` | 5 | 0 | 0 | hardcoded legacy-P literal:3, DB constraint/query:1, hardcoded literal:1 |
| `tools/strategy_farm/tests/test_q04_durable_evidence_wp57.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/tests/test_q08_v3_migration_inventory.py` | 5 | 0 | 0 | hardcoded literal:3, hardcoded legacy-P literal:2 |
| `tools/strategy_farm/tests/test_requeue_q09_stranded_sleeves.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/tests/test_set_priority_track.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/tests/test_terminal_worker_adoption.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/tests/test_work_item_clean_view.py` | 5 | 0 | 0 | hardcoded literal:5 |
| `tools/strategy_farm/build_q09_include_closure.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/factory_process_scope.ps1` | 4 | 0 | 0 | hardcoded literal (ps1):4 |
| `tools/strategy_farm/prepare_ftmo_book3_q02.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/q08_single_target_requal.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/rebuild_ea_metrics.ps1` | 4 | 0 | 0 | hardcoded literal (ps1):4 |
| `tools/strategy_farm/render_cockpit_v2.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/synth_variants.py` | 4 | 0 | 0 | hardcoded legacy-P literal:3, DB constraint/query:1 |
| `tools/strategy_farm/config/dual_book_manifest.v1.schema.json` | 4 | 0 | 0 | manifest/schema/contract:4 |
| `tools/strategy_farm/portfolio/book_reoptimizer.py` | 4 | 0 | 0 | hardcoded literal:3, DB constraint/query:1 |
| `tools/strategy_farm/portfolio/challenge_campaign.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/portfolio/ftmo_candidate_efficiency.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/portfolio/gen_dxz24_weekend_manifest.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/portfolio/make_challenge_setfiles.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/portfolio/sleeve_correlation.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/portfolio/sleeve_improvement_targets.py` | 4 | 0 | 0 | hardcoded legacy-P literal:2, hardcoded literal:2 |
| `tools/strategy_farm/tests/test_basket_order_helper_static.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_governed_work_item_hold.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_mnt009_010_reconciliation.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_q08_single_target_requal.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_q14_opt_admission.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_repair_stale_preflight.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_repair_transition_visibility.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/tests/test_tester_cache_purge_guard.py` | 4 | 0 | 0 | hardcoded literal:4 |
| `tools/strategy_farm/apply_q06_stress_supersede.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/compare_joint_replay.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/prepare_ftmo_book3_standalone_diagnostic.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/protect_audit_evidence.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/q09_ftmo_recommendation.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/risk_freeze.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/config/pipeline_books_program_status.v1.json` | 3 | 0 | 0 | manifest/schema/contract:3 |
| `tools/strategy_farm/portfolio/build_book_dxz.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/portfolio/prop_challenge_sim.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_agent_router_state_exits.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_apply_ks_vintage_bill.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_apply_q06_stress_supersede.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_enqueue_skips_missing_setfiles.py` | 3 | 0 | 0 | hardcoded legacy-P literal:2, DB constraint/query:1 |
| `tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_index_symbol_dispatch_serialization.py` | 3 | 0 | 0 | hardcoded legacy-P literal:3 |
| `tools/strategy_farm/tests/test_maintenance_control.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_mnt016_q08_rescue_invalid_surface.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_prepare_ftmo_book3_standalone_diagnostic.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_q02_disposition_repair.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_q08_recovery_lineage.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_q09_ftmo_recommendation_surface.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_reclassify_defective_binary_work_items.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_strategy_card_v3.py` | 3 | 0 | 0 | hardcoded literal:3 |
| `tools/strategy_farm/tests/test_zero_trade_prevention.py` | 3 | 0 | 0 | hardcoded legacy-P literal:2, hardcoded literal:1 |
| `tools/strategy_farm/apply_ks_vintage_bill.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/audit_g_corpus_dependencies.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/audit_q08_book_setfiles.py` | 2 | 0 | 0 | hardcoded literal:1, DB constraint/query:1 |
| `tools/strategy_farm/defect_block_taint_view.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/install_portfolio_report_scheduled_task.ps1` | 2 | 0 | 0 | hardcoded literal (ps1):2 |
| `tools/strategy_farm/public_snapshot_incident_guard.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/q09_autoseal_hold_census.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/q09_news_calendar.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/research_matrix.py` | 2 | 0 | 0 | hardcoded literal:1, DB constraint/query:1 |
| `tools/strategy_farm/saturday_presunday_check.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/wsf_production_snapshot.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/portfolio/challenge_single_account.py` | 2 | 0 | 0 | hardcoded legacy-P literal:2 |
| `tools/strategy_farm/portfolio/dxz_live_blend_reweight.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/portfolio/gen_dxz_final_manifest.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/portfolio/marginal_contribution_eval.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/portfolio/portfolio_assemble.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/portfolio/recompute_runner_alone_baseline.py` | 2 | 0 | 0 | hardcoded legacy-P literal:2 |
| `tools/strategy_farm/schemas/mnt_adjudication_overlay_event_v1.schema.json` | 2 | 0 | 0 | manifest/schema/contract:2 |
| `tools/strategy_farm/schemas/q08_v3_migration_plan_v1.schema.json` | 2 | 0 | 0 | manifest/schema/contract:2 |
| `tools/strategy_farm/tests/test_classify_recovery_pending.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_compile_work_items.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_dual_book_builders.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_farmctl_scope_audit_isolation.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_ftmo_book3_q02_dispatch.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_news_calendar_claim_gate.py` | 2 | 0 | 0 | hardcoded legacy-P literal:2 |
| `tools/strategy_farm/tests/test_portfolio_admission.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_q04_pf_plausibility_reclassify.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_q07_zero_seed_outlier_reclassify.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_qm5_12580_q08_runtime.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_reboot_diagnostic_mail.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_repair_r11_utility_phase_exemption.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_research_backlog_inventory.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/tests/test_unenqueued_ea_filter.py` | 2 | 0 | 0 | hardcoded literal:2 |
| `tools/strategy_farm/analyze_ftmo_costs.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/compile_ea.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/dxz_target_binary_repro_gate.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/ftmo_book3_fidelity_gate.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/install_reconcile_orphans_scheduled_task.ps1` | 1 | 0 | 0 | hardcoded literal (ps1):1 |
| `tools/strategy_farm/mailbox_source_intake.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/poison_pill_quarantine.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/q12_optimize_runner.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/qm_tasks.manifest.ps1` | 1 | 0 | 0 | hardcoded literal (ps1):1 |
| `tools/strategy_farm/reclaim_busy_agent_temp.ps1` | 1 | 0 | 0 | hardcoded literal (ps1):1 |
| `tools/strategy_farm/reclassify_defective_binary_work_items.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/reconcile_terminal_work_items.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/rollback_ftmo_book3_q02_generation.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/run_agent_orchestration_task.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/strategy_priority.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/target_outcome_dossier.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/validate_symbol_scope.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/config/opt_card.v1.schema.json` | 1 | 0 | 0 | manifest/schema/contract:1 |
| `tools/strategy_farm/config/opt_card_freeze.v1.schema.json` | 1 | 0 | 0 | manifest/schema/contract:1 |
| `tools/strategy_farm/config/opt_dev_sweep.v1.schema.json` | 1 | 0 | 0 | manifest/schema/contract:1 |
| `tools/strategy_farm/config/q15_default_off_equivalence.v1.schema.json` | 1 | 0 | 0 | manifest/schema/contract:1 |
| `tools/strategy_farm/portfolio/audit_activity_marginal.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/portfolio/ftmo_clean_book_sim.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/portfolio/ftmo_timebox_eval.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/portfolio/portfolio_correlation.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/portfolio/portfolio_freeze_gate.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/portfolio/portfolio_live_forward_from_logs.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/portfolio/portfolio_montecarlo.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/portfolio/prop_challenge_optimizer.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_audit_q08_book_setfiles.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_build_backlog_dedup.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_build_q02_exclusion_preflight.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_canonical_checkout_guard.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_commit_reservation_decay.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_defect_block_cohort_marker.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_drain_backlog.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_dwx_history_range_filter.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_dxz_live_blend_reweight.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_ea_id_retirement.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_economic_strategy_clustering.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_event_deduplication.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_evidence_cohort_watch.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_factory_off_build_interlock.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_ftmo_book3_fidelity_gate.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_ftmo_book3_standalone_evaluator.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_ftmo_phase1_mae.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_ftmo_q09_admission.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_fx_basket_manifests.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_health_pending_artifact_binding_drift.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_index_tick_reservation.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_mnt009_infra_fail_evidence_binding.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_mnt038_canary_fanout.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_mt5_feed_depth.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_p4_fold_dispatcher.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_phase_verdict_profit_check.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `tools/strategy_farm/tests/test_poison_pill_quarantine.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_portfolio_admission_dl083_gate.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_portfolio_periodic_report.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_prepare_ftmo_book3_q02.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_q02_evidence_binding.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_q08_aggregate_identity_wp57.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_q08_full_lifecycle_money_producer.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_q08_v3_migration_plan.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_q09_autoseal_hold_census.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_qm5_20181_ftmo_evidence_v2_static.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_render_cockpit_pipeline_books.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_review_repair.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_revive_r11_compile_ea.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_risk_freeze_prevention.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_rollback_ftmo_book3_q02_generation.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_setfile_canonicalization.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_smoke_timeout_override.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_swap_scenario.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py` | 1 | 0 | 0 | hardcoded literal:1 |
| `tools/strategy_farm/tests/test_ws0_notifier.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `scripts/install_pipeline_state_scheduled_task.ps1` | 1 | 0 | 0 | hardcoded literal (ps1):1 |
| `scripts/.tmp/kill_loops.py` | 1 | 0 | 0 | hardcoded legacy-P literal:1 |
| `scripts/ops/qua782_resume_if_ready.ps1` | 1 | 0 | 0 | hardcoded literal (ps1):1 |

## 3 - Critical hardcoded surfaces (must edit for renumbering) - with file:line

### 3.1 Enforced DB CHECK constraint (the only real gate enum in the schema)
- `tools/strategy_farm/q09_news_schema.py:191-196` - `work_item_dependencies.dependency_role IN ('Q08_INPUT','Q09_NEWS','Q09_PORTFOLIO','PARENT_LINEAGE','CHALLENGER_Q10','Q14_ADMISSION')`. **Hard CHECK constraint embedding gate ids; renumber => schema migration required.**
- `tools/strategy_farm/farmctl.py:1589` - `work_items.phase TEXT NOT NULL` has **NO CHECK enum** (comment `-- 'P2','P3',etc.` is stale). Free-text column: no constraint migration, but the stale comment and all literal `phase IN (...)` queries below are couplings.

### 3.2 Legacy P-key arrays hardcoded in PowerShell (public snapshot contract)
- `scripts/export_public_snapshot.ps1:84` and `:253` - `@('G0','P1','P2','P3','P3_5','P4','P5','P5b','P5c','P6','P7','P8','P9','P9b','P10')` validated + used for phase-order label. **Pure legacy-P, no manifest link - must be rewritten or retired.**

### 3.3 legacy-P compat map in the public-state builder
- `scripts/build_pipeline_state.py:381` - `'Q09_PORTFOLIO':'Q11'` mapping + by_phase P* compat keys (`:353`,`:381`). Feeds `public-data`. Hardcoded, not manifest-resolved.
- `scripts/qm_pipeline_summary.py` - 21 legacy-P literals (all hardcoded).

### 3.4 JSON contracts / schemas embedding gate ids
- `public-data/public-snapshot.schema.json` (24), `public-data/public-snapshot.json` (13) - by_phase keys.
- `tools/strategy_farm/schemas/gate_manifest.v3.schema.json` (44), `.v2.schema.json` (23) - `canonical_id_pattern` regex + enum of ids.
- `tools/strategy_farm/config/gate_manifest.v1/v2/v3.json` - the manifests themselves (v1/v2 are frozen fixtures; only v3 is live).

### 3.5 High-density hardcoded logic modules (no manifest import)
- `tools/strategy_farm/q09_news_runner.py` (190), `q09_news_schema.py` (89) - Q09_NEWS pipeline literals throughout.
- `tools/strategy_farm/health.py` (99), `ea_metrics.py` (70; `PHASE_ORDER` list literal :48-49), `analyze_q04_survivor_cohort.py` (`PHASE_ORDER=[...]` :35), `analyze_mistested_ea_rescue_queue.py` (phase-rank map).
- `tools/strategy_farm/q10_confirmation_contract.py` (29), `portfolio/portfolio_q08_contribution.py` (29), `optimization_dashboard_status.py` (25), `opt_census.py`.
- `tools/strategy_farm/farmctl.py` - 836 tokens (582 literal, 201 legacy-P, 53 SQL). Largest single coupling: `PHASE_ORDER`-like frozensets (:282,:287), `Q09_PORTFOLIO_MIN_TRADES` (:316), sort-order `WHEN 'Q09_PORTFOLIO'` (:1279), dep-role literals (:15211,:15568,:15578), and dozens of `phase IN ('Q02','P2')` UNION-read queries. It *imports* the resolver for display but its pipeline logic is literal-driven.

### 3.6 Test fixtures pinning gate ids
- 144 test files, 1370 literals total (e.g. `test_farmctl_cascade.py` 97, `test_candidate_repair_enqueue.py` 90, `test_gate_manifest.py` 79, `test_cascade_chain_p2_to_p8.py` all legacy-P). These encode the *current* contract and are the fail-closed guardrails the directive sec.7.5 requires; they must be updated in lockstep with any renumber.

## 4 - Documentation & vault (file-level; enumerate, do not renumber in code)

`docs/**/*.md`: 2213 files reference gate ids (1946 under `docs/ops`, 265 under `docs/research`). These are dated evidence/runbooks - immutable per Source-of-Truth order; a renumber adds new dated docs, it does not rewrite history.

**Vault `03 Pipeline`** (21 pages with gate ids):
- `03 Pipeline/Q03 Parameter Sweep.md`
- `03 Pipeline/Q05 Gross Full-History Robustness.md`
- `03 Pipeline/Q06 Stress HARSH.md`
- `03 Pipeline/Q07 Multi-Seed.md`
- `03 Pipeline/Q08 Davey Statistical Validation.md`
- `03 Pipeline/Q10 Full-History Confirmation.md`
- `03 Pipeline/Q12 Operational Readiness.md`
- `03 Pipeline/Q13 Live Burn-In DXZ.md`
- `03 Pipeline/Q00 Research Intake.md`
- `03 Pipeline/Q02 Baseline Screening.md`
- `03 Pipeline/Q01 Build & Spec.md`
- `03 Pipeline/Q04 Walk-Forward + Commission.md`
- `03 Pipeline/Q11 Portfolio Construction.md`
- `03 Pipeline/Pipeline Overview.md`
- `03 Pipeline/Q09 News Impact Mode.md`
- `03 Pipeline/Q14 Optimization Admission.md`
- `03 Pipeline/Q15 Challenger Build and Freeze.md`
- `03 Pipeline/Q16 Head-to-Head Requalification.md`
- `03 Pipeline/Pipeline Operations Workflow.md`
- `03 Pipeline/Gate Manifest v3 Diff.md`
- `03 Pipeline/Pipeline Rebaseline Directive 2026-08-23.md`

**Vault `08 Current State`** (6 pages with gate ids):
- `08 Current State/Mission Baseline.md`
- `08 Current State/Current Operating State.md`
- `08 Current State/Current Objective.md`
- `08 Current State/FTMO Hindernisse-Analyse 2026-08-16 (Import).md`
- `08 Current State/Heartbeat.md`
- `08 Current State/Strategischer Fahrplan FTMO Payout und DXZ Allocation 2026-08-22.md`

**Vault `12 ToDo`** (19 pages with gate ids):
- `12 ToDo/_INDEX.md`
- `12 ToDo/01_Prozesse_Datenbanken_Wissensquellen.md`
- `12 ToDo/03_Mission_Control_Cockpit.md`
- `12 ToDo/04_Website.md`
- `12 ToDo/05_MQL5_EA_Productisierung.md`
- `12 ToDo/02_Vault_Ueberarbeitung.md`
- `12 ToDo/00_CEO_Masterplan_2026-08-21.md`
- `12 ToDo/AI ToDos/Codex.md`
- `12 ToDo/07_FTMO_Kampagne.md`
- `12 ToDo/08_DXZ_Live_Book.md`
- `12 ToDo/AI ToDos/Claude.md`
- `12 ToDo/09_Research_Sourcing.md`
- `12 ToDo/10_Pipeline_Leerlauf.md`
- `12 ToDo/AI ToDos/OWNER.md`
- `12 ToDo/AI ToDos/Archive/Entscheidungen 2026-08-21.md`
- `12 ToDo/11_Systemanalyse_2026-08-22.md`
- `12 ToDo/AI ToDos/OWNER Videoanalysen.md`
- `12 ToDo/AI ToDos/Archive/Entscheidungen 2026-08-22.md`
- `12 ToDo/13_Schienenplan_2026-08-22.md`

The `03 Pipeline` gate pages (`Q00..Q16 *.md`) are the human-facing per-gate specs - the primary vault surface a renumber must re-title (OWNER-owned; not edited by this task).

## 5 - Bottom line for the renumber

1. **One safe edit point for names/order:** `gate_manifest.v3.json` + `gate_manifest.py`/`phase_ids.py`. Display everywhere that uses `phase_label()`/`PHASE_NAME` follows for free.
2. **Hard couplings that must be edited by hand:** the `dependency_role` CHECK constraint (`q09_news_schema.py:191`), the legacy-P arrays in `export_public_snapshot.ps1`, the P->Q compat map in `build_pipeline_state.py`, the JSON schemas/contracts under `public-data/` and `schemas/`, and the literal `phase IN (...)` / `if phase==` logic in `farmctl.py`, `q09_news_runner.py`, `health.py`, `ea_metrics.py`, and the portfolio/analyze modules.
3. **Legacy P* keys are still live in three storage/contract paths** (`export_public_snapshot.ps1`, `build_pipeline_state.py`, `public-snapshot.schema.json`) plus dozens of `('Q02','P2')` UNION-reads - these are the migration-compat surface the directive keeps via `gate_contract_version`; readable but must not silently take new semantics.
4. **No enforced enum on `work_items.phase`** - renumber does not require a `work_items` table migration, only `work_item_dependencies.dependency_role`.
5. **Tests are the fail-closed guard** (sec.7.5): 144 test files pin the current ids; update them with the contract to keep hole-skipping / sub-25 book-build fail-closed.