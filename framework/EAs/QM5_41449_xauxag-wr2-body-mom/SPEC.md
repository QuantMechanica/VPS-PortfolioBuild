# QM5_41449_xauxag-wr2-body-mom — Strategy Spec

- EA ID: QM5_41449
- Slug: `xauxag-wr2-body-mom`
- Strategy ID: `FMR-CRABEL-CME-XAUXAG-WR2-BODY-MOM-20260912_S01`
- Source: `FMR-CRABEL-CME-XAUXAG-WR2-BODY-MOM-20260912`
- Author: Codex
- Last revised: 2026-09-12

## 1. Strategy Logic

At the first tradable host D1 bar of a new broker week, reconstruct exactly two consecutive,
synchronized completed weeks of XAU/XAG log-ratio closes. Require the newest ratio-close range to
be strictly wider than the prior range. Continue the strict newest ratio-week body through an
opposed equal-notional package, consume one attempt per week, and hold for one normalized week.
Invalid, tied, contracting, or late states consume flat.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_host_symbol` | setfile/host chart |
| `strategy_companion_symbol` | setfile-required |
| `strategy_history_bars_d1` | 45 |
| `strategy_required_weeks` | 2 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_body_epsilon` | 0.0000000001 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_host_max_spread_points` | 1500 |
| `strategy_companion_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

All strategy parameters are locked for Q02. Framework RNG, news, and Friday inputs remain
configurable and are not equality-pinned. Stress probability is validated only for finiteness and
the inclusive `0..1` range.

## 3. Symbol Universe

- Host input: `XAUUSD.DWX`, D1, slot 0.
- Companion input: `XAGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41449_XAU_XAG_WR2_BODY_MOM_D1`.
- One equal-notional, opposed-leg research package; neither leg is standalone.

## 4. Lifecycle And Risk

The package exits on the first tick of the next broker week, with a ten-day stale repair. Each leg
has a frozen `3.5*ATR(20,D1)` hard stop. Q02 uses one aggregate `RISK_FIXED=1000` budget,
`RISK_PERCENT=0`, and weight 1. Both news axes and framework Friday close are off in the setfile,
but source code does not pin them. Atomic orphan and malformed-package repair precedes entry.

## 5. Source And Non-Duplicate Boundary

Fuertes, Miffre, and Rallis (*Journal of Banking & Finance*, 2010, DOI
`10.1016/j.jbankfin.2010.04.009`) supply commodity-momentum lineage; CME supplies the gold/silver
ratio-spread carrier; governed Crabel records supply range-state and completed-week lineage. The
exact WR2/body ratio continuation is an untested QM translation. It differs from `QM5_41448`'s
outer-quartile fade, alternation and same-sign streak relatives, and directional seasonal WTI.

## 6. Safety Boundary

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading, `T_Live`,
deploy/live manifest, portfolio-gate change, portfolio admission, correlation waiver, external
feed, retry, scale-in, grid, pyramid, target, trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-12 | initial approved build identity |
| v1-q01 | 2026-09-12 | governed T7 compile and strict build check PASS; 6 reference tests and PACER audit PASS |
