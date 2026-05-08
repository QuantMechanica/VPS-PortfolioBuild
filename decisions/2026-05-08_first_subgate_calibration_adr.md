# ADR: First Quality-Tech Sub-Gate Calibration — V5 Initial Distributions

Date: 2026-05-08
Author: Quality-Tech (c1f90ba8)
Trigger: PIPELINE_V5_SUB_GATE_SPEC.md § Recalibration Triggers items 1-3 (first V5 EA reaching P5b, P6, P7)
Evidence source: `D:\QM\reports\pipeline\QM5_1001\` (QM5_1001, generated 2026-04-27)
Status: ADOPTED — one open defect (P5b path count, tracked below)

---

## Context

QM5_1001 is the first V5 EA to complete the P3.5 → P8 pipeline run. The spec
(§ Recalibration Triggers) directs Quality-Tech to re-evaluate provisional defaults
against the first real V5 distributions. This ADR records that first-pass assessment.

All data is verified from disk (`index.json` + per-phase result files).
No invented or inferred numbers.

---

## Evidence Summary

| Phase | Verdict | Key metric(s) |
|---|---|---|
| P3.5 | PASS (post-rerun) | Baseline: FX_MAJOR; CSR rerun added COMMODITY → 2 classes |
| P5 | PASS | Clean PF=1.42, stress PF=1.11, retention=65.4% (threshold ≥50%) |
| P5b | YELLOW | strict=60%, proxy=90% — **DEFECT: run used 10 paths, not 1000** |
| P5c | REPORT_ONLY | 3/7 slices; 1 anomaly (2008Q4_GFC: PF_INVERSION + DD_SPIKE) |
| P6 | MULTI_SEED_PASS | All 5 seeds PASS, no seed PF < 1.0 |
| P7 | PASS (all 4 gates) | PBO=3.4%, DSR=0.22, MC p=0.011, FDR q=0.072, N=312 |
| P8 | MODE_SELECTED=OFF | PF=1.18, Sharpe=0.75, DD=11.1%, 210 trades |

---

## Decisions by Phase

### P7 — Statistical Validation thresholds

**Decision: RETAIN AS-IS.**

All four V5 gates cleared with meaningful headroom on a single EA:

| Gate | Threshold | QM5_1001 | Headroom |
|---|---|---|---|
| PBO | < 5% | 3.4% | 26% |
| DSR | > 0 | 0.22 | — |
| MC p-value | < 0.05 | 0.011 | 78% |
| FDR q-value | < 0.10 | 0.072 | 28% |

No threshold is being actively stressed by the single data point. Thresholds are
unchanged until a second EA runs P7 with materially different characteristics.

**Open spec item #6 (FDR scope: intra-EA vs inter-EA):** QM5_1001 confirms intra-EA
FDR is feasible. Inter-EA comparison deferred until basket ≥ 2 EAs — no change now.

### P6 — Multi-Seed acceptance rule

**Decision: RETAIN AS-IS.**

5-seed config (42, 17, 99, 7, 2026) produced a clean MULTI_SEED_PASS: all 5 pass,
no PF < 1.0. No evidence that majority-vote threshold (≥3) or any seed is problematic.

### P5 — Stress test trade-retention guard

**Decision: RETAIN AS-IS.**

Retention=65.4% is 31% above the 50% floor. The HARSH stress profile was applied
correctly. No data suggesting the guard is miscalibrated.

### P5b — Calibrated Noise paths and compliance thresholds

**Decision: CANNOT CALIBRATE FROM THIS DATA. FLAG AS DEFECT.**

The P5b run for QM5_1001 used `path_count=10`, not the spec default of 1000.
The result file confirms this: `"path_count": 10`.

Consequences:
1. The compliance percentages (strict=60%, proxy=90%) are based on 10 paths —
   too few for a stable compliance estimate. A 10-path run with 6 strict-compliant
   paths does not support confident conclusions about the 1000-path distribution.
2. `calibration_measurement_status: PENDING_MEASUREMENT` — the VPS
   slippage/latency calibration JSON has not been built. The spec (§ P5b) requires
   per-symbol cushion and recovery-fraction values from the calibration JSON.
3. The YELLOW verdict for QM5_1001 is therefore provisional — it may flip PASS or
   remain YELLOW on a proper rerun.

**P5b threshold calibration is deferred until Development:**
(a) Builds `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`
(b) Reruns QM5_1001 P5b with `--paths 1000` and the calibration JSON present.

The one-YELLOW-per-basket cap is not triggered until QM5_1001's YELLOW is confirmed
on a proper 1000-path run.

**Spec open items #1 and #2:**
- `--reject-rate-floor 0.001` — cannot confirm, calibration JSON absent.
- `min-remaining-cushion-pct` and `recovery-fraction-limit` — cannot confirm, same reason.

### P5c — Crisis slice list

**Observation only (no decision).**

Only 3 of 7 defined slices were tested. The 2008Q4_GFC slice flagged PF_INVERSION
+ DD_SPIKE (PF=0.94, DD=22.4%, 17 trades). This is expected GFC-era behavior for
most FX strategies; no automatic fail. The anomaly is already visible in the P8
OFF-mode results (DD drops from 11.1% to 8.4% in no_news mode — consistent with
a strategy that avoids crisis events in live operation).

The 4 untested slices (CHF_Removal, Brexit, COVID_Crash, LDI, SVB) represent
post-2015 crises that are equally or more relevant to DXZ live trading. P5c coverage
should be completed in any future pipeline rerun.

**Spec open item #3 (add 2025 events):** Deferred — add only after 2025 event list
is agreed between CEO + Quality-Tech. Not blocking.

### P3.5 — Broad-asset-class taxonomy

**Decision: RETAIN AS-IS.**

QM5_1001 only covered FX_MAJOR + COMMODITY. Insufficient data to evaluate splitting
FX_CROSS or merging INDEX + INDEX_DERIVATIVE (open item #4). Taxonomy unchanged.

### P10 — KS p-threshold and lookback

**Decision: DEFERRED. No V5 P10 data exists yet.**

QM5_1001 has not entered P10. KS p < 0.01 and 6-month lookback remain provisional
until the first V5 EA completes a live burn-in window.

---

## Summary of Changes to PIPELINE_V5_SUB_GATE_SPEC.md

**None.** Thresholds are retained as-is. The spec defaults are not demonstrably wrong
from one EA dataset. Calibration is deferred where data is compromised (P5b) or absent (P10).

The only durable output of this calibration round is the defect identification:
P5b path_count must be 1000 and the calibration JSON must exist before P5b results
can support threshold recalibration.

---

## Action Items

| ID | Owner | Action |
|---|---|---|
| QT-CAL-001 | Development | Fix P5b runner: enforce `--paths 1000` or fail loudly if path_count < 1000 |
| QT-CAL-002 | Development / CTO | Build `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` from VPS measurements |
| QT-CAL-003 | Pipeline-Ops | Rerun QM5_1001 P5b with corrected runner + calibration JSON; update P5b verdict |
| QT-CAL-004 | Quality-Tech | Trigger next calibration ADR after second V5 EA reaches P7, or after any P5b YELLOW is confirmed |
| QT-CAL-005 | CEO + Quality-Tech | Agree 2025 crisis-event additions for P5c slice list |

---

## References

- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P5b, P6, P7, Recalibration Triggers
- `D:\QM\reports\pipeline\QM5_1001\index.json`
- `D:\QM\reports\pipeline\QM5_1001\P5b\P5b_QM5_1001_result.json`
- `D:\QM\reports\pipeline\QM5_1001\P6\P6_QM5_1001_result.json`
- `D:\QM\reports\pipeline\QM5_1001\P7\P7_QM5_1001_result.json`
