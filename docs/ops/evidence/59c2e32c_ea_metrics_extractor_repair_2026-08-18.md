# E-2 ea_metrics extractor repair evidence — 2026-08-18

- Router task: `59c2e32c-33ac-4c24-a836-8fed59bd0533`
- Baseline snapshot: `3472a5d2e1b5`
- Branch: `agents/board-advisor`
- Scope: `tools/strategy_farm/ea_metrics.py` only
- Disposition: implementation complete; leave in `REVIEW`

## Implemented classes and commits

1. A/Q08 — `61cc7d8e3`: map governed `mc_maxdd_p95` / `_pct` to headline drawdown; retain Monte Carlo and as-realized values in detail.
2. A/Q04 — `8b6df0f0b`: open each fold's bound `summary_path` then `source_summary_path`, read `runs[].drawdown` / `drawdown_raw`, retain per-fold values, and headline the maximum fold drawdown. Missing summaries remain `None`.
3. C/Q07 — `5356e7b17`: headline maximum `per_seed_detail[].dd_money`, matching existing percentage aggregation.
4. D — `01273ec1a`: recognize Q09_NEWS/Q14/Q15/Q16 metadata schemas and extend phase ordering; an unrecognized schema still returns `unknown_phase:<phase>`.
5. B — `6ca1e96e4`: no Q05/Q06/Q10 aggregate in the measured readable set emits net/profit/P&L. The extractor now follows the aggregate's exact bound `summary_path`, as the gate does, and reads `runs[-1].net_profit`; missing source/field remains `None` and no proxy is calculated.
6. E — `36f9f59ac`: Sharpe remains `None` for Q04/Q05/Q06/Q07/Q08/Q10 with explicit provenance comments. Only Q09_PORTFOLIO continues to consume an emitted Sharpe value.

## Measured class-B source census

| Phase | readable aggregates | aggregate `net_profit` keys | bound summaries with `runs[-1].net_profit` |
|---|---:|---:|---:|
| Q05 | 649 | 0 | 633 |
| Q06 | 307 | 0 | 303 |
| Q10 | 41 | 0 | 41 |

## Verification

- `python -m py_compile tools/strategy_farm/ea_metrics.py`: PASS.
- Per-class focused unit assertions: PASS, including missing-source-to-`None`, Q04 source-path fallback, nested Q08 fallback, unknown-schema visibility, exact bound-summary net profit, and Sharpe non-synthesis.
- Gate-source stratified sample: 25 Q04 + 25 Q05 + 25 Q07 + 25 Q08 = **100 exact comparisons**, **0 mismatches**. Expected values were read independently from the evidence paths using the gate access pattern, then compared with `extract_one` without numeric tolerance.
- Isolated `--ea QM5_10123` proof: PASS on a temporary SQLite fixture populated from read-only production rows; 874 scanned and 874 upserted. Source counts included `q04_folds=138`, `q05q06_flat=46`, `q07_seeds=12`, and `q08_subgates=15`. The fixture was deleted after verification.
- `python -m pytest -q tools/strategy_farm/tests/test_dashboard_pipeline_books_programme.py`: **10 passed**.
- Target file has no uncommitted changes after the six class commits.

## Guardrails

The production farm database was opened with SQLite `mode=ro` for census and sampling. No production DB build/full extraction was run, and no work item, verdict, or gate threshold was changed. No terminal, T_Live, or AutoTrading action occurred. This repair produces no pipeline verdict; full extraction remains a later operator step.
