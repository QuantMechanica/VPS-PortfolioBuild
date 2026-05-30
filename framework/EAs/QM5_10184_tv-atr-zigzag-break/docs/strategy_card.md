---
ea_id: QM5_10184
slug: tv-atr-zigzag-break
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/volatility-filter]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/zigzag]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL and author; R2 mechanical ATR ZigZag breakout with bracket exits and ~120 trades/yr/symbol; R3 OHLC/ATR rules portable to DWX CFDs; R4 fixed non-ML one-position logic."
---

# TradingView ATR ZigZag Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `ATR ZigZag Breakout`, author handle `ReflexSignals`, published 2025-12-08, https://www.tradingview.com/script/Hi0gI790-ATR-ZigZag-Breakout/

## Mechanik

### Entry
Use M15 or H1 bars, long and short.

- Compute ATR(14).
- Build ATR-filtered ZigZag pivots: a swing high/low becomes official only after price reverses by at least ATR * pivot_threshold_multiplier from that extreme.
- When a new swing direction is confirmed, arm a pending stop order at the most recent unbroken pivot in the direction of the candidate breakout:
  - Long candidate: buy stop at the latest ATR-ZigZag swing high.
  - Short candidate: sell stop at the latest ATR-ZigZag swing low.
- If price breaks through the armed pivot, enter in that direction.
- Once a pivot has triggered a trade, do not reuse that same pivot in the same swing leg.
- If a new opposite swing confirms before entry, cancel the pending order and arm the new candidate level.
- One open position maximum.

### Exit
- Attach bracket immediately after entry.
- Take profit = stop distance * RR multiplier.
- Optional session filter may restrict entries to liquid hours, but baseline uses all broker hours except rollover.
- If an opposite armed level triggers while a position is active, close the current position first; do not pyramid.

### Stop Loss
- Stop distance = ATR(14) * SL multiplier at entry.
- Baseline defaults: pivot_threshold_multiplier 2.0, SL multiplier 1.5, RR multiplier 1.5.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Spread must be <= 15% of stop distance.
- Rollover blackout: no new entries 21:55-22:10 UTC.
- DWX port targets NDX.DWX, XAUUSD.DWX, XTIUSD.DWX, GER40.DWX, and EURUSD.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - stop entry through ATR-filtered swing highs/lows.
- [[concepts/volatility-filter]] - ATR threshold reduces noisy pivot levels.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `ReflexSignals` are cited. |
| R2 Mechanical | PASS | Source defines ATR ZigZag pivot confirmation, candidate stop levels, bracket SL/TP, one-use levels, and cancel/rotate behavior. |
| R3 Data Available | PASS | Uses OHLC-derived ATR and swing levels; source mentions NQ/GC/crypto but rules port directly to DWX index, gold, oil, and FX CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator logic, no ML, no grid, no martingale, and one-position-per-magic compatible after disabling pyramiding. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10186_tv-pivot-time-break]] - simpler pivot close breakout with time and MA filters.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
