# QT Finding: dispatch_state.json Phantom Contamination — QUA-736

**Date:** 2026-05-05  
**QT Agent:** c1f90ba8 | Run: 518089cf  
**Severity:** CRITICAL  
**Issue:** [QUA-736](/QUA/issues/QUA-736) — assigned to Pipeline-Operator

---

## Finding

`D:/QM/reports/pipeline/dispatch_state.json` `QM5_1003_v1_P2` phase matrix contains **36/36 PASS rows and `phase_verdict=PASS`** — but **21 of those rows are definitively phantom verdicts** from the invalidated 2026-05-01 zero-trade run.

---

## Evidence

### Current dispatch_state.json state (read 2026-05-05 ~15:30 CEST)

```
running: {T1:3, T2:3, T3:3, T4:3, T5:3}  (15 in-flight)
dedup entries: 15
QM5_1003_v1_P2: 36 rows, all verdict=PASS, phase_verdict=PASS
```

### 15 In-Flight Symbols (clean dispatch batch 1)

AUDCAD.DWX, AUDCHF.DWX, AUDJPY.DWX, AUDNZD.DWX, AUDUSD.DWX, CADCHF.DWX, CADJPY.DWX, CHFJPY.DWX, EURAUD.DWX, EURCAD.DWX, EURCHF.DWX, EURGBP.DWX, EURJPY.DWX, EURNZD.DWX, GBPAUD.DWX

### 21 PASS Rows Not In-Flight (phantom — never part of clean dispatch)

EURUSD.DWX, GBPCAD.DWX, GBPCHF.DWX, GBPJPY.DWX, GBPNZD.DWX, GBPUSD.DWX, **GDAXI.DWX**, JPN225.DWX, **NDX.DWX**, NZDCAD.DWX, NZDJPY.DWX, NZDUSD.DWX, UK100.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, USDNOK.DWX, USDSGD.DWX, XAGUSD.DWX, XAUUSD.DWX, XTIUSD.DWX

**Smoking gun:** `GDAXI.DWX` and `NDX.DWX` are non-canonical symbol names. Per `D:/QM/reports/pipeline/QM5_1003/P2/INVALIDATION_NOTICE.md`, the phantom run used these wrong names (canonical: `GDAXIm.DWX`, `NDXm.DWX`). These symbols cannot have real DL-054-gated verdicts.

---

## Root Cause

When Board Advisor invalidated `P2/report.csv` on 2026-05-01, only the report.csv file was overwritten with a stub. The `dispatch_state.json` was NOT cleared. The 36 phantom PASS verdicts from the zero-trade run remain in the `QM5_1003_v1_P2` phase matrix bucket.

The clean P2 dispatch (P2_clean_20260505_162204 / P2_clean_20260505_162310) writes to the SAME dispatch_state.json, but since `_upsert_matrix_row` matches rows by (symbol, terminal) — and the clean dispatch may assign different terminals than the phantom run — new rows are created without overwriting the phantom rows. The phantom PASS rows stay and the `phase_verdict` remains PASS.

---

## Impact

Pipeline-Op reading `phase_verdict=PASS` from dispatch_state.json for `QM5_1003_v1_P2` will see a PASS signal driven by phantom zero-trade data, not by real DL-054-gated runs. Advancing QM5_1003 from P2 to P3-P8 on this basis would be another phantom-PASS incident, replicating the QUA-662 failure mode.

---

## Required Fix

Pipeline-Op must reset the contaminated matrix before accepting any P2 verdict:

```python
import json

state_path = "D:/QM/reports/pipeline/dispatch_state.json"
state = json.load(open(state_path))

# Clear the contaminated bucket
bucket = state["phase_matrix_index"].get("QM5_1003_v1_P2", {})
bucket["matrix"] = []
bucket["phase_verdict"] = None
state["phase_matrix_index"]["QM5_1003_v1_P2"] = bucket

json.dump(state, open(state_path, "w"), indent=2)
print("QM5_1003_v1_P2 matrix reset. Run clean dispatch to re-populate.")
```

After reset:
1. Clean dispatch can populate matrix with DL-054-gated verdicts
2. `phase_verdict` will be set by `_refresh_phase_verdict()` only when DL-054-gated runs complete
3. QT can then review the genuine P2 verdict

---

## Verification (pre-fix)

```python
import json
state = json.load(open("D:/QM/reports/pipeline/dispatch_state.json"))
rows = state["phase_matrix_index"]["QM5_1003_v1_P2"]["matrix"]
phantom_names = {"GDAXI.DWX", "NDX.DWX"}
phantom_rows = [r for r in rows if r.get("symbol") in phantom_names]
print(f"{len(phantom_rows)} phantom rows still present (expect >0 before fix)")
```

---

## Status

- QUA-736 created and assigned to Pipeline-Operator
- This document committed to `agents/quality-tech` as audit evidence
- QT will re-review P2 phase verdict after Pipeline-Op confirms state reset + clean run completion
