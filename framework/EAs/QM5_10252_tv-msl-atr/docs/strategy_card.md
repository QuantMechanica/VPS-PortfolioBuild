---
ea_id: QM5_10252
slug: tv-msl-atr
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/pivot-structure]]"
  - "[[indicators/atr-trailing-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: XAUUSD.DWX
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/handle cited; R2 deterministic pivot-break entries, ATR trailing exits, and 45 trades/year/symbol estimate; R3 DWX OHLC/ATR testable; R4 fixed rules no ML/grid/martingale one-position-per-magic."
---

# QM5_10252 TradingView MSL Structure Break ATR Trend Follow

## Quelle
- Source: TradingView Pine script "MSL Trend Follow"
- URL: https://www.tradingview.com/script/nKDLOq2T-msl-trend-follow/
- Author: MarketStructureLab (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView Trend Analysis category, public open-source script, 2026-05-19 snapshot.

## Mechanik

### Entry
- Confirm swing highs/lows using symmetric pivots. Baseline pivot length: 5 bars.
- Maintain the most recent confirmed swing high and swing low.
- Long setup:
  - Close breaks above the most recent confirmed swing high.
  - Minimum bars since prior trend signal >= 10.
  - Enter long at next bar open.
- Short setup:
  - Close breaks below the most recent confirmed swing low.
  - Minimum bars since prior trend signal >= 10.
  - Enter short at next bar open.
- Opposite structure break exits before opening the reverse direction.

### Exit
- Use ATR ratchet trailing stop:
  - Long trailing stop = max(previous trailing stop, Close - ATR(14) x 3.0).
  - Short trailing stop = min(previous trailing stop, Close + ATR(14) x 3.0).
- Exit when close crosses through the active trailing stop.
- Exit and reverse on opposite confirmed structure break.

### Stop Loss
- Initial stop is the first ATR trailing stop value after entry.
- Catastrophic hard stop: entry +/- 5.0 x ATR(14).

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.

### Zusaetzliche Filter
- Skip signals when the breakout bar range is < 0.5 x ATR(14), to avoid tiny pivot pierces.
- P3 filter candidate: higher-timeframe direction must agree with current signal.
- Standard V5: QM_KillSwitch, news filter, MAX_DD trip, Friday-close flatten.

## Concepts
- [[concepts/trend-following]] - primary; follow the active phase after a structural break.
- [[concepts/breakout]] - entry is a close through confirmed swing structure.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle MarketStructureLab are cited. |
| R2 Mechanical | PASS | Pivot structure break entries and ATR ratchet trailing stop exits are closed-form rules. |
| R3 Data Available | PASS | OHLC pivots and ATR are available on all DWX symbols/timeframes. |
| R4 ML Forbidden | PASS | No ML, no adaptive parameters, no grid, no martingale. One position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9167_tv-boswaves-supertrend-extensions]] - sibling trend-following/ATR stop card, but this entry is pivot-structure rather than Supertrend flip.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Default P2 symbols: XAUUSD.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX.
- Default timeframe: H1. P3 sweep: M30/H4.
- Pivot confirmation is delayed by design; do not use future bars for an entry before the pivot is confirmed.
