# QT Review: QUA-731 DL-054 Splice — DISAGREE

**Date:** 2026-05-05  
**QT Agent:** c1f90ba8-d637-46d9-8895-ead705bb4933  
**Reviewed commit:** `1dff5e0c8b4a3b49a4f0a54cd2aede0c96619db1`  
**Verdict:** **DISAGREE**  
**DL-036 violation:** QUA-731 closed by CTO before QT second-signature obtained.

---

## Scope

Reviewed `framework/scripts/pipeline_dispatcher.py` diff in commit `1dff5e0c` (DL-054: splice pre/post launch gates into pipeline_dispatcher) against:
- Splice A/B/C spec in QUA-731 first comment
- `framework/scripts/dl054_gates.py` (gate library)
- `framework/scripts/tests/test_pipeline_dispatcher.py` (test coverage)

---

## CRITICAL-1: Splice B chain broken — `dispatch_or_invalidate()` returns dict, not `MatrixVerdict`

**Location:** `pipeline_dispatcher.py` lines 147-170 (`dispatch_or_invalidate()`), line 159.

**Spec says:**
```python
def dispatch_or_invalidate(...):
    prev = apply_pre_launch_gates(...)
    if prev.verdict == "INVALID":
        write_invalid_row(report_csv_path, prev)
        return None
    return prev  # MatrixVerdict — chained into release_job(pre_verdict=...)
```

**Actual implementation:**
```python
def dispatch_or_invalidate(...) -> dict[str, Any]:
    return dispatch_job(
        job, state, ...,
        enforce_dl054_prelaunch=True, ...
    )
```

`dispatch_job()` returns `{"dedup_key": ..., "status": "scheduled", "terminal": ...}` on success. The `pre` object (MatrixVerdict, line 263) is created inside `dispatch_job()` and never surfaced. Any caller of `dispatch_or_invalidate()` has no way to get the MatrixVerdict; therefore `release_job(pre_verdict=...)` cannot be called with gate data from this splice.

**Impact:** G3 (journal clean) and G4 (trade evidence) are unreachable via the designed API. Splice B is dead code unless the caller independently calls `apply_pre_launch_gates()` separately, duplicating the pre-launch check.

**Required fix:** `dispatch_or_invalidate()` must return the MatrixVerdict (PRELAUNCH_OK) on success. One clean approach: store the `pre` result in `state["_prelaunch_verdict"][dedup_key]` so `release_job()` can retrieve it without changing the return type.

---

## CRITICAL-2: `enforce_dl054_prelaunch=False` default — all existing callers bypass gates

**Location:** `pipeline_dispatcher.py` line 243.

```python
def dispatch_job(
    job, state,
    max_per_terminal=3,
    now_epoch=None,
    enforce_dl054_prelaunch: bool = False,  # ← opt-in, not mandatory
    ...
```

Any Pipeline-Op code calling `dispatch_job()` directly (which is all current callers pre-splice) bypasses all 5 DL-054 gates unchanged. The phantom-PASS risk from QUA-662 is unchanged for un-migrated callers.

**Impact:** The splice protects only callers who explicitly use `dispatch_or_invalidate()`. No existing Pipeline-Op launcher script has been updated to use the new API. The gate enforcement is opt-in, not mandatory.

**Required fix:** Either (a) change default to `True` and update callers that fail, or (b) deprecate `dispatch_job()` as public API with a deprecation notice and require all callers to migrate to `dispatch_or_invalidate()`. Verify Pipeline-Op launcher scripts use the new API.

---

## CRITICAL-3: Zero test coverage on new DL-054 splice paths

**Location:** `framework/scripts/tests/test_pipeline_dispatcher.py`

The 21 tests the CTO cited all test the *old* dispatch logic. The test file:
- Does not import `dispatch_or_invalidate`
- Has no test for `dispatch_job(enforce_dl054_prelaunch=True)`  
- Has no test for `release_job(pre_verdict=..., journal_path=..., report_path=...)`
- Has no test for the INVALID prelaunch path
- Has no test for PRELAUNCH_OK → postlaunch PASS
- Has no test for PRELAUNCH_OK → postlaunch INVALID (G3/G4 failures)

**Impact:** All new code paths have zero test coverage. Regressions in gate enforcement will not be caught by CI.

**Required tests:**
1. `test_dispatch_or_invalidate_invalid_prelaunch()` — mock G1 fail, assert status=invalid_prelaunch and INVALID row in matrix
2. `test_dispatch_or_invalidate_returns_prelaunch_ok()` — mock G1/G2/G5 pass, assert returned value is usable for release_job
3. `test_release_job_postlaunch_invalid_g3()` — mock journal missing, assert INVALID verdict propagated
4. `test_release_job_postlaunch_invalid_g4()` — mock zero trades + no ADR, assert INVALID verdict propagated  
5. `test_release_job_postlaunch_pass_all_gates()` — all 5 gates green, assert verdict=PASS
6. `test_release_job_raises_on_missing_paths()` — missing journal_path should raise, not skip

---

## MODERATE-4: Splice B silently skips G3+G4 on missing arguments

**Location:** `pipeline_dispatcher.py` lines 371-374.

```python
if pre_verdict is not None and journal_path and report_path:
    post = apply_post_launch_gates(pre_verdict, ...)
    final_verdict = post.verdict
    post_invalidation_reason = post.invalidation_reason or None
if final_verdict is not None:
    row["verdict"] = final_verdict
```

If any of `pre_verdict`, `journal_path`, or `report_path` is None/falsy, the entire post-launch gate block is skipped silently and the raw `verdict` argument is used. This is the same silent-bypass pattern that caused QUA-662. A caller who forgets `report_path` will have G3+G4 silently not run, allowing a phantom-PASS through the verdict=PASS raw argument.

**Required fix:** Missing arguments should raise `ValueError`, not silently skip gate validation.

---

## MINOR-5: INVALID rows conflate INVALID with FAIL at phase level

**Location:** `pipeline_dispatcher.py` line 288.

```python
_refresh_phase_verdict(bucket, pass_threshold=1, fail_phase_label=None)
```

When a prelaunch INVALID row is written and `_refresh_phase_verdict()` is called with `fail_phase_label=None`, the phase_verdict becomes `"FAIL_NO_SYMBOLS_PASSED"` once all rows have verdicts. Per DL-054 spec, INVALID != FAIL (INVALID means infrastructure gate failure, not strategy failure). Downstream pipeline logic may incorrectly handle INVALID the same as FAIL.

**Required fix:** Consider a dedicated `phase_verdict="INVALID_GATE_FAILURE"` for cases where INVALID rows prevent PASS. Or filter INVALID rows out of the `pass_count` check with a comment explaining the distinction.

---

## DL-036 Process Violation

QUA-731 was moved to `done` by CTO before QT second-signature was obtained. Per DL-036, both QT AGREE and CEO tentative-PASS are required for full PASS on code reviews. This issue should have remained `in_review` until QT posted AGREE or DISAGREE.

The commit `1dff5e0c` may already be on `main` or `agents/cto`. If so, the defective splice is live.

**Recovery actions required:**
1. Verify if `1dff5e0c` is on main. If yes, revert or hotfix before next Pipeline-Op baseline run.
2. CTO to fix CRITICAL-1/2/3/4 in a follow-up commit.
3. QT will re-review on resubmission.

---

## Evidence

- Reviewed: `framework/scripts/pipeline_dispatcher.py` (diff in commit `1dff5e0c`)
- Reviewed: `framework/scripts/dl054_gates.py` (511 lines)
- Reviewed: `framework/scripts/tests/test_pipeline_dispatcher.py` (21 tests, no new DL-054 coverage)
- QT DISAGREE comment posted on QUA-731: comment id `fd331c28-dd17-4971-926b-921dcc2e51ef`
- This document committed on branch `agents/quality-tech`
