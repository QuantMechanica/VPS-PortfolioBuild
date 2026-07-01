# QM5_12855_brent-nov-fade - Strategy Spec

**EA ID:** QM5_12855
**Slug:** `brent-nov-fade`
**Source:** `KHAN-WTI-BRENT-SEASON-2023`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural Brent month-of-year sleeve on
`XBRUSD.DWX`. On each new D1 bar, it permits a short entry only when the current
broker-calendar month is November. The position is flattened on the first
subsequent D1 bar, when the chart leaves November, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing energy family:
`QM5_12854_brent-dec-fade` isolates December, `QM5_12726_wti-nov-fade` targets
WTI rather than Brent, and Brent May, Brent weekday, Brent TSMOM, Brent/WTI
spread, WTI event/calendar, XTI/XNG, XNG, XAU/XAG, gas-metal, index, and
commodity RSI sleeves all use different markets, information sets, or timing.
This EA is a pure Brent November calendar-weakness anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 11 | 11 | Broker-calendar November |
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

- Expected trades/year/symbol: about 18-22.
- Typical hold: one D1 bar.
- Regime preference: Brent November month-of-year weakness.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Khan, Z., Saha, T. R. and Ekundayo, T., "Understanding the Seasonality in Crude
Oil Returns for WTI and Brent", Research Square posted content, DOI
10.21203/rs.3.rs-2569101/v1, URL
https://www.researchsquare.com/article/rs-2569101/v1.pdf.

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
| v1 | 2026-07-01 | Initial build from card | build commit pending |
