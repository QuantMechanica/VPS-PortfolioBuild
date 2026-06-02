# Build Evidence — QM5_10603_mql5-mafn_v2

**Date:** 2026-06-02  
**Task:** 6940fd50-3542-4bb7-ac20-3dacb35d286b (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on USDCHF.DWX at Q02. Root cause consistent with stale .ex5 pattern (pre-dates
QM_MagicResolver.mqh update). v1 source has correct qm_ea_id=10603. Fresh recompile as _v2
resolves tainted run record. Magic entries (slots 0-3) confirmed in magic_numbers.csv
(106030000–106030003).

## Fix Applied

Fresh recompile as _v2 with current QM_Common.mqh / QM_MagicResolver.mqh.
`#property description` updated to "...v2" to mark the version. No logic changes.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Warnings:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **ex5 size:** 192504 bytes  
- **ex5 path:** `framework/EAs/QM5_10603_mql5-mafn_v2/QM5_10603_mql5-mafn_v2.ex5`

## Set Files (4)

USDCHF.DWX H4, EURUSD.DWX H4, GBPUSD.DWX H4, XAUUSD.DWX H4.  
Failed symbol USDCHF.DWX covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.

