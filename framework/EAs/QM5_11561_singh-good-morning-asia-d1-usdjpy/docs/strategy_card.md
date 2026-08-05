---
ea_id: QM5_11561
slug: singh-good-morning-asia-d1-usdjpy
type: strategy
source_id: a655746e-8011-56d9-8d9b-0020a8a2ae89
sources:
  - "[[sources/singh-mario-17-proven-currency-trading-strategies]]"
concepts:
  - "[[concepts/prior-day-candle-direction]]"
  - "[[concepts/d1-open-entry]]"
indicators: []
period: D1
source_citation: "Mario Singh, '17 Proven Currency Trading Strategies' (Wiley, 2013), Strategy #17 'Good Morning Asia'. R1 PASS."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 200
g0_approval_reasoning: "R1 PASS single Singh book source_id; R2 PASS mechanical prior-day D1 direction entry with SL/TP and plausible near-daily USDJPY cadence about 200 trades/year after no-Friday filter; R3 PASS USDJPY.DWX; R4 PASS deterministic no ML and one-position compatible."
---

# QM5_11561 Singh — Good Morning Asia D1 (USDJPY)

## Quelle
- Source: Mario Singh, "17 Proven Currency Trading Strategies: How to Profit in the Forex Market" (Wiley/Bloomberg Press, 2013), Strategy #17 "Good Morning Asia."

## Mechanik

**Concept**: Prior day's candle direction sets the Asian-session bias. If the prior D1 bar was bullish, buy at the open of the next D1 bar. SL is the low of the prior-day bar (minimum 30 pips). TP is half the SL distance (0.5:1 R:R by design — author argues the high directional persistence of USDJPY justifies the adverse ratio via win rate). USDJPY only; strategy exploits Tokyo-session momentum continuation of the prior NY session.

### Entry
**LONG**: `iClose(D1,1) > iOpen(D1,1)` (prior day bullish) → Buy at open of next D1 bar (`iOpen(D1,0)`)
**SHORT**: `iClose(D1,1) < iOpen(D1,1)` (prior day bearish) → Sell at open of next D1 bar

### Exit
- **SL (LONG)**: `iLow(D1,1)`, minimum 30 pips below entry
- **SL (SHORT)**: `iHigh(D1,1)`, minimum 30 pips above entry
- **TP**: `entry - (SL_distance / 2)` for LONG; `entry + (SL_distance / 2)` for SHORT

### Stop Loss
- LONG: `MathMax(iLow(D1,1), entry - 30*pip)` → cap: use iLow(D1,1) unless that gives < 30 pips, in which case use 30 pips
- P2 cap: 80 pips (D1 swings can be large)

### Position Sizing
- `RISK_FIXED = $1000` for P2. `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1; Instruments: USDJPY.DWX only; Spread cap: 15p; No Friday entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Mario Singh — Wiley-published author, CEO First Prudential Markets, institutional affiliation. |
| R2 Mechanical | PASS | Pure OHLC: iClose/iOpen comparison for bias, iLow/iHigh for SL. No custom indicators. All MT5-native. |
| R3 Data Available | PASS | D1 USDJPY.DWX. |
| R4 No ML | PASS | Threshold only. |

## Pipeline-Verlauf
- G0: 2026-05-23 — from Mario Singh "17 Proven Currency Trading Strategies" Strategy #17

## Implementation Notes for Codex (P1)
- `double close1 = iClose(NULL,PERIOD_D1,1)`
- `double open1 = iOpen(NULL,PERIOD_D1,1)`
- `double low1 = iLow(NULL,PERIOD_D1,1)`
- `double high1 = iHigh(NULL,PERIOD_D1,1)`
- LONG trigger: close1 > open1 → enter Buy at next D1 open
- SL_raw = entry - low1; if SL_raw < 30*pip, use 30*pip as SL distance
- TP = entry - SL_distance/2 (TP closer than SL — 0.5:1 ratio)
- D1 entry at bar open: use OnTick with flag to enter only once per D1 bar
- P3 sweeps: TP ratio (0.5/1.0/1.5x SL), min SL floor (20/30/40 pips), add time filter (Tokyo hours only)

## Verwandte Strategien
- None yet identified.

## Lessons Learned
- *(populated as pipeline progresses)*
