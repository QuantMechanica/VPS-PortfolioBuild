# Basket Order Helper Artifact - 2026-05-22

Task: `9dc09d15-0057-40f8-aec7-641e04fb0eaf`

## Scope Completed

Added `framework/include/QM/QM_BasketOrder.mqh`, a V5 helper for host-chart basket EAs that need to open positions on non-host DWX symbols.

The helper:

- Accepts an explicit basket-leg `symbol` in `QM_BasketOrderRequest`.
- Sends `trade_req.symbol = req.symbol`, not `_Symbol`.
- Preserves existing V5 controls:
  - kill switch,
  - news filter on the traded leg symbol,
  - registered magic resolution with `ea_id * 10000 + symbol_slot`,
  - duplicate-position guard by magic and symbol,
  - normal risk sizing via `QM_LotsForRisk(req.symbol, sl_points)`,
  - broker send through `QM_TradeContextSend`.
- Logs host chart and traded leg separately for evidence inspection.

## Verification

Executed:

```text
python -m unittest tools.strategy_farm.tests.test_basket_order_helper_static tools.strategy_farm.tests.test_basket_work_items
```

Result: `3 tests passed`.

The static helper test asserts the blocker directly: the helper trades `req.symbol` and does not bind orders to `_Symbol`. The existing basket work-item test confirms queue wiring still creates one `FX8_BASKET_D1` Q02 work item from a basket manifest.

## Not Completed

`QM5_10717` and `QM5_10718` were not truthfully built in this cycle. Remaining required work:

- Add magic registry rows for the two basket EAs and regenerate `QM_MagicResolver.mqh`.
- Build full `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum/` and `framework/EAs/QM5_10718_edgelab-regime-filtered-carry/` source dirs.
- Ship `basket_manifest.json` and host `FX8_BASKET_D1 / D1` setfiles.
- Compile real `.ex5` artifacts with 0 errors / 0 warnings.
- Run G0/build validation and enqueue exactly one Q02 work item per EA.
- Commit and push; push is currently blocked in the headless task by missing GitHub HTTPS credentials.

## Verdict

`BASKET_HELPER_IMPLEMENTED_EA_BUILD_PENDING`
