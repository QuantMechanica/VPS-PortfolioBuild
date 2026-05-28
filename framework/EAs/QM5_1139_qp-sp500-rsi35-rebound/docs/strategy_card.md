---
ea_id: QM5_1139
slug: qp-sp500-rsi35-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 verifiable Quantpedia URL/author; R2 fixed RSI threshold entry plus RSI/time-stop exit; R3 SP500.DWX backtest-only pass with T6 NDX/WS30 caveat; R4 fixed-rule no ML/grid/martingale."
expected_trades_per_year_per_symbol: 500
---

# Quantpedia RSI 35 Rebound - SP500.DWX

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Automated Trading Edge Analysis"
- URL: https://quantpedia.com/automated-trading-edge-analysis/
- Named source author: Daniela Hanicova, Quant Analyst, Quantpedia.
- Location: "Practical trading edge - Short-Term Strategies", subsection "Relative Strength Index".

## Mechanik

### Entry
On each completed D1 bar:
1. Compute RSI(14) on SP500.DWX D1 closes.
2. If RSI(14) crosses below 35 from above, open LONG SP500.DWX at the next regular cash-session open.
3. Do not add to an existing position.

### Exit
- Close when RSI(14) closes above 55.
- Time stop: close after 10 trading days if RSI has not crossed above 55.
- Safety exit: close at the next available bar if the scheduled close fails.

### Stop Loss
- Hard stop at 2.0x D1 ATR(20) from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Require 60 valid D1 closes before first signal.
- Skip if spread is greater than 3x median M30 spread over the prior 20 trading days.
- Optional P3 sweep only: RSI length 10/14/21, lower threshold 30/35, exit threshold 50/55.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/mean-reversion]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Daniela Hanicova / Quantpedia. |
| R2 Mechanical | UNKNOWN | RSI threshold entry and RSI threshold/time-stop exit are deterministic. |
| R3 Data Available | UNKNOWN | Source uses SPY; SP500.DWX is available for T1-T5 backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed indicator thresholds; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1137_qp-sp500-down-day-rebound]] - same SP500.DWX short-term mean-reversion family, but return-rank trigger.
- [[strategies/QM5_1140_qp-sp500-ma10-breakout]] - same Quantpedia article, trend trigger rather than oversold trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
