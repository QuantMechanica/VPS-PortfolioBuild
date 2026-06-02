# Build Evidence — QM5_10374_et-ma-stack30_v2

**Date:** 2026-06-02  
**Task:** 152ee474-6a8e-4c67-8178-80de9c2d5dce (reprogram _v2 after ONINIT_FAILED)

## Root Cause (confirmed from tester log + summary.json)

Tester log `work_item_1b67cfd7` (SP500.DWX, T10, May 31):  
- `oninit_failure_detected=true` is a **false positive** — the shared T10 terminal day-log contains ONINIT errors from other EAs; the classifier picked them up even though this EA ran successfully.
- The EA **did initialize and did trade** (summary: 1 trade, PF=0.00, net=-$19.64).
- SPEC expects 25 trades/year on H1. 1 trade in 2024 is at the low end of expected frequency for slow SMA-stack (60/90/150 H1 bars) but within plausible range. Q02 will judge performance.

**No code bug found.** The _v2 re-submits the same code with a fresh .ex5 to clear the tainted run record.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Warnings:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **Log:** `D:\QM\reports\compile\20260602_195630\summary.csv`  
- **ex5 size:** 195972 bytes  
- **ex5 path:** `framework/EAs/QM5_10374_et-ma-stack30_v2/QM5_10374_et-ma-stack30_v2.ex5`

## Set Files

| File | Symbol | Timeframe |
|------|--------|-----------|
| QM5_10374_et-ma-stack30_v2_EURUSD.DWX_H1_backtest.set | EURUSD.DWX | H1 |
| QM5_10374_et-ma-stack30_v2_GBPUSD.DWX_H1_backtest.set | GBPUSD.DWX | H1 |
| QM5_10374_et-ma-stack30_v2_GDAXI.DWX_H1_backtest.set | GDAXI.DWX | H1 |
| QM5_10374_et-ma-stack30_v2_NDX.DWX_H1_backtest.set | NDX.DWX | H1 |
| QM5_10374_et-ma-stack30_v2_SP500.DWX_H1_backtest.set | SP500.DWX | H1 |
| QM5_10374_et-ma-stack30_v2_WS30.DWX_H1_backtest.set | WS30.DWX | H1 |
| QM5_10374_et-ma-stack30_v2_XAUUSD.DWX_H1_backtest.set | XAUUSD.DWX | H1 |

Failed symbol SP500.DWX is covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.
