# QM5_41372_xtixng-wrelvote-flip-cont — Strategy Spec

- EA ID: QM5_41372
- Slug: `xtixng-wrelvote-flip-cont`
- Strategy ID: `AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906_S01`
- Source: `AI-CODEX-XTIXNG-WRELVOTE-FLIP-CONT-20260906`
- Author: Codex
**Last revised:** 2026-09-06

## 1. Strategy Logic

At the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
the final synchronized XTI/XNG close pairs from the five immediately preceding
consecutive weeks. Each week must contain three to five synchronized sessions.
Form four adjacent XTI-minus-XNG weekly log returns. Compare the strict sign
majority in the older `[d0,d1,d2]` window with the newer `[d1,d2,d3]` window.
Trade only when that majority reverses, following the new relative winner for
one week. A tie, invalid endpoint, no flip, or late attachment consumes flat.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_history_bars_d1` | 50 |
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

- Host: exact `XTIUSD.DWX`, D1, slot 0.
- Companion: exact `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41372_XTI_XNG_WRELVOTE_FLIP_CONT_D1`.
- One equal-notional, opposed-leg research package; neither leg is standalone.

## 4. Lifecycle And Risk

The package exits on the first tick of the next broker week, with a ten-day
stale repair. Each leg has a frozen `3.5*ATR(20,D1)` hard stop. Q02 uses one
aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and weight 1. Both news
axes and framework Friday close are off. Atomic orphan and malformed-package
repair precedes entry gates.

## 5. Source And Non-Duplicate Boundary

Fuertes, Miffre, and Rallis (*Journal of Banking & Finance*, 2010, DOI
`10.1016/j.jbankfin.2010.04.009`) support commodity relative-return research.
Villar/Joutz (U.S. EIA, 2006) and Ramberg/Parsons (*The Energy Journal*, 2012,
DOI `10.5547/01956574.33.2.2`) establish an economically linked but weak and
unstable oil/gas relationship. The overlapping weekly majority flip is an
untested QM translation. Existing nearest siblings use one- or two-week
common-shock states, not four relative returns and two overlapping votes.

## 6. Safety Boundary

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, portfolio admission,
correlation waiver, external feed, retry, scale-in, grid, pyramid, target,
trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-06 | approved build identity |
