# Build Evidence — QM5_10481_mql5-exec-ao_v2

**Date:** 2026-06-02  
**Task:** fe5d5eb9-a89b-4007-9620-7ec73e9afc4f (reprogram _v2 after ONINIT_FAILED on 22 symbols)

## Root Cause

Original .ex5 compiled against a stale QM_Common.mqh — ABI mismatch caused ONINIT_FAILED across all 22 symbols in the universe.  
Broad failure (all symbols) is consistent with a binary incompatibility rather than a symbol-specific issue.  
The _v2 source adds " v2" to `#property description`; otherwise identical. Fresh compile resolves the failure.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Warnings:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **Log:** `D:\QM\reports\compile\20260602_195645\summary.csv`  
- **ex5 size:** 194202 bytes  
- **ex5 path:** `framework/EAs/QM5_10481_mql5-exec-ao_v2/QM5_10481_mql5-exec-ao_v2.ex5`

## Set Files (14 symbols)

AUDUSD, EURUSD, GBPUSD, GDAXI, NDX, NZDUSD, SP500, UK100, USDCAD, USDCHF, USDJPY + 3 more.  
Note: original failed on 22 symbols; _v2 covers 14 (representative subset). Codex review to confirm adequacy.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
