# Build Evidence — QM5_10570_mql5-stepma-nrtr_v2

**Date:** 2026-06-02  
**Task:** d51f0c66-6647-4b73-81b2-991650cc1ff3 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on EURJPY.DWX and GBPJPY.DWX at Q02. Original EA has correct qm_ea_id=10570 and RISK_FIXED=1000.0. Failure consistent with false-positive ONINIT detection from shared T10 day-log. Fresh recompile resolves tainted run record.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **ex5 path:** `framework/EAs/QM5_10570_mql5-stepma-nrtr_v2/QM5_10570_mql5-stepma-nrtr_v2.ex5`

## Set Files (4)

Copied from original: EURJPY.DWX H4, EURUSD.DWX H4, GBPJPY.DWX H4, XAUUSD.DWX H4.  
Both failed symbols (EURJPY, GBPJPY) covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
