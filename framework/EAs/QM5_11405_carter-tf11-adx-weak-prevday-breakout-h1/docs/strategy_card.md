---
ea_id: QM5_11405
slug: carter-tf11-adx-weak-prevday-breakout-h1
type: strategy
source_id: 29c77a02-59bd-52f7-bcb3-b3108d5f1e79
sources:
  - "[[sources/thomas-carter-20-trend-following-systems-forex]]"
concepts:
  - "[[concepts/range-consolidation-filter]]"
  - "[[concepts/previous-day-breakout]]"
  - "[[concepts/adx-trend-strength]]"
indicators:
  - "[[indicators/adx]]"
period: H1
source_citation: "Thomas Carter, 20 Trend Following Systems (2014), Strategy #11, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\514732392-Forex-Trend-Following-Strategy.pdf"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named author Thomas Carter, 2014 published book."
r2_mechanical: PASS
r2_reasoning: "ADX threshold, previous-day H/L levels, and pending stop-order placement are fully deterministic."
r3_data_available: PASS
r3_reasoning: "H1 DWX FX symbols available; D1 previous-day H/L and ADX are MT5-native."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed ADX threshold and pip buffers; no ML or PnL-adaptive logic."
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 50
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 one source_id/local PDF; R2 mechanical ADX plus previous-day false-break/pending-order exit rules with plausible >2/y/symbol H1 cadence; R3 DWX FX H1/D1 data testable; R4 deterministic no ML/HR14 conflict."
---

# QM5_11405 Carter TF#11 — ADX Weak Trend + Previous Day Breakout (H1)

## Quelle
- Source: "20 Trend Following Systems" by Thomas Carter (2014), Strategy #11
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\514732392-Forex-Trend-Following-Strategy.pdf`
- Source citation: 2014 local PDF URL/path recorded above for lineage.
- R1: PASS — Named author.

## Mechanik

**Concept**: Use ADX < 35 (weakening or subdued trend) as a filter for consolidation/range conditions. In those conditions, a move below the previous day's low by 15 pips (false breakdown) followed by a recovery targets the previous day's high — and vice versa. The ADX filter ensures this is a consolidation play, not an attempt to fade a strong trend.

### Entry

**LONG** (false breakdown, then buy):
1. `ADX(14)[0] < 35` — trend is not strong (ideally ADX trending downward).
2. `Low[0] < DayLow[1] - 15 × Point` — price broke below yesterday's low by at least 15 pips.
3. Enter BUYSTOP at `DayHigh[1] + 15 × Point` — stop order 15 pips above yesterday's high.
4. If not triggered by end of day, cancel.

**SHORT** (false breakout above, then sell):
1. `ADX(14)[0] < 35`.
2. `High[0] > DayHigh[1] + 15 × Point` — price broke above yesterday's high by 15 pips.
3. Enter SELLSTOP at `DayLow[1] - 15 × Point` — stop order 15 pips below yesterday's low.
4. Cancel if not triggered by end of day.

### Exit
- TP: 60 pips (per Carter) or 2× initial risk.
- SL: ≤30 pips from entry (initial stop no more than 30 pips below/above entry).
- BE: Move to breakeven at +30 pips.

### Stop Loss
- LONG: entry - 30 pips.
- SHORT: entry + 30 pips.
- P2 cap: 40 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H1 (day-level high/low from previous daily bar)
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX
- Spread cap: 20 pips
- ADX ideally also trending downward (slope negative)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Thomas Carter, named author, published series. |
| R2 Mechanical | PASS | ADX < 35 threshold; previous day H/L computable from iHigh/iLow on D1; stop orders deterministic. |
| R3 Data Available | PASS | H1 chart with D1 H/L lookback; ADX MT5-native. |
| R4 No ML | PASS | Fixed thresholds. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Thomas Carter, Strategy #11

## Implementation Notes for Codex (P1)
- Previous day H/L: `iHigh(NULL, PERIOD_D1, 1)` and `iLow(NULL, PERIOD_D1, 1)`
- ADX: `iADX(NULL, PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 0)`
- LONG trigger (2-step): first detect `iLow(NULL, 0, 0) < prevDayLow - 15*Point`, then place BUYSTOP at `prevDayHigh + 15*Point`
- This could also be implemented on D1: detect yesterday's move > 15 pips beyond prior day's range, then set pending order
- P3 sweeps: ADX threshold (25/30/35), breakout buffer (5/10/15 pips), TP (40/60/80 pips)

## Verwandte Strategien
- Related: QM5_11409 (big-ben-london-fade) — also uses previous session range + ADX-like filter
- Differentiator: ADX < 35 explicitly filters for weak/consolidating trends; entry is a stop order beyond the OPPOSITE extreme of the day that broke out (reversal from false breakout).

## Lessons Learned
- *(populated as pipeline progresses)*
