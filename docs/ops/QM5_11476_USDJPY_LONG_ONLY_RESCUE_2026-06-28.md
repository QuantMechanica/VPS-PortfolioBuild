# QM5_11476 USDJPY Long-Only Rescue - 2026-06-28

Scope: targeted rescue of `QM5_11476_lien-k-double-bb-trend-h1` on
`USDJPY.DWX` without touching `T_Live`.

## Diagnosis

The original audited Q05 baseline failed narrowly on PF:

- Q05 baseline: `FAIL`, PF `0.98`, DD `9.65%`, trades `2787`.
- Native deal decomposition showed the issue was directional, not a global
  absence of edge:
  - long side: `1553` trades, PF `1.088`, net `+5079.92`;
  - short side: `1234` trades, PF `0.849`, net `-7845.21`.

This made a long-only rescue the lowest-risk first variant. Baseline behavior is
unchanged because the new inputs default to the original both-direction/no-delay
configuration.

## Code And Setfiles

Added neutral-default EA inputs:

- `strategy_direction_mode=0`: both directions by default; `1` long-only,
  `-1` short-only.
- `strategy_min_exit_bars=0`: original neutral-channel exit timing by default.

Added rescue setfiles:

- `QM5_11476_lien-k-double-bb-trend-h1_USDJPY.DWX_H1_rescue_long_only_backtest.set`
- `QM5_11476_lien-k-double-bb-trend-h1_USDJPY.DWX_H1_rescue_minexit6_backtest.set`
- `QM5_11476_lien-k-double-bb-trend-h1_USDJPY.DWX_H1_rescue_long_minexit6_backtest.set`

Only the long-only variant has been promoted through stress gates so far.

## Verification

- Compile: `COMPILED`, no warnings/errors.
- Build guardrails: `PASS`.
- Regression tests:
  `python -m pytest framework\scripts\tests\test_q05_q07_verdicts.py framework\scripts\tests\test_q08_davey_subgates.py framework\scripts\tests\test_q04_walkforward.py tools\strategy_farm\tests\test_audit_q04_native_report_guard.py tools\strategy_farm\tests\test_portfolio_q08_contribution.py tools\strategy_farm\tests\test_portfolio_admission.py -q`
  -> `77 passed`.

## Pipeline Evidence

| gate | verdict | key metrics | evidence |
|---|---|---|---|
| Q04 | `PASS` | F1 PF `1.029`, F2 PF `1.448`, F3 PF `1.225`; trades `159 / 179 / 120` | `D:\QM\reports\rescue_11476_20260628\long_only_T9\QM5_11476\Q04\USDJPY.DWX\aggregate.json` |
| Q05 | `PASS` | PF `1.09`, DD `3.21%`, trades `1553` | `D:\QM\reports\rescue_11476_20260628\long_only_q05\QM5_11476\Q05\USDJPY_DWX\aggregate.json` |
| Q06 | `PASS` | PF `1.10`, DD `3.25%`, trades `1410` | `D:\QM\reports\rescue_11476_20260628\long_only_q06\QM5_11476\Q06\USDJPY_DWX\aggregate.json` |
| Q07 | `PASS` | seeds `42 / 17 / 99 / 7 / 2026`; PF `1.10 / 1.10 / 1.14 / 1.09 / 1.07`; variance `6.36%`; min PF `1.07`; trades `1410 / 1432 / 1412 / 1422 / 1419` | `D:\QM\reports\rescue_11476_20260628\long_only_q07_rerun1\QM5_11476\Q07\USDJPY_DWX\aggregate.json` |
| Q08 | `FAIL_SOFT` | `8/10` sub-gates PASS; Neighborhood PASS on bounded 1-param probe; PBO PASS `0.00%`; Regime PASS; soft signals: seasonal, chopping-block, cost cushion `1.9255`; durable stream `1552` trades | `D:\QM\reports\rescue_11476_20260628\long_only_q08\QM5_11476\Q08\USDJPY_DWX\aggregate.json` |
| Q09_PORTFOLIO | `FAIL_PORTFOLIO` | reason `correlation_above_max_corr`; trades `1552`; standalone PF `1.039`; monthly max corr `0.4446` vs cap `0.30`; Sharpe `1.9598 -> 1.8389`; MaxDD `0.4504 -> 0.4731` | `D:\QM\reports\rescue_11476_20260628\long_only_q09_portfolio\QM5_11476\Q09_PORTFOLIO\USDJPY_DWX\aggregate.json` |

## Q07 Runner Fix

The first Q07 run exposed an aggregation bug: a seed whose final `summary.json`
was `result: PASS` could still be marked invalid because an earlier retry inside
the same summary had `BARS_ZERO`/`M0_1970` markers. `summary_invalid_reason()`
now treats a final PASS summary as valid evidence, while failed `NO_HISTORY`
summaries remain invalid.

## Q08 Runner Fixes

The manual Q08 admission run exposed several harness defects and one scope
control:

- Q08 can now accept an explicit `--baseline-setfile` so rescues do not silently
  fall back to an older baseline setfile.
- Q08.5 now resolves V5 experts as `QM\<ea_dir>` and reads standard
  run_smoke timestamp summaries instead of a non-existent neighborhood-specific
  summary path.
- Q08.5 setfile fallback now skips framework/risk/categorical inputs and the
  Q08 aggregate supports `--neighborhood-max-params` for bounded manual probes.
- Q08 now persists the durable portfolio stream before Q08.5/Q08.7 support
  runners can overwrite the volatile Common\Files trade stream with perturbation
  or fold artifacts. This fixed the `1552` Q08 trades versus `1479` Q09 stream
  mismatch observed during the first Q09 attempt.

## Status

`QM5_11476 USDJPY long_only` is Q04-Q07 validated and Q08 `FAIL_SOFT`, but Q09
rejects it for the current book. It is a robust standalone/soft candidate, not a
current live-book addition unchanged. Revisit only if the book composition
changes materially or if a stricter decorrelation/session filter is developed.
