# QM5_11888 AUDJPY Q03 hash-refresh requeue

Date: 2026-07-01
Branch: agents/board-advisor

## Scope

- EA: `QM5_11888_lien-perfect-order-sma-stack`
- Instrument: `AUDJPY.DWX`
- Phase advanced: Q03 retry after Q02 PASS
- Work item: `52ee008c-2b8f-41ab-96ba-e82e74d0ff63`
- Parent task id: `qm5-11888-audjpy-q03-hash-refresh-requeue-20260701_084246Z-52ee008c`

## Rationale

`QM5_11888` is a structural D1 FX trend sleeve, so it is aligned with the current diversity-throughput priority. `AUDJPY.DWX` already had a Q02 PASS on work item `c49ed30d-9541-4f4a-a4d9-528856012cae`, but Q03 had 12 prior INFRA failures ending with `3630b949-32a3-4b55-bf96-9cdf9459017b`.

Before enqueue, the farm DB showed no active/pending Q03 work item and no Q03 PASS for this EA/symbol pair.

## Action

- Ran strict build check for `QM5_11888_lien-perfect-order-sma-stack`.
- Refreshed the compiled EX5 artifact.
- Stamped all generated backtest setfiles with build hash `07ff611859788a7987ba03cf049e0be0396bfb9e9ad3f887ffc3fa4336b767f0`.
- Inserted one guarded Q03 work item for `AUDJPY.DWX`.

Build evidence:

- Build check report: `D:\QM\reports\framework\21\build_check_20260701_084054.json`
- Compile log: `C:\QM\repo\framework\build\compile\20260701_084054\QM5_11888_lien-perfect-order-sma-stack.compile.log`
- Result: PASS, no fatal build-check failures
- Advisory note: report retained 16 existing framework-level DWX indicator-handle advisories in shared include files

DB evidence:

- Farm DB backup before mutation: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11888_audjpy_q03_hash_refresh_requeue_20260701_084246Z.sqlite`
- New work item status after verification: `active`
- Claimed by: `T3`
- Setfile: `C:\QM\repo\framework\EAs\QM5_11888_lien-perfect-order-sma-stack\sets\QM5_11888_lien-perfect-order-sma-stack_AUDJPY.DWX_D1_backtest.set`

## Guardrails

- No portfolio gate edits.
- No `T_Live` or AutoTrading action.
- No local MT5 backtest was started by this agent.
- Risk remains fixed-size in the queued setfile payload: `risk_fixed=1000`, `risk_percent=0`.
