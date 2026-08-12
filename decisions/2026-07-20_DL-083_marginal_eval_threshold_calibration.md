# DL-083 — Marginal-Contribution Evaluator: Evidence-Based Threshold Calibration

**Date:** 2026-07-20
**Authority:** OWNER order 2026-07-20 ("Die Korrelationsschwellen bitte evidenzbasiert
setzen"), executed by Claude. Supersedes the DL-082 placeholder values in
`tools/strategy_farm/portfolio/marginal_contribution_eval.py`.
**Evidence bundle:** `D:\QM\strategy_farm\artifacts\portfolio\marginal_contribution\threshold_calibration_20260720\`
(decision paper, pairwise/leave-one-out corr matrices, redundancy table, ΔSharpe
bootstrap, sensitivity flips).

## Calibrated values

| Key | Placeholder | Calibrated | Evidence anchor |
|---|---|---|---|
| `regime_corr_admit_max` | 0.35 | **0.15** | Sealed Final-24 book's revealed member↔rest-book regime-corr p95 = 0.143, max = 0.173; crisis-adjusted pairwise-calm p90 ≈ 0.148. The old 0.35 was 2× the book's own maximum. |
| `regime_corr_reject_min` | 0.70 | **0.40** | Q09 empirical redundancy cliff across 74 evaluations: admit-rate 0.40 in corr [0.25, 0.35), 0.00 above 0.35; max corr ever admitted = 0.263. The old 0.70 was never reached by any candidate. |
| `sharpe_delta_eps` | 0.010 | **0.020** | Block-bootstrap SE(ΔSharpe) ≈ 0.060 — the old band was ~0.17 SE, deep inside noise. Even 0.020 is < 1 SE: ΔSharpe must never be the sole admit driver (diversify + DD + ops co-gates enforce). |
| `ops_cost_floor_ann_pct` | 0.15 | **0.06** | The sealed book keeps 5 of 24 sleeves below 0.15%/yr; minimum revealed-accepted contribution = 0.063%/yr (12778/AUDUSD, which earns its slot structurally). Slippage ledger (sub-1 bps/fill) confirms ops drag ≪ floor. |

`maxdd_delta_eps_pct` (0.05) and `high_vol_quantile` (0.80) unchanged (out of scope).

## Direction and doctrine fit

Correlation gates get **stricter** (0.35→0.15 admit, 0.70→0.40 reject) while the
ops floor **loosens** (0.15→0.06). This is exactly the portfolio-first doctrine of
2026-07-19: admit many small genuine diversifiers, but reject crisis-redundancy
harder. PBO/DSR and the significance floors are untouched.

## Sensitivity (stability proof)

Across the ±0.05 grid on both corr thresholds, only 2 of 15 Spur-B decisions flip,
and only at the lower=0.10 edge. Proposed-vs-placeholder changes exactly **one**
verdict: 10848/XAUUSD ADMIT → WEAK (driven by eps_s; bootstrap P(ΔS≤0) = 45% —
a noise admit correctly demoted). Verified by re-running both boundary candidates
after the patch: 10848 → WEAK, 10814/USDJPY → ADMIT-CANDIDATE (unchanged).

## Effect on standing recommendations

- Spur-B revival package for 26.07: **10814/USDJPY and 10916/GDAXI unchanged
  (ADMIT-class)**; 10094/GDAXI unchanged; **10848/XAUUSD demoted to WEAK** and
  drops out of the admission package.
- All future marginal-contribution papers echo the calibrated values with the
  DL-083 provenance comment.

## Caveats recorded

Q09 rejects are gate-terminal (no live outcome), so the redundancy curve shows
where the gate stops admitting — the correct object for calibrating the gate,
not a realized live loss. Evaluator loaders reproduce the sealed book Sharpe
2.40915 vs 2.4091 (validation anchor holds). Admission itself remains an
OWNER gate; this DL calibrates the recommendation engine only.
