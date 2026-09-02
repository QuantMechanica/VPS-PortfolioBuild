# QM5_41305_brent-nov-fade-opt - Strategy Spec

**EA ID:** QM5_41305
**Slug:** brent-nov-fade-opt
**Source:** KHAN-WTI-BRENT-SEASON-2023
**Parent EA:** QM5_12855_brent-nov-fade
**Parent source:** KHAN-WTI-BRENT-SEASON-2023
**Author of this spec:** Claude CEO
**Last revised:** 2026-09-02

## 1. Strategy Logic

This EA implements a low-frequency structural month-of-year fade sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a short entry only when the current
broker-calendar month is November. The position is flattened on the first
subsequent D1 bar, when the chart leaves November, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.
Runtime uses MT5 OHLC and the broker calendar only; no external energy data.

The derivative adds six optional closed-D1 pattern veto slots: three for buy
entries and three for sell entries. Each closed-bar reference is read at
`PERIOD_D1` shift 1 and evaluated through `QM_PatternPermissionEvaluate`. Zero
disables a slot, so the Q02 control is mechanically identical to the approved
parent `QM5_12855_brent-nov-fade`. An enabled predicate may suppress an entry
request on its own side immediately before order placement; it cannot create a
trade or alter exits, the ATR hard stop, sizing, the month-of-year gate, the
stale-position guard, news behavior, or Friday-close behavior.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_entry_month | 11 | Broker-calendar November (short-only month) |
| strategy_atr_period | 20 | ATR period for the hard stop |
| strategy_atr_sl_mult | 2.25 | ATR stop distance multiplier |
| strategy_max_hold_days | 1 | Calendar-day stale-position guard |
| strategy_max_spread_points | 1200 | Entry spread cap |
| opt_pp_buy1..3 | 0 | optional buy-side pattern veto predicate IDs |
| opt_pp_sell1..3 | 0 | optional sell-side pattern veto predicate IDs |

The Q02 baseline keeps all six pattern inputs at zero. Pattern discovery is a
later governed measurement and is not part of this build.

## 3. Symbol Universe

| Slot | Symbol | Magic | Rationale |
|---:|---|---:|---|
| 0 | XTIUSD.DWX | 413050000 | approved crude-oil November-fade carrier |

The EA rejects every other symbol and timeframe.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none. Pattern reference read at `PERIOD_D1` shift 1.
- Bar gating: `QM_IsNewBar()`; entries considered at the first tick of a new
  broker D1 bar.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year | 18-22, central prior 20 |
| Typical hold | one D1 bar |
| Entry style | November-only market short |
| Regime preference | November month-of-year weakness |

The source reports crude-oil seasonality evidence. This carrier is a
falsifiable structural port and inherits no profitability claim.

## 6. Source Citation

Derivative source ID: KHAN-WTI-BRENT-SEASON-2023. Parent source ID:
KHAN-WTI-BRENT-SEASON-2023.

Khan, Z., Saha, T. R. and Ekundayo, T., "Understanding the Seasonality in Crude
Oil Returns for WTI and Brent", Research Square posted content, DOI
10.21203/rs.3.rs-2569101/v1, URL
https://www.researchsquare.com/article/rs-2569101/v1.pdf.

Derivative approval and R1-R4 evidence are recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41305_brent-nov-fade-opt.md`.
The complete parent rules are recorded in
`C:/QM/repo/strategy-seeds/cards/approved/QM5_12855_brent-nov-fade_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02-Q10) | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized | n/a |

The backtest preset explicitly fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. It retains the parent's two-axis DXZ news gate and
Friday-close behavior. No live preset, deployment artifact, or portfolio-gate
change is created.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | Approved DL-089 derivative V5 build | pattern instrumentation sibling of QM5_12855 |
