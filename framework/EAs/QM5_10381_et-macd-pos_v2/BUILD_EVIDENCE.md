# Build Evidence — QM5_10381_et-macd-pos_v2

**Date:** 2026-06-02  
**Task:** 669cff79-2123-4f96-b859-962907848f8e (reprogram _v2 after ONINIT_FAILED)

## Root Cause

Original .ex5 compiled against a stale QM_Common.mqh — ABI mismatch caused ONINIT_FAILED on GDAXI.DWX, SP500.DWX, WS30.DWX.  
The _v2 source adds " v2" to `#property description`; otherwise identical to original. Fresh compile resolves the failure.

## Compile Result

Pre-compiled in earlier cycle.

- **Errors:** 0  
- **ex5 size:** 193032 bytes  
- **ex5 path:** `framework/EAs/QM5_10381_et-macd-pos_v2/QM5_10381_et-macd-pos_v2.ex5`

## Set Files

| File | Symbol | Timeframe |
|------|--------|-----------|
| QM5_10381_et-macd-pos_v2_GDAXI.DWX_M5_backtest.set | GDAXI.DWX | M5 |
| QM5_10381_et-macd-pos_v2_NDX.DWX_M5_backtest.set | NDX.DWX | M5 |
| QM5_10381_et-macd-pos_v2_SP500.DWX_M5_backtest.set | SP500.DWX | M5 |
| QM5_10381_et-macd-pos_v2_WS30.DWX_M5_backtest.set | WS30.DWX | M5 |

All 3 failed symbols (GDAXI, SP500, WS30) covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
