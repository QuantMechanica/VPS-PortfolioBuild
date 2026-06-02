# Build Evidence — QM5_10727_tv-dy-vol-push_v2

**Date:** 2026-06-02  
**Task:** d3f415e5-6c85-4f57-a515-db22c290e1d6 (reprogram _v2 after ONINIT_FAILED)

## Root Cause (confirmed from tester log + summary.json)

Tester log `work_item_4d479d21` (SP500.DWX, T10, May 31):  
- `oninit_failure_detected=true` is a **false positive** — the shared T10 terminal day-log contains ONINIT errors from other EAs running earlier the same day.
- The EA **ran successfully**: summary shows 41 trades, PF=1.13, net profit +$3569.52. Test passed: "SP500.DWX,M1: 11844408 ticks, 175165 bars generated. Test passed in 0:03:21."
- No ONINIT error was present in the EA's own tester execution.

**No code bug found.** The _v2 re-submits with fresh .ex5 to clear the tainted run record. This EA is a strong candidate for Q02 PASS on SP500.

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
