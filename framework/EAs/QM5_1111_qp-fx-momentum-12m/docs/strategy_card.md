---
ea_id: QM5_1111
slug: qp-fx-momentum-12m
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/currency-momentum]]"
  - "[[concepts/cross-sectional-ranking]]"
indicators:
  - "[[indicators/twelve-month-return-rank]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "Quantpedia FX-momentum 12m rank (Menkhoff/Sarno/Schmeling/Schrimpf JFE 2012 + Bianchi/Drew/Polichronis 2005): R1 verifiable Quantpedia URL + named-paper DOI 10.1016/j.jfineco.2011.10.002; R2 12mo return rank + monthly top/bottom-3 rebalance fully deterministic; R3 7/7 G10-USD DWX universe live-routa"
---

# Quantpedia Currency Momentum - 12 Month Rank

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Currency Momentum Factor"
- URL: https://quantpedia.com/strategies/currency-momentum-factor
- Named source authors / institutions: Deutsche Bank Currency Momentum USD Index; Menkhoff, Sarno, Schmeling, and Schrimpf, "Currency Momentum Strategies", Journal of Financial Economics 2012, DOI 10.1016/j.jfineco.2011.10.002, https://doi.org/10.1016/j.jfineco.2011.10.002; Bianchi, Drew, and Polichronis 2005, "A Test of Momentum Trading Strategies in Foreign Exchange Markets: Evidence from the G7", https://eprints.qut.edu.au/4011/.

## Mechanik

### Entry
At each month-end:
1. Universe: liquid DWX developed-market FX pairs quoted versus USD where history is sufficient, candidate set `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`, plus other approved G10 USD crosses if present.
2. Convert each pair into base-currency return versus USD over the prior 252 D1 bars. For USD-base pairs, invert the return so all scores represent foreign-currency appreciation versus USD.
3. Rank currencies descending by 12-month momentum.
4. Open LONG positions in the top 3 currencies versus USD.
5. Open SHORT positions in the bottom 3 currencies versus USD.

### Exit
- Close and rebalance all legs at the next month-end.
- Close any leg that leaves its long/short bucket at rebalance.

### Stop Loss
- ATR(20) hard stop at 4.0x D1 ATR from entry per leg.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per active slot.
- Live: `RISK_PERCENT = 0.25` per active slot.

### Zusaetzliche Filter
- Monthly rebalance only.
- Require at least 270 D1 bars before a pair is rank-eligible.
- Skip entry if current spread is greater than 3x the symbol's median D1 spread over the prior 20 trading days.

## Concepts
- [[concepts/currency-momentum]] - primary
- [[concepts/cross-sectional-ranking]] - secondary

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.
