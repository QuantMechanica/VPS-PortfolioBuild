# QM5_12599_wti-feb-prem - Strategy Spec

**EA ID:** QM5_12599
**Slug:** `wti-feb-prem`
**Source:** `GORSKA-WTI-CAL-2015`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency structural WTI month-of-year sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar month is February. The position is flattened on the first
subsequent D1 bar, when the chart leaves February, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
weekday seasonality, broad EIA monthly demand seasonality, WPSR
continuation/fade/pre-event, refinery maintenance, hurricane-season breakout,
OPEC event-window breakout, and medium-term return reversal all use different
information sets and entry logic. This EA is a pure February calendar anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 2 | 2 | Broker-calendar February |
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
- Regime preference: WTI February month-of-year calendar premium.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Gorska, A. and Krawiec, M., "Calendar Effects in the Market of Crude Oil",
Quantitative Methods in Economics, 16(4), 2015, URL
https://ageconsearch.umn.edu/record/230857/files/2015_4_7.pdf.

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
| v1 | 2026-06-27 | Initial build from card | first structural build |
| v2 | 2026-07-02 | OnTick ordering fix per 2026-07-02 audit rule; remove duplicate CloseTimeExpired call from EntrySignal | eba2ee32-da67-477d-9cb7-7131b40c01ad |
