---
ea_id: QM5_1140
slug: qp-sp500-ma10-breakout
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Quantpedia Hanicova 2024 + Faber 2007 JWM SSRN 962461 SMA(10) cross D1 mechanical R1-R4 PASS; SP500.DWX R3 backtest-only T6 caveat NDX/WS30 parallel validation"
---

# Quantpedia 10-Day MA Breakout - SP500.DWX

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Automated Trading Edge Analysis"
- URL: https://quantpedia.com/automated-trading-edge-analysis/
- Named source author: Hanicova, Daniela (2024) Quant Analyst, Quantpedia "Automated Trading Edge Analysis" — URL https://quantpedia.com/automated-trading-edge-analysis/
- Location: "Practical trading edge - Short-Term Strategies", subsection "Moving Average Based Strategies".
- Academic lineage: Faber, Mebane T. (2007) "A Quantitative Approach to Tactical Asset Allocation", Journal of Wealth Management 9(4), SSRN 962461 — same 10-month/200-day MA breakout family, ported here to D1 10-bar variant per Quantpedia article.

## Mechanik

### Entry
On each completed D1 bar:
1. Compute SMA(10) on SP500.DWX D1 closes.
2. If close crosses above SMA(10), open LONG SP500.DWX at the next regular cash-session open.
3. Do not add to an existing position.

### Exit
- Close when D1 close crosses below SMA(10).
- P3 optional variant from source: hold exactly 3 trading days after the close-above-SMA(10) trigger.
- Safety exit: close at the next available bar if the scheduled close fails.

### Stop Loss
- Hard stop at 2.0x D1 ATR(20) from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Require 60 valid D1 closes before first signal.
- Skip if spread is greater than 3x median M30 spread over the prior 20 trading days.
- Optional P3 sweep: SMA length 5/10/20 and exit mode cross-below versus fixed 3-day hold.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Daniela Hanicova / Quantpedia. |
| R2 Mechanical | UNKNOWN | SMA(10) cross entry and SMA/fixed-day exits are deterministic. |
| R3 Data Available | UNKNOWN | Source uses SPY; SP500.DWX is available for T1-T5 backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed moving-average rule; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1139_qp-sp500-rsi35-rebound]] - same Quantpedia article, mean-reversion trigger rather than trend trigger.
- [[strategies/QM5_1138_qp-sp500-lowvol-nextday]] - same SP500.DWX timing source, volatility-state trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
