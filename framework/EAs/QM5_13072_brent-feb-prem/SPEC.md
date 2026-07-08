# QM5_13061_brent-jun-prem - Strategy Spec

**EA ID:** QM5_13061
**Slug:** `brent-jun-prem`
**Source:** `ARENDAS-OIL-SEASON-2018`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency structural Brent month-of-year sleeve on
`XBRUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar month is June. The position is flattened on the first
subsequent D1 bar, when the chart leaves June, or by a one-calendar-day
stale-position guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing energy family:
`QM5_12981_brent-febsep-prem` tests one first-tradable-day entry across the
source window, while this build isolates daily June Brent exposure inside that
window. Existing Brent March/April/May/August/September/November/December/
January calendar, Brent weekday, Brent TSMOM, Brent/WTI spread, WTI
event/calendar, XTI/XNG, XNG, XAU/XAG, and commodity RSI sleeves all use
different information sets, markets, or timing. This EA is a pure Brent June
calendar-premium anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 6 | 6 | Broker-calendar June |
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

- Expected trades/year/symbol: about 18-23.
- Typical hold: one D1 bar.
- Regime preference: Brent June month-of-year source-window premium.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Arendas, P., Tkacova, D. and Bukoven, J., "Seasonal patterns in oil prices and
their implications for investors", Journal of International Studies, 11(2),
180-192, DOI 10.14254/2071-8330.2018/11-2/12, URL
https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

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
| v1 | 2026-07-08 | Initial build from card | Q02 queued as work_item 4f8bbc99-ead4-47ac-a686-d4d550a8f799 |
