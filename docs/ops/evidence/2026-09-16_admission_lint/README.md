# Admission lint — Q08 empty-strategy-params pre-enqueue guard

- Date: 2026-09-16
- Task: `admission-lint` (OWNER-delegated D1 failure-concentration follow-up;
  analysis: `docs/ops/evidence/2026-09-16_d1_failure_analysis/ANALYSIS.md` §3–§4)
- Preflight: `agent_worktree_preflight.py` PASS (branch `agents/board-advisor`, no collisions)
- Companion: `BACKLOG_10280.md` (QM5_10280 park + staged backfill ticket)

## Change

`tools/strategy_farm/farmctl.py`

1. `_q08_baseline_setfile_admission(setfile_path, symbol)` (new helper beside
   `_q02_strategy_params_contract`, farmctl.py:28165) — parses the bound baseline
   setfile with the house `_setfile_semantic_parameters` parser and fails closed
   when it carries zero `strategy_*` params. Escape hatch (documented, matches
   observed runner behavior): an explicit ablation-setfile marker admits the
   enqueue — either the bound setfile is itself `*_ablation_*`, or a same-symbol
   `*_ablation_*.set` sibling exists in the sets dir (the aggregate baseline
   resolver's known fallback, e.g. QM5_10804 GDAXI.DWX H1, whose bound setfile
   IS `..._backtest_ablation_00.set` with 7 params). Missing files defer to the
   pre-existing `missing_setfile` skip; unparseable files defer to the sweep
   triage class (duplicate/empty-value grammar) — no behavior change there.
2. `enqueue_cascade_backtest_for_ea` (farmctl.py:32191) — for `phase == "Q08"`,
   the per-predecessor loop now refuses admission with reason
   `SETFILE_EMPTY_STRATEGY_PARAMS` when the check fails. Covers fresh enqueues,
   in-place requeues, and append-only reruns (single point before all three
   branches). Intake admission only — no gate calibration touched.

## Why

8 of 13 executed V3 Q08 rows carried `empty_strategy_params` setfiles
(`; card_defaults_source=not_found`); QM5_10211 INVALIDed at §8.5 because the
neighborhood runner raises `baseline setfile has no strategy parameters` on every
run, and §8.7 then INVALIDs (`insufficient_distinct_configs`). The pending
QM5_10280 row would have burned a full-window run the same way — parked the same
day (see BACKLOG_10280.md). This guard stops the recurrence at intake.

## Tests

`tools/strategy_farm/tests/test_q08_setfile_empty_strategy_params_admission.py`
— 9 hermetic tests (temp dirs/DBs only): 7 helper-level (empty→refuse,
params→admit, same-symbol ablation sibling→admit, other-symbol sibling→refuse,
ablation-bound→admit, missing→defer, parse-error→defer) + 2 cascade-enqueue
end-to-end (empty→skipped with `SETFILE_EMPTY_STRATEGY_PARAMS`, params→created).
All 9 pass.

## Regression proof (subset run 2026-09-16)

- compile_work_items / enqueue / lineage subset (8 files): 670 passed, 2 failed —
  both pre-existing, reproduce identically with the farmctl.py change stashed:
  `test_compile_work_items.py::test_compile_profile_stdlib_failure_is_persisted_as_infra_not_compile_fail`
  (live-DB SH-3 taxonomy constraint: "apply the governed schema migration first")
  and `test_compile_backlog_authorities.py::test_framework_input_pin_wave2_registration_is_exact_and_hash_bound`.
- Q08/cascade/NEWS/Q10 enqueue subset (6 files): 113 passed, 1 failed —
  `test_v4_runtime_wiring.py::test_no_runtime_auto_portfolio_enqueue_and_readiness_is_green`,
  also reproduces with the change stashed (pre-existing, environment-dependent).

## Known asymmetry (documented, not changed)

`sweep_enqueue_built_eas.py` part-2 Q08 re-enqueue guard
(`_q08_setfile_deterministic_defect`) refuses ALL empty-param setfiles without
the ablation hatch. It errs fail-closed, so no doomed run can slip through; the
two paths may disagree only on the rare empty-baseline+rescue-ablation class,
which the enqueue path admits and the sweep would park for triage. Left as-is
deliberately: the sweep's scope is stranded-INFRA retry, not fresh admission.
