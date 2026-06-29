# QM5_12781 USDJPY/AUDJPY Q02 Enqueue Evidence

Date: 2026-06-29
Branch: agents/board-advisor

## Scope

Built one non-duplicate FX market-neutral cointegration basket:
`QM5_12781_edgelab-usdjpy-audjpy-cointegration`.

This was selected as the next unbuilt rank-26 USDJPY/AUDJPY D1 pair from the
same 66-pair FX cointegration scan rerun after existing higher-ranked baskets
were already built. It is an exploratory tail candidate, not a hard-bar survivor.

## Build

- EA directory: `framework/EAs/QM5_12781_edgelab-usdjpy-audjpy-cointegration`
- Logical symbol: `QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1`
- Basket legs: `USDJPY.DWX`, `AUDJPY.DWX`
- Risk payload: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- Tester accounting: `tester_currency=USD`, `tester_deposit=100000`
- Build task: `c5c43c78-2d18-465d-9a9a-c0cc078bbd05`

## Validation

- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings.
- Card schema lint: PASS.
- SPEC validation: PASS.
- Basket symbol scope: `BASKET_OK`.

## Q02 Handoff

`farmctl record-build` auto-enqueued Q02:

- Work item: `080ebc00-3644-4719-b6e6-6f855604f6b6`
- Phase: Q02
- Status at handoff: active
- Claimed by: T2
- Setfile: `framework/EAs/QM5_12781_edgelab-usdjpy-audjpy-cointegration/sets/QM5_12781_edgelab-usdjpy-audjpy-cointegration_QM5_12781_USDJPY_AUDJPY_COINTEGRATION_D1_D1_backtest.set`
- Payload backup before enrichment: `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12781_q02_payload_20260629_154331Z.sqlite`

No `T_Live`, AutoTrading, portfolio admission, portfolio KPI, or
`q08_contribution` artifacts were touched.
