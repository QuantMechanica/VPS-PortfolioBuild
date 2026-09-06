# QM5_41373_xtixng-walt3-rv — Strategy Spec

- EA ID: QM5_41373
- Slug: `xtixng-walt3-rv`
- Strategy ID: `AI-CODEX-XTIXNG-WALT3-RV-20260907_S01`
- Source: `AI-CODEX-XTIXNG-WALT3-RV-20260907`
- Author: Codex
**Last revised:** 2026-09-07

## 1. Strategy Logic

At the first tradable host D1 bar of a new broker week, reconstruct four
consecutive synchronized completed-week XTI/XNG endpoints. Form exactly three
adjacent XTI-minus-XNG relative log returns. Trade only strict `+,-,+` or
`-,+,-` sign alternation and fade the newest relative winner for one week. A
tie, invalid endpoint, non-alternating state, or late attachment consumes flat.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_host_symbol` | setfile/host chart |
| `strategy_companion_symbol` | setfile-required |
| `strategy_history_bars_d1` | 45 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_signal_epsilon` | 1e-10 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_xti_max_spread_points` | 1500 |
| `strategy_xng_max_spread_points` | 3000 |
| `strategy_deviation_points` | 20 |

All strategy parameters are locked for Q02.

## 3. Symbol Universe

- Host input: `XTIUSD.DWX`, D1, slot 0.
- Companion input: `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41373_XTI_XNG_WALT3_RV_D1`.
- One equal-notional, opposed-leg research package; neither leg is standalone.

## 4. Lifecycle And Risk

The package exits on the first tick of the next broker week, with a ten-day
stale repair. Each leg has a frozen `3.5*ATR(20,D1)` hard stop. Q02 uses one
aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and weight 1. Both news
axes and framework Friday close are off. Atomic orphan and malformed-package
repair precedes entry gates.

## 5. Source And Non-Duplicate Boundary

Villar/Joutz (U.S. EIA, 2006) and Ramberg/Parsons (*The Energy Journal*, 2012,
DOI `10.5547/01956574.33.2.2`) establish an economically linked but weak and
unstable oil/gas relationship. Fuertes/Miffre/Rallis (*Journal of Banking &
Finance*, 2010, DOI `10.1016/j.jbankfin.2010.04.009`) provide commodity
relative-return lineage. The three-week strict alternation fade is an untested
QM translation. Nearby builds use two-return magnitude states, individual-leg
common shocks, leader states, or four-return vote transitions.

## 6. Safety Boundary

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, portfolio admission,
correlation waiver, external feed, retry, scale-in, grid, pyramid, target,
trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-07 | approved build identity |
