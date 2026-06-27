# QM5_12727_wti-apr-prem - Strategy Spec

**EA ID:** QM5_12727
**Slug:** `wti-apr-prem`
**Source:** `ARENDAS-OIL-SEASON-2018`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI month-of-year sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar month is April. The position is flattened on the first
subsequent D1 bar, when the chart leaves April, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
February premium, October/November fades, weekday seasonality, broad EIA
monthly demand seasonality, WPSR continuation/fade/pre-event, refinery
maintenance, hurricane-season breakout, OPEC event-window breakout, expiry
breakout, and medium-term momentum/reversal all use different information sets
or timing. This EA is a pure April calendar-premium anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 4 | 4 | Broker-calendar April |
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
- Regime preference: WTI April month-of-year calendar premium.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Arendas, P., Chovancova, B. and Balaz, V., "Seasonal patterns in oil prices and
their implications for investors", Journal of Investment Strategies, URL
https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
