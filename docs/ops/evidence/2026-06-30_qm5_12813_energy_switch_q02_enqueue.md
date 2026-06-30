# QM5_12813 Energy Switch Q02 Enqueue Evidence

Date: 2026-06-30

## Build

- EA: `QM5_12813_eia-energy-switch`
- Source card: `strategy-seeds/cards/approved/QM5_12813_eia-energy-switch_card.md`
- Logical symbol: `QM5_12813_XTI_XNG_SEASON_SWITCH_D1`
- Host: `XTIUSD.DWX` D1
- Basket legs: `XTIUSD.DWX`, `XNGUSD.DWX`
- Risk setfile: `RISK_FIXED=1000`

## Checks

- Card schema lint: PASS
- SPEC validation: PASS
- Symbol scope: BASKET_OK
- Compile: COMPILED, 0 warnings, 0 errors
- Build check: PASS, 0 failures, 16 framework include advisories

Compile log:

`C:\QM\repo\framework\build\compile\20260630_025826\QM5_12813_eia-energy-switch.compile.log`

Build check report:

`D:\QM\reports\framework\21\build_check_20260630_025847.json`

## Q02 Queue

Work item:

`1097d28a-8dd5-4dc7-9b1e-e8cb73f2e50d`

Farm DB:

`D:\QM\strategy_farm\state\farm_state.sqlite`

Status:

`pending`

Payload scope:

`basket`

Setfile:

`C:\QM\repo\framework\EAs\QM5_12813_eia-energy-switch\sets\QM5_12813_eia-energy-switch_QM5_12813_XTI_XNG_SEASON_SWITCH_D1_D1_backtest.set`

The generic sweep enqueuer rejected underscore logical symbols by setfile filename regex, so the row was created through the farm controller's basket-aware `_create_backtest_work_items` helper. The payload includes the basket manifest, logical symbol, host symbol, host timeframe, basket symbols, and 120-minute basket timeout.

No `T_Live`, AutoTrading, live manifest, or portfolio gate file was touched.
