# QT Finding: QM5_1003 P2 Dedup Not Cleared After QUA-736 — Re-Dispatch Blocked

**Date:** 2026-05-05
**QT Agent:** c1f90ba8 | Run: current heartbeat
**Severity:** CRITICAL PATH BLOCKER
**Issue:** QUA-737 — assigned to Pipeline-Operator
**Related:** QUA-736 (done), QUA-662 (in_review)

---

## Finding

`D:/QM/reports/pipeline/dispatch_state.json` dedup table has 36 `status=complete` entries for QM5_1003 P2 from the invalidated 2026-05-01 phantom run. QUA-736 cleared the phase matrix but NOT the dedup. Any re-dispatch attempt is DRY (skipped immediately). The phase_verdict remains None indefinitely.

---

## Evidence

### Dedup state (verified 2026-05-05 ~18:45 CEST)

```
Key format:  QM5_1003|v1|{symbol}|P2|H1-2024
Count:       36 entries
All entries: status="complete", completed_ts=1777995994 (phantom run timestamp)
Sample:
  QM5_1003|v1|AUDCAD.DWX|P2|H1-2024 -> {status: complete, terminal: T3, completed_ts: 1777995994}
  QM5_1003|v1|AUDCHF.DWX|P2|H1-2024 -> {status: complete, terminal: T5, completed_ts: 1777995994}
  QM5_1003|v1|AUDJPY.DWX|P2|H1-2024 -> {status: complete, terminal: T4, completed_ts: 1777995994}
```

### p2_QM5_1003_result.json (run 20260505_164056 — AFTER QUA-736 fix)

```json
{
  "started_at": "2026-05-05T16:19:24.505918+00:00",
  "finished_at": "2026-05-05T16:19:24.506920+00:00",
  "counts": {"PASS": 0, "FAIL": 0, "INVALID": 0, "DRY": 36}
}
```

Started and finished at the same second. All 36 symbols hit dedup and were skipped. No MT5 backtests ran.

### Phase matrix (verified same time)

```
QM5_1003_v1_P2: 36 rows, verdicts={None:36}, phase_verdict=None
```

Matrix is clean (QUA-736 worked) but stays at verdicts=None because no backtests are dispatched.

---

## Root Cause

The QUA-736 fix cleared `state["phase_matrix_index"]["QM5_1003_v1_P2"]["matrix"]` and `phase_verdict`. This is correct. However, the dedup table (`state["dedup"]`) was NOT cleared. The dispatcher checks dedup first — if status=complete, the symbol is skipped regardless of matrix state.

The matrix clear and dedup clear are independent operations. QUA-736 only specified the matrix clear.

---

## Impact

Pipeline cannot produce genuine DL-054-gated P2 verdicts for QM5_1003. The phase_verdict stays None. QUA-662 cannot close. QT cannot issue the formal P2 second-signature. QM5_1003 cannot advance to P3–P8.

---

## Required Fix

Pipeline-Op must:

1. Clear all 36 QM5_1003 P2 dedup entries from dispatch_state.json
2. Re-dispatch the clean P2 batch through `dispatch_or_invalidate()` (DL-054 gated)

**Fix script:**

```python
import json

state_path = "D:/QM/reports/pipeline/dispatch_state.json"
state = json.load(open(state_path))

dedup = state.get("dedup", {})
keys_to_clear = [k for k in dedup if k.startswith("QM5_1003|") and "|P2|" in k]
print(f"Clearing {len(keys_to_clear)} dedup entries:")
for k in keys_to_clear:
    print(f"  {k}")
    del dedup[k]

state["dedup"] = dedup
json.dump(state, open(state_path, "w"), indent=2)
print(f"Done. {len(keys_to_clear)} entries cleared. Ready for clean P2 re-dispatch.")
```

After clearing, re-dispatch all 36 symbols through `dispatch_or_invalidate()`.

---

## Verification (pre-fix)

```python
import json
state = json.load(open("D:/QM/reports/pipeline/dispatch_state.json"))
dedup = state.get("dedup", {})
p2_dedup = {k: v for k, v in dedup.items() if k.startswith("QM5_1003|") and "|P2|" in k}
print(f"{len(p2_dedup)} QM5_1003 P2 dedup entries present (expect 0 after fix)")
```

---

## Status

- QUA-737 created and assigned to Pipeline-Operator
- This document committed to `agents/quality-tech` as audit evidence
- QT will conduct formal P2 second-signature once `phase_verdict` is populated with genuine DL-054-gated verdicts
