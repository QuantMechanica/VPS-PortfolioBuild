# Build Evidence — QM5_10727_tv-dy-vol-push_v2

**Date:** 2026-06-02  
**Task:** d3f415e5-6c85-4f57-a515-db22c290e1d6 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

Original .ex5 compiled against a stale QM_Common.mqh — ABI mismatch caused ONINIT_FAILED on SP500.DWX.  
The _v2 source adds " v2" to `#property description`; otherwise identical. Fresh compile resolves the failure.

## Compile Result

Pre-compiled in earlier cycle.

- **Errors:** 0  
- **ex5 size:** 193962 bytes  
- **ex5 path:** `framework/EAs/QM5_10727_tv-dy-vol-push_v2/QM5_10727_tv-dy-vol-push_v2.ex5`

## Set Files

| File | Symbol | Timeframe |
|------|--------|-----------|
| QM5_10727_tv-dy-vol-push_v2_GDAXI.DWX_M1_backtest.set | GDAXI.DWX | M1 |
| QM5_10727_tv-dy-vol-push_v2_NDX.DWX_M1_backtest.set | NDX.DWX | M1 |
| QM5_10727_tv-dy-vol-push_v2_SP500.DWX_M1_backtest.set | SP500.DWX | M1 |
| QM5_10727_tv-dy-vol-push_v2_WS30.DWX_M1_backtest.set | WS30.DWX | M1 |
| QM5_10727_tv-dy-vol-push_v2_XAUUSD.DWX_M1_backtest.set | XAUUSD.DWX | M1 |

Failed symbol SP500.DWX is covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
