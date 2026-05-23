# Edge Lab Direction 1 Build Follow-Up Review - 2026-05-22

Task: `fccb8155-cdb2-4ca9-822c-15d209cced05`

## Scope Checked

- Cards:
  - `D:/QM/strategy_farm/artifacts/cards_review/QM5_10717_edgelab-xsec-fx-momentum.md`
  - `D:/QM/strategy_farm/artifacts/cards_review/QM5_10718_edgelab-regime-filtered-carry.md`
- Design:
  - `docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md`
- Existing basket queue wiring:
  - `tools/strategy_farm/tests/test_basket_work_items.py`
  - `farmctl.enqueue_backtest()` basket manifest branch

## Findings

- Basket queue wiring is present and covered by a focused test: one `FX8_BASKET_D1` Q02 work item is produced from `basket_manifest.json`.
- `framework/EAs/QM5_10717_edgelab-xsec-fx-momentum/` is absent.
- `framework/EAs/QM5_10718_edgelab-regime-filtered-carry/` is absent.
- No `.mq5`, `.ex5`, host setfile, or `basket_manifest.json` exists for either EA at the time of this cycle.
- The V5 framework's standard `QM_EntryRequest` / `QM_TM_OpenPosition()` path is host-symbol bound:
  - `QM_Entry.mqh` resolves prices and lots from `_Symbol`.
  - `QM_Entry()` sends `trade_req.symbol = _Symbol`.
  - A true basket EA that opens selected pair legs from one host chart therefore needs an explicit basket-order helper or carefully reviewed direct `MqlTradeRequest`/`CTrade` logic outside the normal entry helper.

## Verification

- `python -m unittest tools.strategy_farm.tests.test_basket_work_items`: PASS as part of the focused 5-test suite.
- File existence check for both target EA directories: absent.
- No MT5 terminal was started, no `T_Live` path was touched, and AutoTrading was not changed.

## Verdict

`BUILD_NOT_COMPLETED_FRAMEWORK_GAP`

The task should not be closed as a successful EA build. The safe next implementation step is to add or approve a V5 basket-order helper that can trade non-host symbols with registered magic slots, then build `QM5_10717` and `QM5_10718` against that helper and compile real `.ex5` artifacts.
