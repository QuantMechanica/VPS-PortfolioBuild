---
ea_id: QM5_1138
slug: qp-sp500-lowvol-nextday
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/volatility-effect]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/rolling-volatility-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 verifiable Quantpedia URL/author; R2 fixed realized-volatility rank long entry and scheduled exit; R3 SP500.DWX backtest-only pass with T6 NDX/WS30 caveat; R4 fixed-rule no ML/grid/martingale."
expected_trades_per_year_per_symbol: 500
---

# Quantpedia Low-Volatility Next-Day Edge - SP500.DWX

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Automated Trading Edge Analysis"
- URL: https://quantpedia.com/automated-trading-edge-analysis/
- Named source author: Daniela Hanicova, Quant Analyst, Quantpedia.
- Location: "Practical trading edge - Short-Term Strategies", volatility variant after "Trading Based on Significant Days".

## Mechanik

### Entry
On each completed D1 bar:
1. Compute 21-day realized volatility from close-to-close D1 returns on SP500.DWX.
2. Rank today's 21-day volatility against the prior 250 completed 21-day volatility observations, excluding today.
3. If today's 21-day volatility is among the 25 lowest observations in that lookback, open LONG SP500.DWX at the next regular cash-session open.
4. Hold one active long slot only.

### Exit
- Close at the regular cash-session close of the entry day.
- P3 optional holding sweep: 1, 2, or 3 trading days.
- Safety exit: close at the next available bar if the scheduled close fails.

### Stop Loss
- Hard stop at 1.2x D1 ATR(20) from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Require 280 valid D1 closes before first signal.
- Skip if the next session is an early close or full holiday.
- Skip if spread is greater than 3x median M30 spread over the prior 20 trading days.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/volatility-effect]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Daniela Hanicova / Quantpedia. |
| R2 Mechanical | UNKNOWN | Fixed 21-day volatility, fixed 250-observation rank, bottom-25 trigger, and scheduled exit are deterministic. |
| R3 Data Available | UNKNOWN | Source uses SPY; SP500.DWX is available for T1-T5 backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed volatility-rank rule; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1137_qp-sp500-down-day-rebound]] - same Quantpedia article, return-shock trigger.
- [[strategies/QM5_1104_qp-country-bab]] - related low-risk anomaly family, but cross-sectional index beta rather than one-index realized volatility state.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
