# Build Evidence — QM5_10381_et-macd-pos_v2

**Date:** 2026-06-02  
**Task:** 669cff79-2123-4f96-b859-962907848f8e (reprogram _v2 after ONINIT_FAILED)

## Root Cause (confirmed from tester log)

Tester log `work_item_12b70fbc`: `EA_MAGIC_NOT_REGISTERED: ea_id=9999 slot=0 magic=99990000`

The v1 .mq5 was built from a skeleton template and the `qm_ea_id` input was never updated:  
`input int qm_ea_id = 9999;`  ← wrong

`QM_MagicChecked(9999, 0, "SP500.DWX")` returns 0 (not registered) → `QM_FrameworkInit` returns false → INIT_FAILED.

**Fix in _v2:** `qm_ea_id = 10381` (correct). Description updated from generic skeleton text.

## Compile Result

- **Errors:** 0  
- **ex5 size:** 193032 bytes  
- **ex5 path:** `framework/EAs/QM5_10381_et-macd-pos_v2/QM5_10381_et-macd-pos_v2.ex5`

## Set Files

| File | Symbol | Slot | Timeframe |
|------|--------|------|-----------|
| QM5_10381_et-macd-pos_v2_SP500.DWX_M5_backtest.set | SP500.DWX | 0 | M5 |
| QM5_10381_et-macd-pos_v2_NDX.DWX_M5_backtest.set | NDX.DWX | 1 | M5 |
| QM5_10381_et-macd-pos_v2_WS30.DWX_M5_backtest.set | WS30.DWX | 2 | M5 |
| QM5_10381_et-macd-pos_v2_GDAXI.DWX_M5_backtest.set | GDAXI.DWX | 3 | M5 |

All 4 registered magic slots used. Strategy params use code defaults (MACD 12/26/9, stop_money=$600, session 9:30-15:30 broker).  
Note: US-index session defaults (9:30 broker) do not match actual US open (16:30 broker). Q03 parameter sweep will cover corrected times.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
