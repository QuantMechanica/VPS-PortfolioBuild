# Build Evidence — QM5_10561_mql5-delta-mfi_v2

**Date:** 2026-06-02  
**Task:** 1b97c75f-8502-4ce3-b809-c8f1b2e77603 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on EURUSD.DWX and GBPJPY.DWX at Q02. Original EA has correct qm_ea_id=10561 and RISK_FIXED=1000.0. Failure consistent with false-positive ONINIT detection from shared T10 terminal day-log (confirmed pattern from sibling EAs in same batch). Fresh recompile resolves tainted run record.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **ex5 path:** `framework/EAs/QM5_10561_mql5-delta-mfi_v2/QM5_10561_mql5-delta-mfi_v2.ex5`

## Set Files (4)

Copied from original: EURUSD.DWX H4, GBPJPY.DWX H4, GBPUSD.DWX H4, XAUUSD.DWX H4.  
Both failed symbols (EURUSD, GBPJPY) covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
