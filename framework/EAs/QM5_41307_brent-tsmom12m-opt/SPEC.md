# QM5_41307_brent-tsmom12m-opt - Strategy Spec

**EA ID:** QM5_41307
**Slug:** `brent-tsmom12m-opt`
**Source:** `MOP-TSMOM-2012_BRENT_S01`
**Parent EA:** QM5_12849_brent-tsmom12m
**Parent source:** MOP-TSMOM-2012_BRENT_S01
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

## 1. Strategy Logic

This EA implements a low-frequency structural Brent time-series-momentum sleeve
on `XTIUSD.DWX`. On the first new D1 bar of each broker-calendar month, it
computes the prior 12-month log return from completed D1 closes. A positive
return above the neutral band opens a monthly long package; a negative return
below the neutral band opens a monthly short package. Any open package is
flattened on the next monthly rebalance or by the max-hold stale-position guard.
Each position carries an ATR hard stop and Q02 backtests run in `RISK_FIXED`
mode.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Each enabled predicate is evaluated on the
completed D1 reference bar through `QM_PatternPermissionEvaluate` and may
suppress an entry on its own side immediately before order placement. Zero
disables a slot, so with the neutral control defaults the Q02 behavior is
mechanically identical to the approved parent. A predicate can only suppress an
entry on its own side; it cannot create a trade or alter exits, sizing, the ATR
hard stop, news behavior, or Friday-close behavior.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-315 | Completed D1 bars used for 12-month return-sign signal |
| `strategy_min_abs_return_pct` | 1.0 | 0.0-5.0 | Neutral band around zero trailing return |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |
| `opt_pp_buy1..3` | 0 | pattern IDs | optional buy-side pattern veto predicate IDs |
| `opt_pp_sell1..3` | 0 | pattern IDs | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Magic | Rationale |
|---:|---|---:|---|
| 0 | XTIUSD.DWX | 413070000 | approved WTI carrier for the Brent 12M TS-momentum port |

The EA rejects every other symbol and timeframe.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Pattern reference: closed D1 bar (shift 1).
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 8-12 (central prior 10), inherited from the
  parent; the pattern surface can only reduce entries, never add them.
- Typical hold: one monthly package, capped at 31 calendar days by default.
- Regime preference: persistent Brent directional trends over a 12-month
  horizon.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Derivative source ID: `MOP-TSMOM-2012_BRENT_S01`. Parent EA:
`QM5_12849_brent-tsmom12m`.

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H., "Time Series Momentum",
Journal of Financial Economics, 2012, 104(2), 228-250, URL
https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum.

The complete parent rules are recorded in
`C:/QM/repo/framework/EAs/QM5_12849_brent-tsmom12m/docs/strategy_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior. No live manifest, `T_Live` file, portfolio gate, or
AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build (measurement sibling of QM5_12849) | CEO order 2026-09-02 |
