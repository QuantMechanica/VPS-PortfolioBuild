# Phase Chain Build Plan — 2026-05-19

**Status:** Planning, build kicked off 2026-05-19
**Owner:** Board Advisor + OWNER
**Goal:** Replace stub phase runners (PENDING_IMPLEMENTATION) with real fold/scenario generators + dispatchers + aggregators so the pipeline can actually grade EAs against spec.

## Problem Statement

Per audit 2026-05-19: cascade-patch (`ced8925f`) routes work_items to phase runners (P3.5/P4/P5/P5b/P5c/P6/P7/P8), but those runners are **verdict-evaluators that consume CSV inputs nobody produces**:

- `p35_csr_runner.py --baseline-csv ... --csr-results-csv ...` → no producer
- `p4_walk_forward.py --walk-forward-csv ...` → no producer
- `p5_stress_driver.py --calibration-json ...` (slippage/latency model) → no producer
- `p7_statval.py --sweep-pass-rows ... --multiseed-rows ...` → first arg has no producer
- `p8_news_driver.py --news-matrix ...` → no file on disk

Without input CSVs, every runner returns `verdict='PENDING_IMPLEMENTATION'`. Pipeline practical depth = P3.

## Per-Phase Template (apply to each)

| Letter | Component | Responsibility |
|---|---|---|
| A | **Scenario Generator** | Produce fold spec / seed list / scenario list / news matrix |
| B | **Run Dispatcher** | For each scenario, spawn `run_smoke.ps1` with mutated setfile/window |
| C | **Aggregator** | Collect per-scenario `summary.json` → CSV in format expected by runner |
| D | **Wire** | `_phase_runner_cmd_for_work_item` calls A+B+C before the runner |
| E | **Tests** | Mock scenarios, assert CSV shape + verdict logic |

## Build Order (most critical first)

### 1. P4 Walk-Forward (1-2 days)
**Why first:** Goal-acceptance criterion ("WF 2023-2025 OOS Sharpe ≥0.6, Trades ≥30") requires P4. P5/P5b also need P4's calibration output.

Components:
- A: `p4_fold_generator.py` — emit anchored folds: train windows 2017-`year`, OOS = next 6 months, until 2025-12-31. Min 6 folds. Regime labels via simple trend/range heuristic on benchmark symbol. **DONE** commit `73366a4b` (regime classifier stubbed as `UNCLASSIFIED`, separate sub-component step 1A-2)
- B: `p4_fold_dispatcher.py` — for each fold, call `run_smoke.ps1 -FromDate <oos_start> -ToDate <oos_end> -SetFile <orig>`. Parallel where terminal capacity allows.
- C: `p4_fold_aggregator.py` — read per-fold summary.json → walk_forward.csv with columns: `ea_id,phase,fold_id,regime,dev_start,dev_end,oos_start,oos_end,verdict,trades,pf,sharpe,max_dd,net_profit`
- D: `_phase_runner_cmd_for_work_item` P4 branch: run A → B → C → then call existing `p4_walk_forward.py --walk-forward-csv <C output>`
- E: `tests/test_p4_fold_pipeline.py`

**Lesson from 2026-05-19 Codex session pattern**: Codex `exec` spent 80% tokens on exploration/planning, ran out before writing. **Directive prompts with full code skeleton** (like `bv1s2o2qr`) work much better — Codex just writes + tests + commits in one short session. Apply this pattern for B/C/D/E too.

### 2. P3.5 Cross-Sectional Robustness (1 day)
**Why second:** Should run before P4 per spec order. Plus simpler logic.

Components:
- A: `p35_csr_generator.py` — list orthogonal symbol classes (FX major / FX cross / Index / Metal / Energy / Crypto if applicable) covering ≥3 classes
- B: `p35_csr_dispatcher.py` — run_smoke per symbol with shared setfile, IS window 2017-2022
- C: `p35_csr_aggregator.py` — write baseline.csv (single original) + csr_results.csv (per-symbol)
- D + E: wire + tests

### 3. P5 Calibration Extractor + Stress (1-2 days)
**Components needed beyond what exists:**
- A: `p5_calibration_extractor.py` — read P4 fold trade fills, compute per-symbol commission proxy (from spread+slippage observed), p95 spread, slippage histogram. Output `calibration.json`.
- B+C: already in `p5_stress_driver.py` (it dispatches its own clean+stress runs)
- D + E: wire

### 4. P5b Calibrated Noise (0.5 day)
- A: minimal — uses calibration.json from P5
- B/C/D: `p5b_noise_driver.py` already produces `p5b_trials.csv`; only wiring needs verification

### 5. P5c Crisis Slices (1 day, OPTIONAL per spec)
- A: `p5c_slices_generator.py` — emit slices.csv with named crisis windows (2008-09, 2015-08, 2020-03, etc.)
- B: dispatcher runs `run_smoke.ps1` per slice
- C: `p5c_aggregator.py` — collect into format `p5c_crisis_slices.py` expects

### 6. P6 Multi-Seed (verify only — already mostly wired)
- A+B: `p6_multiseed_driver.py` runs N-seed via existing mock-or-real path
- C: writes `p6_seeds.csv` ✅
- Verify P6 runs end-to-end with real seeds, no mock path

### 7. P7 Statistical Validation (1-2 days)
**Needs prerequisites:**
- P3 must write `sweep_pass_rows.csv` (currently writes `report.csv` — patch to also emit pass-filtered subset)
- P6 must write `p6_seeds.csv` ✅ already
- Then `p7_statval.py` consumes both — already works
- D + E: wire

### 8. P8 News Impact (1-2 days)
- A: `p8_news_matrix_generator.py` — read `D:/QM/data/news_calendar/*.csv`, emit `news_matrix.csv` with columns per spec (`symbol,date_utc,event,impact,profile_applied`)
- B+C: `p8_news_driver.py` already runs 7 modes
- D + E: wire

## Cross-Cutting Concerns

### Path Bug: P3.5 vs P3_5
- `p35_csr_runner.py:47` uses `out_dir = ... / "P3_5"` (underscore)
- `_ea_phase_dir(ea_id, 'P3.5')` returns `... / 'P3.5'` (dot)
- Fix: align both to `phase.replace('.', '_')` convention OR change `_phase_runner_inputs` lookup. **Apply early.**

### Token Budget Per Codex Session
- ≤200k tokens per session
- One component (A or B or C) per commit
- Tests + docs in same commit as the component they exercise
- Multi-component commits prone to half-finish (yesterday's lesson 3x)

### Test Strategy
- Each new script gets unit tests
- Integration test per phase: mock scenarios → assert verdict
- End-to-end test only after all 8 phases wired

### Operational Coordination
- Phase dispatchers (B) compete with terminal_worker daemons for T1-T5 slots — needs `-AllowRunningTerminal` flag OR pump-coordination so phase dispatchers can pause workers temporarily
- Or: dispatch via worker daemons themselves (work_item type = `phase_subrun` with parent_phase reference)

## Done Definition

- All 8 phases produce real CSV inputs to existing runners
- Pipeline runs P2 → P3 → P3.5 → P4 → P5 → P5b → P5c → P6 → P7 → P8 end-to-end without PENDING_IMPLEMENTATION
- ≥1 EA reaches P8 with honest verdict (PASS or FAIL on real evidence)
- Roadmap closure: `docs/ops/PHASE_CHAIN_BUILD_RESULT_<date>.md` summarizing what worked + what's stubbed (e.g. regime labels via heuristic = stub)

## Tracking

Each Codex commit references this plan: `feat(p4): fold generator (PHASE_CHAIN_BUILD_PLAN_2026-05-19 step 1A)`.
