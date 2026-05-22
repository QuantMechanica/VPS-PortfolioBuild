# Queue Starvation Auto-Enqueue Fix

Date: 2026-05-22
Task: `5d2df835-7c8f-4f2a-81c3-ba3a193d6c04`
Status: REVIEW

## Scope

Fixed the review-approved EA queue starvation path so an `APPROVE_FOR_BACKTEST`
review attempts Q02 enqueue immediately from `farmctl record-review`. The
existing pump-side auto-enqueue remains as the idempotent backstop.

## Changes

- `tools/strategy_farm/farmctl.py`
  - `record_review_result()` now calls `enqueue_backtest(..., "P2")` when the
    review verdict is `APPROVE_FOR_BACKTEST`.
  - The command response includes `auto_p2_enqueue` with the enqueue result.
- `tools/strategy_farm/tests/test_record_review_auto_enqueue.py`
  - Covers APPROVE auto-enqueue and REJECT no-enqueue behavior.
- `framework/registry/dwx_symbol_history_ranges.csv`
  - Added 37 H4 rows mirroring H1 coverage, so H4 EAs are not filtered out
    before the terminal workers can run them.
- Generated missing D1 backtest setfiles:
  - `QM5_10021_rw-fx-abs-mom`: 5 setfiles.
  - `QM5_1555_aa-factor-ma50`: 3 setfiles.
  - `QM5_9152_chan-at-buy-on-gap`: 1 setfile.

## Real Queue Actions

P2 enqueue commands were run against the existing review tasks:

| EA | Result |
|---|---:|
| `QM5_10021` | 5 Q02 work items pending |
| `QM5_1555` | 3 Q02 work items pending |
| `QM5_9152` | 1 Q02 work item pending |
| `QM5_1383` | 14 Q02 H4 work items pending |
| `QM5_10006` | 0 work items; current blocker is W1 history unavailable for target symbols |

`QM5_10006` is no longer presenting as a non-history setfile failure in this
worktree. Its current enqueue evidence reports W1 `SYMBOL_NO_HISTORY_FOR_PERIOD`
for `EURUSD.DWX`, `GBPUSD.DWX`, `SP500.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`.
No phase verdict was inferred from that.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py`: PASS
- `python -m unittest tools.strategy_farm.tests.test_record_review_auto_enqueue tools.strategy_farm.tests.test_p2_full_dwx_fanout tools.strategy_farm.tests.test_basket_work_items tools.strategy_farm.tests.test_dwx_history_range_filter`: PASS, 9 tests
- H4 history filter spot-check:
  - `AUDUSD.DWX/H4`: not skipped, 2017-2022 available.
  - `NDX.DWX/H4`: not skipped, adjusted to 2018-2022.
  - `SP500.DWX/H4`: not skipped, adjusted to 2018-2022.

No T_Live or AutoTrading action was taken. No terminal was started manually.
