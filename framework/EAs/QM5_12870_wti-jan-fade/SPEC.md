# QM5_12870_wti-jan-fade - Strategy Spec

**EA ID:** QM5_12870
**Slug:** `wti-jan-fade`
**Source:** `ARENDAS-OIL-SEASON-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency structural WTI month-of-year sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a short entry only when the
current broker-calendar month is January. The position is flattened on the
first subsequent D1 bar, when the chart leaves January, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
April/May/August single-month long premiums, October/November/December fades,
broad February-September seasonality, weekday seasonality, WPSR, refinery,
hurricane, OPEC, expiry, roll, Cushing, WTI/FX, WTI/Brent, and medium-term
momentum/reversal all use different timing or information sets. This EA is a
pure January calendar-fade anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 1 | 1 | Broker-calendar January |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0. This is the DWX WTI crude-oil custom symbol
  present in `framework/registry/dwx_symbol_matrix.csv`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 18-22.
- Typical hold: one D1 bar.
- Regime preference: WTI January month-of-year calendar weakness.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Arendas, P., Chovancova, B. and Balaz, V., "Seasonal patterns in oil prices and
their implications for investors", Journal of International Studies, URL
https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

All R1-R4 checks are PASS per
`artifacts/cards_approved/QM5_12870_wti-jan-fade.md`.

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
| v1 | 2026-07-02 | Initial build from card | build task `984cdf19-838d-4df1-ab26-77a76f0fb087` |
