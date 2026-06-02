# Build Evidence — QM5_10372_et-1005-bracket_v2

**Date:** 2026-06-02  
**Task:** 9f7ab554-88a4-4394-af06-013af3947186 (reprogram _v2 after ONINIT_FAILED on SP500.DWX)

## Root Cause (confirmed from tester log + summary.json)

Tester log `work_item_7e918e4f` (SP500.DWX, T10, May 31):  
- `oninit_failure_detected=true` is a **false positive** caused by the shared terminal day-log (T10 ran multiple EAs; ONINIT errors from other EAs appear in the same log file)
- The EA **did initialize and did trade** (summary shows 4 trades, PF=0.13, net=-$2733)
- However 4 trades/year is far below the expected 180/year per SPEC.md

**Actual failure:** Too few trades due to `strategy_max_range_atr_mult=1.5` being too tight for SP500 opening-range width. SP500 opening range (16:30–17:05 broker, ~35 min) consistently exceeds 1.5×ATR(14 M5 bars), causing `Strategy_RangeQualityOK()` to filter out most trading days.

**Fix in _v2:**
- `.mq5` source unchanged
- SP500 setfile: adds `strategy_max_range_atr_mult=3.0` + explicit US-session times for clarity
- Other symbol setfiles: unchanged (defaults will be validated by Q02)

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **ex5 size:** 194308 bytes  
- **ex5 path:** `framework/EAs/QM5_10372_et-1005-bracket_v2/QM5_10372_et-1005-bracket_v2.ex5`

## Set Files

| File | Symbol | Slot | Key Param Change |
|------|--------|------|-----------------|
| QM5_10372_et-1005-bracket_v2_SP500.DWX_M5_backtest.set | SP500.DWX | 0 | max_range_atr_mult=3.0 (was 1.5) |
| QM5_10372_et-1005-bracket_v2_NDX.DWX_M5_backtest.set | NDX.DWX | 1 | defaults |
| QM5_10372_et-1005-bracket_v2_WS30.DWX_M5_backtest.set | WS30.DWX | 2 | defaults |
| QM5_10372_et-1005-bracket_v2_GDAXI.DWX_M5_backtest.set | GDAXI.DWX | 3 | defaults |

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
