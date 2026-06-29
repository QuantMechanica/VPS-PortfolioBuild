# QM5_12777_wti-dec-fade - Strategy Spec

**EA ID:** QM5_12777
**Slug:** `wti-dec-fade`
**Source:** `QUAY-WTI-DEC-2019`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural WTI month-of-year sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a short entry only when the current
broker-calendar month is December. The position is flattened on the first
subsequent D1 bar, when the chart leaves December, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
October and November fades, February/March/April/August premiums, weekday
seasonality, broad EIA monthly demand seasonality, WPSR, refinery, hurricane,
OPEC, expiry, ETF-roll, CAD/oil, XTI/XNG, XAU/XAG, XNG, and medium-term
trend/reversal sleeves all use different timing or information sets. This EA is
a pure December calendar fade.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 12 | 12 | Broker-calendar December |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 18-22.
- Typical hold: one D1 bar.
- Regime preference: WTI December month-of-year calendar weakness.
- Risk mode for Q02 backtests: RISK_FIXED.

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

