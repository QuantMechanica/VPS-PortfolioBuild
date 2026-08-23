# QM5_41127_wti-mdaily-persist-mom - Strategy Spec

**EA ID:** QM5_41127

**Slug:** `wti-mdaily-persist-mom`

**Strategy ID:** `MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026_S01`

**Source:** `MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-23

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct every close in the immediately completed month. Require 17 through
23 unique month-session closes plus the adjacent older close from the preceding
calendar month.

Starting at that boundary, calculate one chronological log return ending on
every session in the completed month. Let `N` be their signed sum and `mu=N/n`.
Let `S` be the sum of squared demeaned returns and `A` the sum of every adjacent
demeaned-return product. Calculate `rho=A/S` and the fixed short-sample score
`J=rho+1/(n-1)`. Require endpoint identity, finite arithmetic, positive `S`,
and bounded `rho`. Buy only when `J>0` and `N>0`; sell only when `J>0` and
`N<0`. Every other valid or malformed state consumes the month flat.

The position follows the persistence-qualified endpoint for one broker month,
using one fixed-risk budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 45 | bounded completed-month D1 buffer |
| `strategy_min_month_sessions` | 17 | minimum returns ending in month |
| `strategy_max_month_sessions` | 23 | maximum returns ending in month |
| `strategy_sample_bias_adjustment` | true | fixed `1/(n-1)` correction |
| `strategy_persistence_threshold` | 0.0 | strict positive corrected-score gate |
| `strategy_numerical_tolerance` | 1e-10 | endpoint and bound tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `strategy_deviation_points` | 20 | framework order-deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411270000`.
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: immediately completed broker-calendar month.
- Path: adjacent demeaned products across all daily returns ending in month.
- Trigger: bias-neutralized lag-one persistence score strictly above zero.
- Direction: sign of the completed-month endpoint return.
- Hold: first tick in a later broker month, with a forty-day stale repair.

## 5. Expected Behaviour

- Approximately five to seven completed WTI positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric direct-WTI monthly structural continuation after daily-persistence
  qualification.
- One fixed-risk position and one consumed attempt per broker month.
- Direct WTI supplies physical-energy exposure absent from the certified
  XAU/SP500/NDX/XNG book; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Mehlitz, J. S., and Auer, B. R. (2024), "Memory-enhanced momentum in commodity
futures markets," *The European Journal of Finance* 30(8), 773-802, DOI
`10.1080/1351847X.2023.2220118`.

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026/source.md`.

The papers supply WTI membership, own-return momentum/monthly clock, and
return-autocorrelation lineage. The within-month daily horizon, finite-sample
shift, and strict score gate are disclosed QM hypotheses; no source or sibling
result transfers to this continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
decorrelation claim, correlation waiver, portfolio-gate change, current-month
signal price, optimized threshold, score-strength sizing, external feed,
retry, scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Framework Alignment

- no_trade: exact symbol/period/ID/slot, locked risk/news/Friday and strategy
  inputs.
- trade_entry: month attempt, exact calendar package, daily return array,
  centering, variance/adjacent sums, correction, endpoint identity, spread/
  quote/ATR/stop checks, and one fixed-risk request.
- trade_management: malformed-position repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-23 | approved source build | source approval `4a9af0a24`; card `1930703f7`; governed magic `411270000` |
