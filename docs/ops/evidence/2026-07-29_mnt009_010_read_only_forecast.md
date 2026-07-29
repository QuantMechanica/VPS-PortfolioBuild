# MNT-009 → MNT-010 read-only reconciliation forecast

**Generated:** 2026-07-29 · **Forecast mutation:** none · **Factory:** OFF

> This is the immutable pre-apply forecast. The exact manifest was
> subsequently applied at `2026-07-29T12:18:03Z`; see
> `2026-07-29_mnt009_010_reconciliation_apply.md` and the machine-readable
> apply receipt. Factory remained OFF.

## Exact bindings

- Database: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Database main-file SHA-256: `3f77860fa3962c85ae1c3e4257163044d3322301e9f2b598a9a25491853f1831`
- Database serialized/logical SHA-256: `3f77860fa3962c85ae1c3e4257163044d3322301e9f2b598a9a25491853f1831`
- FACTORY_OFF SHA-256: `09cc4f83e8d5f384f03bc51306beff2cdd165108559a00dbf665097c60b47f1c`
- Plan ID: `cb494c756acd3a7f9378acf9b6b209f74b06b1960684cd0ce2c5584344c8b713`
- Plan manifest: `docs/ops/evidence/2026-07-29_mnt009_010_reconciliation_plan.json`
- Manifest size: `2,173,303` bytes
- Manifest byte SHA-256: `f5249c4cba64bcd6c03b668533fd2eb1d8b81e819c851ee7a6b0ffcde26624b2`

The manifest was loaded again through the duplicate-key-rejecting validator after
publication. Any database, flag, artifact, or manifest-byte drift invalidates APPLY.

## Forecast

- Terminal rows with `verdict IS NULL`: **832**.
  - **804** → `failed / INFRA_FAIL`, exact NDX repair-park reasons.
  - **27** → `done / SUPERSEDED_BY_LOGICAL_BASKET`, exact logical-basket replacement reason.
  - **1** → `done / RETIRE`, exact OWNER-approved USDJPY-only admission reason.
  - Unknown reasons: **0**; classification is exact-string and fail-closed.
- Current `INFRA_FAIL`/`INVALID` rows without `evidence_path`: **46,040**.
  The NULL migration adds **798** previously unbound INFRA dispositions (six other
  parked rows already have an evidence path), for a projected corpus of **46,838**.
  - Existing and lineage-valid artifact bindings planned: **1,005** (`524 report_root`,
    `459 log_path`, `22 archived_report_root_on_requeue`); **18** are bound atomically
    inside their NULL-disposition transition.
  - Deliberately left unbound: **45,833**. No artifact or test evidence is invented.
- Physically terminal parent zombies: **43**.
  - Predicted closure: **13 PASS**, **27 INFRA_FAIL**, **3 STRATEGY_FAIL**.
  - All 13 PASS progressions are written as `DEFERRED_FACTORY_OFF`; APPLY cannot enqueue.

Therefore MNT-009 remains explicitly **PARTIAL** after this safe scope (NULL migration
complete, honest evidence remainder open). MNT-010 is ready for guarded runtime APPLY.

## Source and safety verification

- New focused reconciliation suite: `18 passed`.
- Atomic-claim/terminal-worker/basket adjacent suites: `84 passed`.
- Package/quiescence/maintenance-control adjacent suites: `22 passed`.
- Full `tools/strategy_farm/tests` integration run: `2219 passed, 31 failed,
  25 subtests passed` in `369.63s`.

The 31 integration failures are retained for the root integration fix pass; none failed
in the new MNT-009/MNT-010 tests or reported the new NULL insert/update trigger,
parent CAS, Factory-OFF deferral, manifest validation, or evidence-lineage guard:

1. `test_agent_router.py::AgentRouterTests::test_replenish_pauses_research_when_card_pool_is_sufficient`
2. `test_agent_router.py::AgentRouterTests::test_research_review_card_accepts_relaxed_optional_sections`
3. `test_agent_router.py::AgentRouterTests::test_research_review_card_rejects_duplicate_ea_id`
4. `test_agent_router.py::AgentRouterTests::test_research_review_card_rejects_duplicate_fingerprint`
5. `test_agent_router.py::AgentRouterTests::test_run_once_does_not_replenish_generic_research`
6. `test_cascade_chain_p2_to_p8.py::CascadeChainP2ToP8Tests::test_all_chain_inputs_spawn_expected_phase_drivers`
7. `test_cascade_real_phase_runners.py::CascadeRealPhaseRunnerTests::test_q04_basket_dispatch_uses_host_symbol_and_keeps_logical_label`
8. `test_cascade_real_phase_runners.py::CascadeRealPhaseRunnerTests::test_q04_dispatch_spawns_walk_forward_not_run_smoke`
9. `test_cascade_real_phase_runners.py::CascadeRealPhaseRunnerTests::test_q08_dispatch_bounds_neighborhood_and_passes_baseline_setfile`
10. `test_dwx_history_range_filter.py::DwxHistoryRangeFilterTests::test_p2_enqueue_adjusts_skips_and_leaves_valid_full_window`
11. `test_dxz_10939_repair_packet.py::test_real_spec_hash_bindings_pass`
12. `test_dxz_10939_repair_packet.py::test_complete_three_group_bundle_passes`
13. `test_dxz_12567_xau_repair_packet.py::test_spec_is_hash_bound_blocked_and_xau_not_xng`
14. `test_execution_contract_lint.py::test_dxz23_registry_is_source_bound_and_structurally_clean`
15. `test_execution_contract_lint.py::test_density_execution_contracts_are_source_and_runtime_binding_clean`
16. `test_execution_contract_lint.py::test_20009_ftmo_news_calendar_is_exact_and_evidence_bound`
17. `test_ftmo_13207_t20a_wiring.py::test_only_research_setfiles_exist_and_bind_current_source_hash`
18. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_refuses_ambiguous_ea_dirs_before_creating_task`
19. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_refuses_duplicate_ex5_before_creating_task`
20. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_refuses_missing_ex5_before_creating_task`
21. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_rejects_latest_zero_trade_q01_smoke`
22. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_respects_card_declared_universe`
23. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_skips_existing_pending_work_item`
24. `test_p2_full_dwx_fanout.py::P2UniverseFanoutTests::test_p2_enqueue_skips_unregistered_magic_symbols`
25. `test_p2_p3_profit_filter.py::P2P3ProfitFilterTests::test_p2_to_p3_only_promotes_profitable_symbols`
26. `test_priority_track_new_q02.py::test_force_build_does_not_depend_on_strategy_priority`
27. `test_priority_track_new_q02.py::test_first_q02_is_priority_but_existing_organic_survivor_is_unchanged`
28. `test_q09_news_farmctl_integration.py::test_q09_news_is_writable_canonical_phase_and_q09_alias_is_read_only`
29. `test_registry_rekey_12784.py::test_rekey_preserves_old_binary_but_new_identity_has_no_stale_ex5`
30. `test_registry_rekey_p19.py::test_p19_registry_directory_filename_and_source_ids_agree`
31. `test_setfile_canonicalization.py::SetfileCanonicalizationTests::test_dispatch_persists_spawn_effective_setfile_path`

## Historical APPLY handoff

At forecast time, APPLY additionally required a new, non-existing snapshot path and receipt path. It
re-checks all four hashes under `FACTORY_MUTATION.lock`, takes the snapshot, re-checks
the DB again, applies evidence bindings then NULL dispositions then parent CAS closures
in one transaction, checkpoints the WAL, and emits a receipt. Those checks all passed
for the later guarded apply; any future plan must still be refused and regenerated if
one of its bindings changes.
