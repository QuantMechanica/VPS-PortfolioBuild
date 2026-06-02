# Build Evidence — QM5_10372_et-1005-bracket_v2

**Date:** 2026-06-02  
**Task:** 9f7ab554-88a4-4394-af06-013af3947186 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

Original .ex5 compiled against a stale QM_Common.mqh — ABI mismatch caused ONINIT_FAILED on SP500.DWX.  
The _v2 source is identical to the original except `#property description` adds " v2". Fresh compile against current headers resolves the failure.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Warnings:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **Log:** `D:\QM\reports\compile\20260602_195613\summary.csv`  
- **ex5 size:** 194308 bytes  
- **ex5 path:** `framework/EAs/QM5_10372_et-1005-bracket_v2/QM5_10372_et-1005-bracket_v2.ex5`

## Set Files

| File | Symbol | Timeframe |
|------|--------|-----------|
| QM5_10372_et-1005-bracket_v2_GDAXI.DWX_M5_backtest.set | GDAXI.DWX | M5 |
| QM5_10372_et-1005-bracket_v2_NDX.DWX_M5_backtest.set | NDX.DWX | M5 |
| QM5_10372_et-1005-bracket_v2_SP500.DWX_M5_backtest.set | SP500.DWX | M5 |
| QM5_10372_et-1005-bracket_v2_WS30.DWX_M5_backtest.set | WS30.DWX | M5 |

Failed symbol SP500.DWX is covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
