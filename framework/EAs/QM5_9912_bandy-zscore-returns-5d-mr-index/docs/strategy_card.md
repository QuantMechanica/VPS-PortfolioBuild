---
ea_id: QM5_9912
slug: bandy-zscore-returns-5d-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/return-distribution]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 32
last_updated: 2026-05-19
r1_track_record: PASS
r1_reasoning: "Single source_id present; Bandy QTA book named with ISBN and URL; z-score-of-returns variant explicitly attributed."
r2_mechanical: PASS
r2_reasoning: "Return window, z lookback, entry/exit thresholds, time stop, and catastrophic ATR backstop are all explicit."
r3_data_available: PASS
r3_reasoning: "D1 timeframe testable on SP500.DWX (backtest), NDX.DWX, WS30.DWX; live-promotion SP500 caveat noted."
r4_ml_forbidden: PASS
r4_reasoning: "Closed-form rolling z-score with fixed lookback and thresholds (not adaptive); one position per magic; no martingale."
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS: Bandy QTA book ISBN+URL; R2 PASS: mechanical daily z-score entry/exit with 32 expected trades/year/symbol; R3 PASS: testable on SP500.DWX backtest plus NDX/WS30 caveat; R4 PASS: fixed-rule non-ML one-position-per-magic."
---

# Bandy Z-Score of 5-Day Returns Mean Reversion (Long-only Index MR)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management", Blue Owl Press, 2015, ISBN 9780979183850.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850, URL: https://books.google.com/books/about/Quantitative_Technical_Analysis.html?id=LTJJngEACAAJ
- Bandy in QTA's mean-reversion chapters distinguishes z-score of **price level** (path-dependent, drift-biased) from z-score of **rolling returns** (path-independent, drift-neutral). The returns-based variant is what Bandy advocates for US-index MR because the long-run drift biases price-level z-scores downward over time. The card mines the **5-day return z-score** variant explicitly — distinct from QM5_9576 (Batch 1, REJECTED but slug-locked) which was z-score of close-level. The 5-day return window captures the "weekly oscillation" Bandy describes as the most stable MR window on US equity indices. Long-only with 200-SMA regime overlay matches Bandy's long-only MR doctrine.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanik

Period: D1.

### Entry
On each daily close of the target instrument:
- Compute `ret5[i] = log(close[i] / close[i-5])` for `i = 0 .. 19` (last 20 returns).
- Compute `mu = mean(ret5, 20)`, `sigma = stdev(ret5, 20)`.
- Compute `z = (ret5[0] - mu) / sigma`.
- Compute `regime = SMA(close, 200)`.
- Long entry at next bar's open if `z <= -2.0` AND `close > regime`.
- Long-only (no short side — Bandy's long-only MR doctrine).

### Exit
- Primary: exit at next bar's open if `z >= 0` (returns reverted to mean).
- Time stop: exit after `8` trading days if z hasn't crossed back to zero.
- P3 sweep candidates: return window `3 / 5 / 7 / 10`; z lookback `10 / 20 / 30`; entry threshold `-1.5 / -2.0 / -2.5`; exit threshold `-0.5 / 0.0 / 0.5`; time stop `5 / 8 / 12`; regime SMA `100 / 200 / 300`.

### Stop Loss
Catastrophic backstop: `2.5 * ATR(14)` below entry price. Rarely hit because the time stop and z-recovery exits dominate. Sized so that the $1,000 P2 risk maps to a stop-distance the EA actually respects.

### Position Sizing
P2: fixed $1,000 risk based on the 2.5×ATR catastrophic stop distance. Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip on incomplete daily bar.
- One position per magic.
- Optional P3 filter: skip entries within 2 bars of a prior entry (avoid retriggering on a multi-day drawdown that's still bottoming).

## Concepts
- [[concepts/mean-reversion]] — primary
- [[concepts/return-distribution]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named Bandy book + ISBN + URL; z-score-of-returns explicitly distinguished in QTA from z-score-of-price. |
| R2 Mechanical | PASS | Explicit return window, z lookback, thresholds, exit, time stop, catastrophic ATR stop. |
| R3 Data Available | PASS | Daily timeframe; testable on SP500.DWX (backtest), NDX.DWX, WS30.DWX. Optionally FX majors / XAUUSD for breadth. |
| R4 ML Forbidden | PASS | Closed-form rolling z-score (not adaptive learning — fixed lookback, fixed thresholds). One position per magic. No martingale. Precedent: rolling z-score / percentile thresholds in prior Bandy / Connors cards were accepted as R4 PASS. |

## R3
**Live promotion T_Live gate:** SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. Board Advisor enforces this at the T_Live gate.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 6.

## Verwandte Strategien
- [[strategies/QM5_9717_bandy-pir-position-in-range-mr-index]] — PIR-based MR (different oscillator construction).
- [[strategies/QM5_9718_bandy-cumulative-rsi2-mr-index]] — multi-bar RSI(2) stack MR (oscillator-based vs. distribution-based).
- [[strategies/QM5_9719_bandy-percentrank-channel-mr-index]] — PercentRank-based MR (distribution-free vs. parametric z).

## Lessons Learned (während Pipeline-Lauf)
- TBD
