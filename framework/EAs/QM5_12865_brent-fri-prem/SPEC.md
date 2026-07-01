# QM5_12865_brent-fri-prem - Strategy Spec

**EA ID:** QM5_12865
**Slug:** `brent-fri-prem`
**Source:** `QUAY-WTI-DOW-2019`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency structural Brent weekday sleeve on
`XBRUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar D1 bar is Friday. The position is flattened by the V5 Friday
close guard, on the first subsequent non-Friday D1 bar, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing energy family:
Brent Thursday premium, Brent Monday fade, WTI Friday premium, WTI
month/event/roll/refinery/hurricane/Cushing, WTI/Brent relative baskets,
XTI/XNG baskets, XNG storage/weather/day-of-week, XAU/XAG, oil/gold, oil/silver,
and `QM5_12567_cum-rsi2-commodity` all use different symbols, weekdays,
directions, or information sets.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_dow` | 5 | 5 | Broker-calendar Friday, Sunday=0 |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 40-52 before Q02 validates XBR history.
- Typical hold: Friday session through Friday close or one D1 bar.
- Regime preference: Brent Friday day-of-week calendar premium.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Quayyum, H. A., Khan, M. A. M. and Ali, S. M., "Seasonality in crude oil
returns", Soft Computing 24, 7857-7873 (2020), DOI
https://doi.org/10.1007/s00500-019-04329-0.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from card | Q02 work item `b84d3cb8-2ecf-4efa-bdc5-ef0cdacbdf2e` |
