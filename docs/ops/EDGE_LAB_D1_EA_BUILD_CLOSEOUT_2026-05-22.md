# Edge Lab D1 EA Build Closeout - 2026-05-22

Task: `f8e7684d-3ec0-408e-b5a5-98d4addbf028`

## Verdict

`EDGE_D1_EAS_BUILT_Q02_ENQUEUED`

Built the two Edge Lab Direction 1 basket EAs against the V5 basket-order helper and enqueued exactly one Q02 logical basket work item for each EA.

## Built Artifacts

- `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum/QM5_10717_edgelab-xsec-fx-momentum.mq5`
- `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum/QM5_10717_edgelab-xsec-fx-momentum.ex5`
- `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum/basket_manifest.json`
- `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum/sets/QM5_10717_edgelab-xsec-fx-momentum_FX8_BASKET_D1_D1_backtest.set`
- `framework/EAs/QM5_10718_edgelab-regime-filtered-carry/QM5_10718_edgelab-regime-filtered-carry.mq5`
- `framework/EAs/QM5_10718_edgelab-regime-filtered-carry/QM5_10718_edgelab-regime-filtered-carry.ex5`
- `framework/EAs/QM5_10718_edgelab-regime-filtered-carry/basket_manifest.json`
- `framework/EAs/QM5_10718_edgelab-regime-filtered-carry/sets/QM5_10718_edgelab-regime-filtered-carry_FX8_BASKET_D1_D1_backtest.set`

## G0 / Q00

- `QM5_10717`: approved with R1-R4 pass reasoning after adding explicit source-citation and target-symbol body coverage to the review card.
- `QM5_10718`: approved with R1-R4 pass reasoning after adding explicit source-citation and target-symbol body coverage to the review card.
- Both cards remain in `D:/QM/strategy_farm/artifacts/cards_review/`; `farmctl approve-card` updated status but does not move cards that originated outside `cards_draft`.

## Q02 Queue

- `QM5_10717` review task: `83516fea-adea-46ff-abc1-ddc192218673`
- `QM5_10717` Q02 parent: `31c9c81e-7711-45b5-958c-c15f6f49c822`
- `QM5_10717` Q02 work item: `f587cbe6-478c-42cb-b4ff-94ba86130d77`
- `QM5_10718` review task: `fe2e0067-cea2-45a8-9a82-aa6f85c61876`
- `QM5_10718` Q02 parent: `d0910eaa-d30a-4792-a6d7-7a11e31ed33a`
- `QM5_10718` Q02 work item: `c730d1d0-81e5-47ab-86c8-b99776c3d969`

Each work item uses:

- `symbol = FX8_BASKET_D1`
- `host_symbol = EURUSD.DWX`
- `host_timeframe = D1`
- `portfolio_scope = basket`
- `basket_symbol_count = 28`

## Verification

- `compile_one.ps1 -Strict` PASS for `QM5_10717`, 0 errors, 0 warnings.
- `compile_one.ps1 -Strict` PASS for `QM5_10718`, 0 errors, 0 warnings.
- `build_check.ps1 -EALabel QM5_10717_edgelab-xsec-fx-momentum` PASS, 0 failures, 0 warnings.
- `build_check.ps1 -EALabel QM5_10718_edgelab-regime-filtered-carry` PASS, 0 failures, 0 warnings.
- `python -m unittest tools.strategy_farm.tests.test_basket_work_items tools.strategy_farm.tests.test_basket_order_helper_static` PASS, 3 tests.

No `T_Live` or AutoTrading setting was touched. No MT5 terminal was started manually.
