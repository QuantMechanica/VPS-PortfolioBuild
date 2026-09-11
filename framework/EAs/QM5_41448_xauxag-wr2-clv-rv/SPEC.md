# QM5_41448_xauxag-wr2-clv-rv — Strategy Spec

- EA ID: QM5_41448
- Slug: `xauxag-wr2-clv-rv`
- Strategy ID: `SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912_S01`
- Source: `SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912`
- Author: Codex
- Last revised: 2026-09-12

## 1. Strategy Logic

At the first tradable host D1 bar of a new broker week, reconstruct exactly two consecutive,
synchronized completed weeks of XAU/XAG log-ratio closes. Require the newest ratio-close range to
be strictly wider than the prior range. Fade only a newest ratio close strictly above 0.75 or
below 0.25 of its own weekly range, then hold the opposed equal-notional package for one week.
Invalid, tied, contracting, interior, or late states consume flat.

## 2. Parameters

| Parameter | Value |
|---|---:|
| `strategy_host_symbol` | setfile/host chart |
| `strategy_companion_symbol` | setfile-required |
| `strategy_history_bars_d1` | 45 |
| `strategy_required_weeks` | 2 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_clv_lower` | 0.25 |
| `strategy_clv_upper` | 0.75 |
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
- Logical symbol: `QM5_41448_XAU_XAG_WR2_CLV_RV_D1`.
- One equal-notional, opposed-leg research package; neither leg is standalone.

## 4. Lifecycle And Risk

The package exits on the first tick of the next broker week, with a ten-day stale repair. Each leg
has a frozen `3.5*ATR(20,D1)` hard stop. Q02 uses one aggregate `RISK_FIXED=1000` budget,
`RISK_PERCENT=0`, and weight 1. Both news axes and framework Friday close are off in the setfile,
but source code does not pin them. Atomic orphan and malformed-package repair precedes entry.

## 5. Source And Non-Duplicate Boundary

Schweikert (*Journal of Banking & Finance*, 2018, DOI
`10.1016/j.jbankfin.2017.11.010`) and CME supply gold/silver relationship and ratio-spread
lineage. Governed Crabel records supply range-state and completed-week lineage. The exact WR2/CLV
ratio fade is an untested QM translation. It differs from one-week close rank, seven-week NR
breakout, per-leg CLV divergence, weekly sign streaks, and directional seasonal WTI systems.

## 6. Safety Boundary

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading, `T_Live`,
deploy/live manifest, portfolio-gate change, portfolio admission, correlation waiver, external
feed, retry, scale-in, grid, pyramid, target, trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-12 | initial approved build identity |
