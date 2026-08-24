---
ea_id: QM5_9932
slug: bandy-roc-zscore-normalised-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/regime-filter]]"
indicators:
  - "[[indicators/roc]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
period: D1
g0_status: APPROVED
expected_trades_per_year_per_symbol: 22
last_updated: 2026-05-24
r1_track_record: PASS
r1_reasoning: Single source_id (Bandy QTA ISBN 9780979183850 + URL); ROC and z-score are generic substrates; one canonical source per card.
r2_mechanical: PASS
r2_reasoning: ROC period, z-score lookback, entry/exit z thresholds, regime gate, ATR stop, time stop, and degenerate-denominator guard are all numeric and Codex-implementable.
r3_data_available: PASS
r3_reasoning: D1 MR strategy testable on SP500.DWX (backtest) and NDX.DWX / WS30.DWX (live-routable DWX instruments).
r4_ml_forbidden: PASS
r4_reasoning: Rolling z-score is closed-form descriptive statistics, not adaptive learning; fixed parameters, one position per magic, no ML.
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS single Bandy book source_id/ISBN attribution; R2 PASS deterministic D1 ROC z-score MR entry/exit with plausible >2 trades/year/symbol; R3 PASS SP500.DWX backtest plus NDX/WS30 fallback; R4 PASS deterministic non-ML one-position rules."
---

# Bandy ROC Z-Score Normalised MR (Long-Only Index)

## Source
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard B. Bandy, "Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management", Blue Owl Press, 2015, ISBN 9780979183850.
- Citation: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850, URL: https://books.google.com/books/about/Quantitative_Technical_Analysis.html?id=LTJJngEACAAJ
- Bandy in QTA presents the **z-score normalisation of momentum oscillators** as a way to make threshold choices comparable across instruments with very different volatility regimes. Plain ROC (Rate of Change) uses a fixed percent threshold (e.g. ROC(10) ≤ -4.0% in slug-locked QM5_9726) — but a 4% move in SP500 is a strong reversal signal while in oil it is noise. The z-score normalisation expresses the current ROC reading as standard deviations away from its rolling mean, making the threshold scale-invariant. Bandy's contribution captured here is the **rolling z-score wrap around standard ROC, combined with a 200-SMA regime gate and an ATR catastrophic stop overlay**. Distinct from slug-locked QM5_9726 (plain ROC threshold, rejected at G0) and from QM5_9912 (z-score of 5-day RETURNS, a different substrate — returns are path-dependent vs. ROC which is point-to-point).
- Substrate attribution: Rate of Change (ROC) is generic momentum oscillator (no single canonical attribution); z-score normalisation is standard descriptive statistics. Bandy's contribution is the composite definition + regime treatment + threshold calibration.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanics

Period: D1.

### Entry
On each daily close of the target instrument:
- Compute `roc10 = 100 * (close[0] - close[10]) / close[10]`.
- Compute the rolling z-score: `z = (roc10[0] - mean(roc10, 60)) / stdev(roc10, 60)`, where the mean and standard deviation are taken over the last 60 daily ROC readings.
- Compute `regime = SMA(close, 200)`.
- Long entry at next bar's open if `z <= -2.0` AND `close > regime` AND no position currently open.
- Short entry not used. Long-only construct (Bandy: short-MR on equity indices is structurally weaker — drift bias).

### Exit
- Exit when `z >= 0` (mean-revert to neutral) OR time stop OR catastrophic SL hit.
- Time stop: 8 trading days.
- P3 sweep candidates: ROC period `5 / 10 / 14`; rolling stat lookback `40 / 60 / 90`; entry threshold `z ≤ -1.5 / -2.0 / -2.5`; exit threshold `z ≥ -0.5 / 0.0 / 0.5`; ATR mult `2.0 / 2.5 / 3.0`; time stop `5 / 8 / 12`.

### Stop Loss
Catastrophic stop: long-side SL = `entry_price - 2.5*ATR(14)`, fixed for trade duration. No trailing — short-horizon MR design.

### Position Sizing
P2: fixed $1,000 risk based on initial SL distance. Live: `RISK_PERCENT` per HR4.

### Additional filters
- Skip on incomplete daily bar.
- Skip if `stdev(roc10, 60) < 0.20` (degenerate quiet-regime — z-score blows up on near-zero denominator). The `0.20` threshold is in absolute ROC-percent units.
- One position per magic.

## Target symbols
SP500.DWX (backtest-only), NDX.DWX, WS30.DWX. Equity-index MR is the canonical z-score-ROC substrate; the same construct could be ported to FX/commodities later but Bandy reports weaker statistical evidence outside indices.

## Concepts
- [[concepts/mean-reversion]] — primary
- [[concepts/regime-filter]] — secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Named Bandy book + ISBN + URL; substrate is generic ROC + descriptive statistics, attribution captured. |
| R2 Mechanical | UNKNOWN | Explicit ROC period, z-score lookback, entry/exit thresholds, regime gate, ATR catastrophic stop, time stop. |
| R3 Data Available | UNKNOWN | Daily timeframe; SP500.DWX tick history 2018-07 → 2026-05; NDX.DWX / WS30.DWX live-routable. |
| R4 ML Forbidden | UNKNOWN | Rolling z-score is closed-form descriptive statistics — precedent: QM5_9576 z-of-price (REJECTED for strategy quality, not for R4) and QM5_9912 z-of-returns (APPROVED) both passed R4 under the same rule. Fixed parameters, no ML, no martingale. |

## R3
SP500.DWX is backtest-only on the Darwinex CFD feed (no broker order routing). **Live promotion T_Live gate:** if the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. Board Advisor T_Live-gate enforcement.

## Pipeline history
- G0: 2026-05-19, PENDING, drafted from Bandy QTA Batch 8 (z-score normalisation of ROC — distinct from slug-locked QM5_9726 plain-ROC variant).

## Related strategies
- [[strategies/QM5_9576_bandy-zscore-mr-index]] — z-score of price-LEVEL (rejected for strategy quality); 9932 z-scores momentum not level.
- [[strategies/QM5_9912_bandy-zscore-returns-5d-mr-index]] — z-score of RETURNS (approved); 9932 z-scores ROC which is point-to-point momentum vs. path-summed return.
- [[strategies/QM5_9726_bandy-roc-reversal-mr-index]] — plain-ROC threshold variant (slug-locked rejected); 9932 wraps ROC in scale-invariant z-norm.

## Lessons learned (during the pipeline run)
- TBD
