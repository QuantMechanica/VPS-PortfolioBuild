# QM5_41418_xauxag-wstreak2-cont — Strategy Spec

- EA ID: QM5_41418
- Slug: `xauxag-wstreak2-cont`
- Strategy ID: `MOP-CME-XAUXAG-WSTREAK2-CONT-20260910_S01`
- Source: `MOP-CME-XAUXAG-WSTREAK2-CONT-20260910`
- Author: Codex
**Last revised:** 2026-09-10

## 1. Strategy Logic

At the first tradable host D1 bar of a new broker week, reconstruct four
consecutive synchronized completed-week XAU/XAG endpoints. Form exactly three
adjacent XAU-minus-XAG relative log returns, oldest to newest. Trade only
strict `-,+,+` or `+,-,-`: the newest two returns form a fresh same-sign streak
after an opposite predecessor. Follow that streak for one week. A tie, invalid
endpoint, non-fresh state, or late attachment consumes flat.

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
| `strategy_host_max_spread_points` | 1500 |
| `strategy_companion_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

All strategy parameters are locked for Q02. Framework news and Friday inputs
remain configurable and are not equality-pinned. The stress probability is
validated only for finiteness and the inclusive `0..1` range.

## 3. Symbol Universe

- Host input: `XAUUSD.DWX`, D1, slot 0.
- Companion input: `XAGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41418_XAU_XAG_WSTREAK2_CONT_D1`.
- One equal-notional, opposed-leg research package; neither leg is standalone.

## 4. Lifecycle And Risk

The package exits on the first tick of the next broker week, with a ten-day
stale repair. Each leg has a frozen `3.5*ATR(20,D1)` hard stop. Q02 uses one
aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and weight 1. Both news
axes and framework Friday close are off in the setfile, but the source does not
pin them. Atomic orphan and malformed-package repair precedes entry gates.

## 5. Source And Non-Duplicate Boundary

Moskowitz, Ooi, and Pedersen (*Journal of Financial Economics*, 2012, DOI
`10.1016/j.jfineco.2011.11.003`) establish the commodity time-series momentum
lineage. CME defines the gold/silver ratio and intermarket-spread carrier. The
fresh two-week relative continuation is an untested QM translation.
`QM5_41417` takes the opposite side; `QM5_41078` waits for a third same-sign
week and fades; `QM5_41414` follows an overlapping-window majority flip.

## 6. Safety Boundary

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, portfolio admission,
correlation waiver, external feed, retry, scale-in, grid, pyramid, target,
trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-10 | approved build identity |
| v1-build | 2026-09-10 | governed COMPILE_OK and Q01 build-check PASS |
| v1-q02 | 2026-09-10 | paced fixed-risk logical basket Q02 enqueued; result pending |
