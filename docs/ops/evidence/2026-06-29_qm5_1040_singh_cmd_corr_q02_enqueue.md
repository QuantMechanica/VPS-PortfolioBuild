# QM5_1040 Singh Commodity Correlation Q02 Enqueue

Date: 2026-06-29
Branch: `agents/board-advisor`

## Edge

`QM5_1040_singh-cmd-corr` implements `SRC06_S13` Part 1 only:

- Traded symbol: `CADJPY.DWX`
- Leading symbol: `XTIUSD.DWX`
- Timeframe: D1
- Logic: oil support/resistance breakout triggers next-bar CADJPY trade
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`

This is an energy-linked currency sleeve, not another outright WTI/XNG system and not an added XAU/XAG metal sleeve.

## Build Verification

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings
- `.ex5`: `framework/EAs/QM5_1040_singh-cmd-corr/QM5_1040_singh-cmd-corr.ex5`
- `build_check.ps1 -Strict`: PASS, 0 failures
- Build-check warnings: 16 inherited framework include advisories for lazy indicator handles / releases; no EA-local failure.
- Backtest setfile hash stamped:
  `ff6f92a21d58f47d335b73316747e907889ad34a35613758d498830ace51728f`

## Q02 Queue

Inserted one pending work item into `D:\QM\strategy_farm\state\farm_state.sqlite`:

- Work item id: `8d2adf87-9471-4af3-bcb5-aba5f2e0f2d6`
- Kind: `backtest`
- Phase: `Q02`
- EA: `QM5_1040`
- Symbol: `CADJPY.DWX`
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_1040_singh-cmd-corr\sets\QM5_1040_singh-cmd-corr_CADJPY.DWX_D1_backtest.set`
- Status: `pending`
- Payload host: `CADJPY.DWX` D1
- Payload leading symbol: `XTIUSD.DWX`
- Enqueued at UTC: `2026-06-28T22:25:01+00:00`

DB backup before insert:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1040_q02_enqueue_20260628T222501Z.sqlite`

No backtest was launched manually. The paced workers own Q02 execution.

## Guardrails

- Did not touch the portfolio gate.
- Did not touch the `T_Live` manifest.
- Did not toggle AutoTrading.
- Did not add metal exposure from the card's Part 2 USDX-XAUUSD variant.
