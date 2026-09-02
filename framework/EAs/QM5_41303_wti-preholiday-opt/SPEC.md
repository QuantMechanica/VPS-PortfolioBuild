# QM5_41303_wti-preholiday-opt - Strategy Spec

**EA ID:** QM5_41303
**Slug:** wti-preholiday-opt
**Source:** QADAN-AHARON-EICHEL-2019
**Parent EA:** QM5_20048_wti-preholiday
**Parent source:** QADAN-AHARON-EICHEL-2019
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

## 1. Strategy Logic

Once per new XTIUSD.DWX D1 bar, the EA buys WTI on the last tradable D1 session
before observed New Year, Presidents Day, Good Friday, Memorial Day,
Independence Day, Labor Day, Thanksgiving, and Christmas. It exits on the first
subsequent D1 bar, with a four-calendar-day stale guard and a frozen ATR (period
20, multiplier 3.0) hard stop. One long attempt is allowed per holiday; there is
no retry, pyramid, grid, martingale, or ML logic. Entry spread is capped at
1,200 points.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Zero disables a slot, so the Q02 control is
mechanically identical to the approved parent. An enabled predicate may suppress
an entry on its own side; it cannot create a trade or alter exits, sizing, the
ATR hard stop, news behavior, or Friday-close behavior. The parent is long-only,
so only the buy-side slots can affect its single pre-holiday entry; the sell-side
slots are wired symmetrically for the shared instrument and remain inert.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_atr_period | 20 | ATR period for the hard stop |
| strategy_atr_sl_mult | 3.0 | ATR stop multiplier |
| strategy_max_hold_days | 4 | maximum calendar-day hold before stale close |
| strategy_max_spread_points | 1200 | entry spread cap |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Magic | Rationale |
|---:|---|---:|---|
| 0 | XTIUSD.DWX | 413030000 | approved WTI pre-holiday carrier |

The EA rejects every other symbol and timeframe. WTI crude-oil exposure is
inherited from the approved parent; portfolio diversification remains a later Q09
claim, not a build assumption.

## 4. Timeframe

`D1`; all calendar decisions, pattern-reference evaluation, and execution occur
once per new broker D1 bar. Range and pattern geometry use completed bars only.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year | approximately 8 packages before framework exclusions |
| Maximum hold time | 4 calendar days |
| Entry style | long-only calendar pre-holiday market entry |
| Regime preference | recurring US-holiday sentiment window |

Q02 retires the strategy below five packages/year or on governed economics. The
source studies calendar anomalies in natural-resource futures and reports
abnormal returns around joyful U.S. holidays; this carrier inherits no
profitability claim beyond the approved parent.

## 6. Source Citation

Source ID: QADAN-AHARON-EICHEL-2019. Parent source ID: QADAN-AHARON-EICHEL-2019.

Qadan, M., Aharon, D. Y., and Eichel, R. (2019), "Seasonal patterns and calendar
anomalies in the commodity market for natural resources," Resources Policy 63,
101435, DOI `10.1016/j.resourpol.2019.101435`.

Derivative approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41303_wti-preholiday-opt.md`.
The complete parent rules are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20048_wti-preholiday_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior. No live preset, deployment artifact, or portfolio-gate
change is created.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build | CEO order 2026-09-02, path-to-25 pattern instrumentation sibling |
