---
ea_id: QM5_11325
slug: tc-m5-9-ema50-100-macd-partial-exit
type: strategy
source_id: e78a9f1f-4e6a-563c-a080-915133d6ed28
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/ema-cascade]]"
  - "[[concepts/partial-exit]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/macd]]"
period: M5
source_citation: "Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), 5 Min Trading System #9, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf"
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-26
expected_trades_per_year_per_symbol: 36
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "EMA50/EMA100 cascade breakout with 10-pip threshold, MACD zero-cross-within-5-bar scan, 5-bar-extreme SL and 2x-risk/EMA50-trail partial exit are all deterministic and codable; gaps (e.g. exact partial split) are side-parameters Codex/P3 can default and sweep."
r3_reasoning: "Testable on EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX M5 — all standard DWX major-pair symbols with full tick history."
r4_reasoning: "Fixed-period EMA/MACD only, no adaptive or PnL-dependent parameters, no ML, no martingale; the source's 2-lot partial-exit maps to a single MT5 position with PositionClosePartial, keeping it 1-pos-per-magic compatible."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11325_tc-m5-9-ema50-100-macd-partial-exit.md"
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic EMA/MACD entry and partial-close plus EMA exit with conservative 36 trades/year/symbol; R3 testable on major-pair DWX symbols; R4 deterministic and ML-free, implemented as one position with partial volume close."
expected_pf: 1.25
expected_dd_pct: 15.0
---

# QM5_11325 TC-M5 System #9 — EMA(50/100) Cascade + MACD(12,26,9) + Partial Exit (M5)

## Quelle
- Source: "20 Forex Trading Strategies (5 Minute Time Frame)" by Thomas Carter (PDF)
- Section: 5 Min Trading System #9
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
- Author: Thomas Carter. R1 PASS.

## Mechanik

Price breaks above both EMA(50) and EMA(100) by 10+ pips. MACD(12,26,9) must have crossed positive within the last 5 bars. Two-lot entry: exit half at 2× risk (move SL to BE on remainder); exit second half when price breaks back below EMA(50) by 10 pips. Sophisticated partial-exit management.

### Entry

**LONG**:
1. Price (Close) is **above** both EMA(50) and EMA(100).
2. Price has broken above EMA(50) by **at least 10 pips**.
3. MACD(12,26,9) main crossed **above** zero within the **last 5 bars**.
4. Do NOT enter if price is between EMA(50) and EMA(100) — must be above both.
5. SL: five-bar low from entry bar.

**SHORT** (mirror):
1. Price below both EMA(50) and EMA(100), below EMA(50) by 10+ pips.
2. MACD crossed below zero within last 5 bars.
3. SL: five-bar high from entry.

### Exit
- **Half position**: exit at 2× risk (entry + 2 × SL_distance for LONG). Move SL on remainder to breakeven.
- **Remainder**: exit when price breaks **back below** EMA(50) by 10 pips.

### Stop Loss
- LONG: lowest low of last 5 bars (iLowest).
- P2: ATR(14) × 1.5 as cap.

### Position Sizing
- `RISK_FIXED = $1000` for P2 (2 lots = $500 each).
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: M5
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX
- Spread cap: 15 pips
- Between-EMA rejection: skip if Close < EMA100 or between EMA50 and EMA100

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Thomas Carter named. |
| R2 Mechanical | PASS | EMA cascade + MACD within-5-bar lookback + 2×-risk TP + EMA50 trail exit = all deterministic. |
| R3 Data Available | PASS | M5 DWX data. |
| R4 No ML | PASS | Fixed indicators. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from TC-M5 PDF, System #9

## Implementation Notes for Codex (P1)
- EMA50, EMA100: iMA PRICE_CLOSE
- 10-pip breakout: (Close[0]-ema50[0]) >= 10*_Point for LONG
- MACD within-5: scan MACD[0..4] for a negative-to-positive cross (macd[i]<=0 && macd[i-1]<=0 && macd[i+1]>0)
- 5-bar low SL: iLow(NULL,0,iLowest(NULL,0,MODE_LOW,5,1))
- Partial exit: use 2-lot system (2 separate positions with same entry); close lot 1 at entry+2*sl_dist, move lot 2 SL to entry
- Trail exit lot 2: close when price < ema50-10*_Point
- P3 sweeps: breakout threshold (5 vs 10 vs 20 pips), MACD lookback (3 vs 5 vs 7 bars), partial split (50/50 vs 33/67)

## Verwandte Strategien
- Related: QM5_11327 (tc-m5-11-mtf-4h-ema5-10) — also M5 EMA+MACD; this uses two slow EMAs + partial exit
- Differentiator: Partial-exit management and two-phase position reduce variance vs single TP

## Lessons Learned
- *(populated as pipeline progresses)*
