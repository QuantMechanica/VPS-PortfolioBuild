---
ea_id: QM5_11355
slug: robo-psar-cci
type: strategy
source_id: ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/multi-timeframe]]"
  - "[[concepts/cci-trend-filter]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/cci]]"
  - "[[indicators/psar]]"
period: M5
source_citation: "RoboForex, Strategy Scalping with use of Parabolic SAR + CCI, Recommended timeframes M1, local PDF: C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 600
g0_approval_reasoning: "R1 PASS single source_id/local RoboForex PDF; R2 PASS deterministic PSAR+EMA+CCI entry and TP/EMA SL with plausible M5 scalp cadence; R3 PASS DWX forex M5 symbols; R4 PASS deterministic no ML."
---

# QM5_11355 RoboForex PSAR + CCI MTF Scalp (M1/M5)

## Quelle
- Source: RoboForex Strategy Collection, "Strategy Scalping with use of Parabolic SAR + CCI"
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf`
- Citation: RoboForex, "Strategy Scalping with use of Parabolic SAR + CCI", local PDF archive path above, accessed 2026; URL unavailable (local PDF).
- Author: RoboForex (institutional). R1 CONDITIONAL.

## Mechanik

Multi-timeframe scalp: EMA(50) on M1 + EMA(21) on M5 provide dual-TF trend context. CCI(45) as momentum filter. PSAR(0.02,0.2) as directional trigger. LONG when PSAR is above EMA and CCI > 100 (momentum up). Source says M1 recommended but P2 uses M5 for DWX data availability.

### Entry

**LONG** (all simultaneously on M5):
1. PSAR(0.02,0.2) **below** current close (PSAR below = bullish).
2. EMA(50, M5) **below** close AND EMA(21, M5) **below** close (price above both EMAs).
3. CCI(45) **above 100** — impulse momentum.
4. Enter BUY at next bar open.

**SHORT** (mirror):
1. PSAR above close (bearish PSAR).
2. Close below EMA(50,M5) and EMA(21,M5).
3. CCI(45) **below −100**.
4. Enter SELL.

Note: Source says "PSAR above EMA's line" for LONG — interpreted as PSAR below price but above EMA; implementing as price above both EMAs + PSAR below price.

### Exit
- TP: EURUSD 10 pips, AUDUSD 7 pips, GBPUSD 12 pips (midpoints of given ranges).
- SL: EMA(21,M5) level.
- P2: fixed 10 pips TP, EMA21 distance as SL.

### Stop Loss
- Dynamic: EMA(21,M5) distance from entry.
- Maximum: 15 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: M5 (adapted from M1 source)
- Instruments: EURUSD.DWX, AUDUSD.DWX, GBPUSD.DWX
- Spread cap: 3 pips
- Session: London + NY (13:00–22:00 GMT)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Institutional RoboForex named. |
| R2 Mechanical | PASS | PSAR position, EMA position, CCI threshold — all binary deterministic. |
| R3 Data Available | PASS | M5 DWX; standard indicators. |
| R4 No ML | PASS | Fixed-period indicators. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from RoboForex strategy collection PDF page 1

## Implementation Notes for Codex (P1)
- PSAR: iSAR(NULL,0,0.02,0.2,0) — below Close[0] = bullish
- EMA21,M5: iMA(NULL,PERIOD_M5,21,0,MODE_EMA,PRICE_CLOSE,0)
- EMA50,M5: iMA(NULL,PERIOD_M5,50,0,MODE_EMA,PRICE_CLOSE,0)
- CCI(45): iCCI(NULL,0,45,PRICE_TYPICAL,0) — note unusual period 45
- SL: dynamic = EMA21 value at entry time
- P3 sweeps: CCI period (30 vs 45 vs 60), TF (M5 vs M15), EMA periods (21/50 vs 20/55)

## Verwandte Strategien
- Related: QM5_11347 (rbt-adx-momentum-m5) — also M5 trend scalp with directional filter
- Differentiator: PSAR as trigger instead of EMA cross; CCI(45) unusual period as momentum gate

## Lessons Learned
- *(populated as pipeline progresses)*
