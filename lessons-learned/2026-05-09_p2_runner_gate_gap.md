# Lesson — P2 Runner Gate Gap: PF and DD not enforced (2026-05-09)

**Gate:** P2 Baseline Screening — G1d (PF > 1.30) and G1e (DD < 12%)  
**Issue:** QUA-1076 (P2 G1-gate enforcement audit, triggered by QUA-1060)  
**Date:** 2026-05-09  
**Author:** Quality-Tech (audit) — archived by Documentation-KM (QUA-1602)

---

## Finding

`p2_baseline.py` (`derive_verdict`, lines 163–177) and `run_smoke.ps1` (pass-criteria block,
lines 766–771) both capture `profit_factor` and `drawdown` in the summary JSON but **never
evaluate them against the G1d / G1e thresholds** (PF > 1.30, DD < 12%).

The runner's PASS decision was: `completedRunCount OK AND not globalOnInitFailure AND
tradeGatePassed AND deterministic AND not timeout AND realTicksGatePassed`. PF and DD were
written to the summary JSON (lines 724–726 of `run_smoke.ps1`) and were present in every
result artifact — but neither file ever compared them against 1.30 / 12%.

Additionally, `run_smoke.ps1` was passing the flag `-AllowMissingRealTicksLogMarker` hardcoded
(line 228 of `p2_baseline.py`), effectively bypassing the G1a (Model 4 marker) check at the
runner layer. `p2_baseline.py` re-gates correctly in `derive_verdict`, but the bypass flag
introduces ambiguity.

---

## Why it happened

The P2 phase gate specification (G1a–G1e) was defined in `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`
and `PIPELINE_PHASE_SPEC.md`, but those documents did not include a mandatory runner
implementation checklist. The runner was evolved incrementally — trade count and determinism
were implemented early, PF and DD were deferred, and the deferral was never formally tracked or
reviewed. The gap persisted across two runner files without either triggering a spec-vs-code
review.

---

## Impact

**Actual impact: zero false PASS rows.** The QUA-1076 audit checked QM5_1001 and QM5_1004:
- QM5_1001: no P2 run had ever been completed (phantom index.json from old QUAA runtime).
- QM5_1004: 207 rows, 0 PASS, 0 false positives.

The gap created **potential** for an EA with PF ≤ 1.30 or DD ≥ 12% to receive a `verdict=PASS`
row, which would have invalidated the P3–P10 downstream chain silently. The fact that no false
PASS rows exist is luck of timing (both EAs failed all other gates before reaching PF/DD
evaluation), not correctness.

A separate finding: QM5_1001's `index.json` recorded `final_verdict: "READY"` with P3.5–P8 all
marked PASS/COMPLETE (timestamps 2026-04-27), with **no P2 directory or report.csv**. This is
the same phantom-advance class identified by QUA-662 (2026-05-01) for QM5_1003. QM5_1001 must
be treated as pipeline-VOID until a valid V5 P2 run produces at least one PASS row.

---

## Corrective

**A1 (BLOCKER for next P2 run):** CTO adds PF > 1.30 and DD < 12% gate enforcement to
`p2_baseline.py` `derive_verdict` before any next P2 dispatch. No P2 PASS claim is valid
without this fix in place.

**A2 (HIGH):** CTO removes the hardcoded `-AllowMissingRealTicksLogMarker` flag from the
`invoke_run_smoke` call in `p2_baseline.py` (line 228). The G1a gate should be enforced at
the `run_smoke.ps1` level, not bypassed.

**A3 (HIGH):** Pipeline-Op adds an INVALIDATION notice to
`D:/QM/reports/pipeline/QM5_1001/index.json` and resets QM5_1001 phase state to pre-P2.

Status of these actions: as of the audit date (2026-05-09), A1 and A2 were filed as CTO
tickets; A3 was assigned to Pipeline-Op. Verification by Quality-Tech required before next P2 run.

---

## Going-forward rule

**Gate spec and runner must be verified together at every phase boundary.** Before any P2 run:
Quality-Tech confirms that every G1a–G1e condition (model4 marker, determinism, min_trades,
PF > 1.30, DD < 12%) has a corresponding `if not condition: verdict = INVALID/FAIL` branch in
`p2_baseline.py derive_verdict` with a passing smoke test. This check is mandatory regardless
of whether a P2 has been run previously on that EA.

---

## Cross-references

- `docs/ops/P2_G1_AUDIT_QM5_1001_1004_2026-05-09.md` — full audit report with evidence paths
- `framework/scripts/p2_baseline.py` — lines 163–177 (`derive_verdict`), line 228 (bypass flag)
- `framework/scripts/run_smoke.ps1` — lines 739–771 (pass criteria), 724–726 (PF/DD capture)
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` — G1a–G1e specification
- `lessons-learned/2026-05-01_codex_outage_phantom_pass_class.md` — Mode 2 (phantom PASS class),
  which is the predecessor incident that prompted the QUA-1076 gate audit
- QUA-1076 (gate enforcement audit), QUA-1060 (trigger issue), QUA-662 (phantom PASS origin)
