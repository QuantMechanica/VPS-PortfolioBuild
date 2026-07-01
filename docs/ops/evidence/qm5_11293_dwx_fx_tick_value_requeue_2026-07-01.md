# QM5_11293 DWX FX Tick-Value Requeue

Date: 2026-07-01
Branch: agents/board-advisor

## Target

- EA: QM5_11293_ema5-13-fib-cross-h1
- Diverse instrument focus: USDJPY.DWX / EURJPY.DWX forex Q02 throughput
- Source failure: `ce74ea59-24ff-4e81-957f-36eb9fb7e9d9`
- Source evidence: `D:\QM\reports\work_items\ce74ea59-24ff-4e81-957f-36eb9fb7e9d9\QM5_11293\20260701_024906\summary.json`

## Diagnosis

The Q02 USDJPY.DWX run initialized on the custom `.DWX` symbol and loaded `.DWX`
history, then aborted after MT5 requested plain `USDJPY` history. This is
consistent with native `SYMBOL_TRADE_TICK_VALUE` conversion lookup for a JPY
profit-currency FX custom symbol on a USD account.

## Fix

Updated `framework/include/QM/QM_RiskSizer.mqh` so `.DWX` fiat FX symbols compute
tick value directly from contract size, tick size, and `.DWX` conversion crosses.
Non-fiat or non-DWX symbols keep the existing MT5 native tick-value path.

## Verification

- `pwsh -File framework\scripts\compile_one.ps1 -EALabel QM5_11293_ema5-13-fib-cross-h1 -Strict`
  - PASS, 0 errors, 0 warnings
- `pwsh -File framework\scripts\build_check.ps1 -EALabel QM5_11293_ema5-13-fib-cross-h1 -Strict`
  - PASS, 0 failures
  - 16 existing framework advisory warnings unrelated to this change

No additional smoke was started because fleet MT5 slots were already occupied
(`T2/T3/T4/T5/T7` active plus T_Live present).

## Requeue

- Added Q02 pending work item: `9f7266df-e6d0-45fd-ac86-6c2f133a4d2b`
- EA: `QM5_11293`
- Symbol: `USDJPY.DWX`
- Setfile: `framework\EAs\QM5_11293_ema5-13-fib-cross-h1\sets\QM5_11293_ema5-13-fib-cross-h1_USDJPY.DWX_H1_backtest.set`
- Existing pending EURJPY.DWX retry left intact: `994d5989-dac1-4146-bf88-74d820eadef7`
