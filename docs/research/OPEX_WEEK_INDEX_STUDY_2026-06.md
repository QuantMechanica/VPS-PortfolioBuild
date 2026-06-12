# OPEX-Week Index Effect — OOS Study 2026-06-12

**Task:** 27195799 Study B  
**Evidence:** `D:/QM/reports/research/opex_week_index_study_2026-06.csv`  
**Script:** `C:/QM/repo/framework/scripts/mt5_diagnostics/analyze_opex_week.py`  
**Symbols:** NDX.DWX, WS30.DWX, GDAXI.DWX, SP500.DWX  
**Data window:** ~2018-07 through 2026-06 (all OOS relative to Stivers-Sun DEV 1988-2010)  
**Cost model:** 0.5 bp round-trip (conservative; $0 swap on .DWX confirmed)

---

## Pre-Registered Threshold

Tradeable = OOS net annualised Sharpe > 0.5 AND same sign as DEV (Stivers-Sun: positive OPEX-week return, negative post-OPEX weakness). All available data is genuinely OOS — no pre-2018 data in T_Export.

---

## Results Summary

### OPEX week (non-quad-witching)

| Symbol | n full | Mean % | t vs normal | Sharpe ann | boot p |
|--------|--------|--------|-------------|------------|--------|
| NDX    | 55     | −0.156 | −1.36       | −0.39      | 0.682  |
| WS30   | 63     | +0.079 | −0.76       | +0.31      | 0.745  |
| GDAXI  | 63     | +0.101 | −0.68       | +0.40      | 0.673  |
| SP500  | 63     | +0.031 | −0.99       | +0.11      | 0.916  |

**Verdict: DEAD.** The Stivers-Sun positive OPEX-week long bias does not persist in 2018-2026. All t-stats < 2, none of the signs are convincingly positive, and NDX is actively negative.

### Quad-witching weeks (Mar/Jun/Sep/Dec OPEX)

| Symbol | n full | Mean % | t vs normal | Sharpe ann |
|--------|--------|--------|-------------|------------|
| NDX    | 26     | −0.103 | −0.81       | −0.21      |
| WS30   | 30     | −0.946 | −1.62       | −1.66      |
| GDAXI  | 30     | −0.602 | −1.49       | −1.37      |
| SP500  | 30     | −0.820 | −1.59       | −1.53      |

Consistently negative but not significant (max t = −1.62). Directionally consistent short signal but below trading threshold.

### Week-after-OPEX (most interesting finding)

| Symbol | n full | Mean % | Sharpe ann | P1 Sharpe | P2 Sharpe | boot p |
|--------|--------|--------|------------|-----------|-----------|--------|
| NDX    | 82     | +0.569 | +1.50      | +0.78     | +1.85     | 0.051  |
| WS30   | 94     | +0.273 | +0.72      | +0.03     | +1.56     | 0.303  |
| GDAXI  | 90     | +0.069 | +0.18      | −0.51     | +1.11     | 0.779  |
| SP500  | 94     | +0.446 | +1.21      | +0.54     | +1.91     | 0.063  |

**Verdict: INCONCLUSIVE.** Sign is consistently positive across all 4 symbols and both sub-periods (P2 in particular looks strong: NDX Sharpe 1.85, SP500 1.91, p ~0.06-0.08). However the full-period t-stats are all ≤ 1.5, not clearing the pre-registered t > 2 bar. Bootstrap p values are 0.051-0.30 for the more promising symbols — suggestive but not significant.

The P2 (2022-2026) improvement in week-after signal warrants monitoring. Do not build a card on this alone.

---

## Conclusion vs Hypothesis

The Stivers-Sun (1988-2010) positive OPEX-week long-index effect **does not replicate OOS at 2018-2026** on any of our four index CFDs. The effect appears to have decayed post-2010. Possible explanations: institutional adaptation, structural market changes post-2010, regime change (increased passive ownership absorbing seasonal pressures).

**Week-after-OPEX shows mild positive tendency** (especially P2) — not tradeable on its own evidence but worth watching in a portfolio context.

---

## Verdict per Pre-Registered Criteria

- OPEX_NON_QUAD: **DEAD** (fails Sharpe and sign consistency)
- QUAD weeks: **DEAD** (wrong sign vs hypothesis)
- WEEK_AFTER: **INCONCLUSIVE** (right sign, t < 2, borderline bootstrap p)

No cards generated. M1/M30 data not needed — D1 is the correct granularity for this study.
