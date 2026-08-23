# rb-advancement — centralized gate advancement evidence

Date: 2026-08-23
Ticket: `rb-advancement` / proposal ticket 1
Scope: centralize active v3 gate advancement without renumbering or changing gate criteria.

## Result

PASS. Runtime phase topology now comes from one immutable table built from the active gate manifest's `PHASE_ORDER`, `ORDINARY_PHASE_ORDER`, and `PHASE_NEXT`. The table contains explicit v3 storage handling for `Q09_NEWS` / `Q09_PORTFOLIO` and historical legacy-P storage topology. No manifest number, threshold, verdict criterion, queue row, verdict row, factory state, or live terminal state was changed.

## What changed

- `tools/strategy_farm/phase_ids.py:97` defines the immutable `PhaseAdvancement` row and builds the single runtime table from the loaded manifest. The mandatory and lane-inclusive runtime orders are exposed at `:243` and `:247`; public `advancement_table()`, `next_phase()`, `prev_phase()`, and `phase_rank()` are at `:261`, `:274`, `:280`, and `:286`.
- `tools/strategy_farm/farmctl.py:307-326` derives `SUPPORTED_BACKTEST_PHASES`, `CASCADE_BACKTEST_PHASES`, and `REAL_PHASE_RUNNER_PHASES`; `:1272` generates the former SQL phase-rank CASE; `:10079` derives `PARENT_PROGRESSION_MAP`; `:17892` derives the pump successor walk; `:21763` resolves exact-enqueue predecessors; `:22670` resolves `dispatch_tick` successors.
- `tools/strategy_farm/evidence_cascade_driver.py:46` derives its strict phase walk. It now walks `Q08 -> Q09_NEWS -> Q10` and cannot skip Q09.
- `tools/strategy_farm/terminal_worker.py:51` derives the exact early runner phase/primary-alias set. `P3.5` remains excluded from the early `P2/P3` smoke path.
- `tools/strategy_farm/sweep_enqueue_built_eas.py:123` derives the stranded-INFRA phase set and uses central ranks/alias reads.
- `tools/strategy_farm/invalidate_unprofitable_cascade.py:29` derives the historical legacy cascade set.
- `tools/strategy_farm/repair.py:122` derives the canonical-plus-legacy Q02 UNION-read keys used by R18/R12.
- `tools/strategy_farm/r_eval_drain.py` was audited and had no gate advancement map/set to replace; it remains unchanged.
- `tools/strategy_farm/tests/test_advancement_centralization.py:37-216` freezes the former maps/ranks, proves Q09 is present, performs the fixture-DB dry-run comparison, and statically rejects new literal phase-to-phase dicts in the listed consumers. The only allowlisted literal phase map is `farmctl.PHASE_NOMENCLATURE`, which maps retired runner semantics and does not select successors.

## Dispatch successor blast-radius proof

The pre-ticket routes were copied from the original literal `PARENT_PROGRESSION_MAP`, pump `cascade_phase_map`, and `dispatch_tick.next_phase_map`. `test_dispatch_successors_match_pre_ticket_fixture_db` writes only a temporary SQLite fixture, reads each frozen predecessor, resolves it through the new table, and asserts byte-for-byte equality. It does not open the production state DB.

| Predecessor | Before | After |
|---|---|---|
| Q02 | Q03 | Q03 |
| Q03 | Q04 | Q04 |
| Q04 | Q05 | Q05 |
| Q05 | Q06 | Q06 |
| Q06 | Q07 | Q07 |
| Q07 | Q08 | Q08 |
| Q08 | Q09_NEWS | Q09_NEWS |
| Q09_NEWS | Q10 | Q10 |
| P2 | P3 | P3 |
| P3 | P3.5 | P3.5 |
| P3.5 | P4 | P4 |

Additional frozen compatibility assertions cover the complete former cascade phase set, real-runner set, predecessor table (including the established Q04 two-hop default-probe exception), legacy invalidation phases, and all former SQL queue ranks.

## Verification

Pre-change baseline:

```text
python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_cascade_chain_p2_to_p8.py tools/strategy_farm/tests/test_candidate_repair_enqueue.py tools/strategy_farm/tests/test_gate_manifest.py
90 passed, 1 skipped, 6 subtests passed in 104.16s
```

Final requested suite plus ticket guard:

```text
python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_cascade_chain_p2_to_p8.py tools/strategy_farm/tests/test_candidate_repair_enqueue.py tools/strategy_farm/tests/test_gate_manifest.py tools/strategy_farm/tests/test_advancement_centralization.py
95 passed, 1 skipped, 6 subtests passed in 105.13s
```

Touched-consumer and queue-ordering suite:

```text
python -m pytest -q tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py tools/strategy_farm/tests/test_repair_transition_visibility.py tools/strategy_farm/tests/test_repair_stale_preflight.py tools/strategy_farm/tests/test_repair_r11_utility_phase_exemption.py tools/strategy_farm/tests/test_review_repair.py tools/strategy_farm/tests/test_terminal_worker_adoption.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py tools/strategy_farm/tests/test_terminal_worker_identity.py tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py tools/strategy_farm/tests/test_opt_census_dispatch.py tools/strategy_farm/tests/test_ultracode_wsa_claim.py tools/strategy_farm/tests/test_pipeline_view_work_items.py tools/strategy_farm/tests/test_phase_runner_process_lineage.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py
238 passed, 4 subtests passed in 72.72s
```

Post-adjustment manifest/centralization check:

```text
python -m pytest -q tools/strategy_farm/tests/test_advancement_centralization.py tools/strategy_farm/tests/test_gate_manifest.py
21 passed, 1 skipped in 1.92s
```

Static/syntax checks:

```text
python -m py_compile tools/strategy_farm/phase_ids.py tools/strategy_farm/farmctl.py tools/strategy_farm/evidence_cascade_driver.py tools/strategy_farm/terminal_worker.py tools/strategy_farm/sweep_enqueue_built_eas.py tools/strategy_farm/invalidate_unprofitable_cascade.py tools/strategy_farm/repair.py tools/strategy_farm/tests/test_advancement_centralization.py
PASS (no output)

git diff --check
PASS (no whitespace errors; Git emitted only existing checkout line-ending normalization warnings)
```

## Safety / state evidence

- Production DB `D:/QM/strategy_farm/state/farm_state.sqlite` was not opened or mutated. The compatibility DB is pytest's temporary SQLite fixture only.
- No backtest was enqueued/deleted, no verdict was written/overwritten, and no factory flag/process was changed.
- `C:/QM/mt5/T_Live` was not accessed.
- Active manifest remains v3; `tools/strategy_farm/config/gate_manifest.v3.json` is unchanged.
- Gate thresholds, criteria, windows, and verdict policy are unchanged.

## Risks and rollback

Residual risk is limited to future consumers bypassing `phase_ids`; the static source guard covers every consumer named in this ticket and fails on new literal phase-to-phase dicts. The split Q09 lane and non-invertible legacy aliases remain explicit by design so a future manifest activation must update one central override rather than multiple runtimes.

Rollback: revert the commit containing this evidence file. This restores the previous literal runtime tables and removes the tests; no database, queue, verdict, factory, or live-state rollback is required.
