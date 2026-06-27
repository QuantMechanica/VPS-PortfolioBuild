# QM5_12596_wti-mon-fade - Strategy Spec

**EA ID:** QM5_12596
**Slug:** `wti-mon-fade`
**Source:** `QUAY-WTI-DOW-2019`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI weekday-seasonality sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a short entry only when the current
broker-calendar day is Monday. The position is flattened on the first subsequent
D1 bar or by a one-calendar-day stale-position guard. The only price-derived
input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
monthly seasonality, WPSR continuation/fade/pre-event, refinery maintenance,
hurricane-season breakout, and medium-term return reversal all use different
information sets and entry logic. This EA is a pure weekday calendar anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_entry_dow` | 1 | 1 | Broker-calendar Monday, where Sunday=0 |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 45-52.
- Typical hold: one D1 bar.
- Regime preference: WTI weekday/weekend-effect seasonality.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Quayyum, H. A., et al., "Seasonality in crude oil returns", Soft Computing 24,
7857-7873 (2020), DOI https://doi.org/10.1007/s00500-019-04329-0.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
