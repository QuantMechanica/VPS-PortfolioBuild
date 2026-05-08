# QUA-765 — QT Audit Finding: p2_baseline.py G1 Gate Not Enforced

**Date:** 2026-05-08
**Issue:** QUA-765
**Severity:** HIGH — G1-failing runs written as PASS in report.csv
**Status:** FIXED — commit 3ff5eb22 (agents/board-advisor)
**Evidence commit (prior audit):** fc647c6b (agents/quality-tech)

---

## Bug Summary

`p2_baseline.py::derive_verdict()` had no check for `model4_log_marker_detected`.
Because `invoke_run_smoke()` unconditionally passes `-AllowMissingRealTicksLogMarker`
to `run_smoke.ps1`, runs where the real-ticks log marker is absent surface with
`result="PASS"` in their `summary.json`. `derive_verdict` then sees `result=PASS`,
skips the `reason_classes` gate entirely, checks only trade counts, and returns
`verdict=PASS` — violating DL-054 G1.

## Root Cause (Two-Layer Defect)

### Layer 1 — run_smoke.ps1 (intentional bypass, correctly documented)

`run_smoke.ps1` line 718:
```powershell
$realTicksGatePassed = $globalRealTicksMarker -or $AllowMissingRealTicksLogMarker.IsPresent
```
With `-AllowMissingRealTicksLogMarker` always present, `$realTicksGatePassed = $true`
regardless of whether the marker exists. This means `result = "PASS"` can emit even
when `model4_log_marker_detected = $false`. The flag was intended to allow p2_baseline.py
to collect run metrics even on G1-failing runs; the expectation was that p2_baseline.py
would catch the G1 failure post-hoc.

### Layer 2 — p2_baseline.py derive_verdict (bug — missing G1 check)

`derive_verdict()` (pre-fix, lines 163-174):
```python
def derive_verdict(summary: dict, min_trades: int) -> tuple[str, str, str]:
    if summary.get("result") != "PASS":       # skipped when result="PASS"
        ...
    runs = summary.get("runs") or []           # NO G1 check before this
    ...
    return "PASS", "", ...                     # G1-failing run reaches here
```

`model4_log_marker_detected` is present in the summary JSON (run_smoke.ps1 line 750)
but was never read by derive_verdict. `reason_classes=['NO_REAL_TICKS_MARKER']` was
also present but unreachable once `result="PASS"`.

## Evidence

- AUDCHF.DWX run `20260506_032435` — report.csv: PASS; summary: model4_log_marker_detected=false
- EURNZD.DWX run `20260506_023608` — report.csv: PASS; summary: model4_log_marker_detected=false
- Source: QM5_1003 smoke post-QUA-747

## Fix Applied

**Commit:** `3ff5eb22` (agents/board-advisor)
**File:** `framework/scripts/p2_baseline.py`

```diff
 def derive_verdict(summary: dict, min_trades: int) -> tuple[str, str, str]:
     if summary.get("result") != "PASS":
         reasons = summary.get("reason_classes") or ["UNKNOWN"]
         return "FAIL", "run_smoke_fail:" + ";".join(reasons), summary.get("report_dir", "")
+    # DL-054 G1: model4 real-ticks log marker is mandatory; INVALID beats all other gates.
+    if not summary.get("model4_log_marker_detected"):
+        return "INVALID", "G1_NO_REAL_TICKS", summary.get("report_dir", "")
     runs = summary.get("runs") or []
```

The G1 check is placed after the `result != "PASS"` guard (FAIL cases already handled)
but before runs/trades checks ("regardless of other fields" per CTO spec).

## Regression Tests Added

- `test_derive_verdict_g1_fail_is_invalid_regardless_of_trades` — verifies
  `model4_log_marker_detected=False` with 50 trades → INVALID, G1_NO_REAL_TICKS
- `test_derive_verdict_pass_requires_g1_marker` — verifies happy path with marker
  present → PASS

Both pass. `framework/scripts/tests/test_p2_baseline.py`.

## Gate Coverage Gap (Out of Scope for this Fix)

DL-054 defines 5 gates. The `derive_verdict` function currently only enforces:
- Gate 1 (model4 marker) — **fixed by this commit**
- Gate 4 (trade count) — enforced via `trade_count_below_min` check

Gates 2, 3, 5 are not enforced in derive_verdict. This is not a regression
introduced by this fix but a pre-existing gap. Recommend tracking as a separate
QT finding if DL-054 compliance coverage is required.

---

*Quality-Tech audit — QUA-765 close-out*
