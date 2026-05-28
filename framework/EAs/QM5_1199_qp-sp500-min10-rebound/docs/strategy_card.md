---
ea_id: QM5_1199
slug: qp-sp500-min10-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/rolling-price-extreme]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "qp-sp500-min10-rebound Hanicova Quantpedia 2024 10-day rolling-low rebound, fixed-next-day exit + 2.0xATR(20) stop; R1 PASS Quantpedia URL + named author (year-tag added 2024 + accessed-2026-05-17); R2 PASS deterministic 10D-low trigger / next-day-close exit / ATR stop; R3 PASS SP500.DWX backtest-av"
---

# Quantpedia SP500 10-Day Minimum Rebound

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Automated Trading Edge Analysis" (Hanicova, Quantpedia 2024)
- URL: quantpedia.com/automated-trading-edge-analysis/
- Named source author: Daniela Hanicova, Quant Analyst, Quantpedia (accessed 2026-05-17).
- Location: "Practical trading edge - Short-Term Strategies", subsection "10-Day Minimum / Maximum".

## Mechanik

### Entry
On each completed D1 bar for `SP500.DWX`:
1. Compute the rolling 10-day minimum of D1 closes including the current completed close.
2. If today's close is equal to the rolling 10-day minimum, open LONG `SP500.DWX` at the next regular-session open.
3. Do not add if a position is already open.

### Exit
- Close after 1 trading day at the regular-session close.
- P3 may test holding until the first close above SMA(10), but P1 uses the fixed next-day exit to keep the card narrow.
- Safety exit: close at the next available bar if the scheduled close is missed.

### Stop Loss
- Hard stop: 2.0x ATR(20) D1 from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Require 60 valid D1 closes before first signal.
- Skip entries on the session before a full US market holiday.
- Spread filter: skip if spread is greater than 3x the 20-day median M30 spread.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/short-term-reversal]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Daniela Hanicova / Quantpedia. |
| R2 Mechanical | UNKNOWN | Rolling 10-day close minimum trigger and fixed next-day exit are deterministic. |
| R3 Data Available | UNKNOWN | Source uses SPY; SP500.DWX is available for T1-T5 backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed rolling-window price-extreme rule; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1197_qp-sp500-lowret-rebound]] - return-tail reversal variant from same source article.
- [[strategies/QM5_1198_qp-sp500-highret-fade]] - opposite short-side price-shock family.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
