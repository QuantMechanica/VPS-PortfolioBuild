---
ea_id: QM5_1197
slug: qp-sp500-lowret-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/rolling-return-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia URL/author cited; R2 PASS bottom-25-of-250 daily-return long entry and fixed hold exit mechanical; R3 PASS SP500.DWX backtest-only with T6 NDX/WS30 caveat; R4 PASS fixed rolling-rank non-ML one-position rule."
---

# Quantpedia SP500 Low Return Rebound

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Automated Trading Edge Analysis"
- URL: quantpedia.com/automated-trading-edge-analysis
- Citation year: 2024 URL quantpedia.com/automated-trading-edge-analysis
- Named source author: Daniela Hanicova, Quant Analyst, Quantpedia.
- Location: "Practical trading edge - Short-Term Strategies", subsection "Trading Based on Significant Days".

## Mechanik

### Entry
On each completed D1 bar for `SP500.DWX`:
1. Compute the daily close-to-close return.
2. Rank today's daily return against the previous 250 completed daily returns.
3. If today's return is among the 25 lowest returns in that 250-day window, open LONG `SP500.DWX` at the next regular-session open.
4. Do not enter if an existing position for this magic number is open.

### Exit
- Close after 1 trading day at the regular-session close.
- P3 may test 2-day and 3-day fixed holding periods because the source reports those horizons.
- Safety exit: close at the next available bar if the scheduled close is missed.

### Stop Loss
- Hard stop: 2.0x ATR(20) D1 from entry.
- Gap-risk kill: close at first tradable bar if loss exceeds 2.5x planned risk.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Require at least 270 valid D1 bars before first signal.
- Skip entries on the session before a full US market holiday.
- Spread filter: skip if spread is greater than 3x the 20-day median M30 spread.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/short-term-reversal]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Daniela Hanicova / Quantpedia. |
| R2 Mechanical | UNKNOWN | Bottom-25-of-250 daily-return trigger and fixed holding-period exit are deterministic. |
| R3 Data Available | UNKNOWN | Source uses SPY; SP500.DWX is available for T1-T5 backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed rolling-rank rule; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1059_jegadeesh-stm-reversal-indices]] - weekly index reversal family.
- [[strategies/QM5_1138_qp-sp500-lowvol-nextday]] - same Quantpedia methodology article, volatility-state trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
