# Build Evidence — QM5_10566_mql5-ravi-hist_v2

**Date:** 2026-06-02  
**Task:** 659ff715-2026-420d-8f37-2b8b3b16bc2f (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on GBPUSD.DWX at Q03 (parameter sweep). Original EA has correct qm_ea_id=10566 and RISK_FIXED=1000.0. Q03 failure with ONINIT pattern consistent with false-positive from shared T10 day-log (same pattern as sibling EAs). Fresh recompile clears tainted record.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **ex5 path:** `framework/EAs/QM5_10566_mql5-ravi-hist_v2/QM5_10566_mql5-ravi-hist_v2.ex5`

## Set Files (54)

Includes EURUSD, GBPJPY regular setfiles + 52 GBPUSD grid sweep setfiles from Q03.  
Failed symbol GBPUSD covered (grid sweep).

## Handoff

Ready for Codex code review + Q02/Q03 pipeline enqueue.
