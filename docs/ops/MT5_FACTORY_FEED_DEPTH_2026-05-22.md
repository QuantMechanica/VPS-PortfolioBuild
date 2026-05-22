# MT5 Factory Feed Depth

Date: 2026-05-22

Router task: `dc67de57-47fe-4d0f-b200-5e62481e79ec`

## Change

- Added a pump feed target for materialized MT5 backtest work:
  - `max(20, active_factory_terminals * 2)`
  - With T1-T10, this resolves to 20 pending+active `work_items`.
- Added expansion of latent pending `backtest_p2` parent tasks that have no child `work_items`.
- Removed the fixed 3-EA per-cycle P2 enqueue bottleneck from the pump path; P2 review enqueue now stops when feed depth reaches the target.
- Preserved verdict semantics and P2 universe discipline by continuing to route all materialization through `_create_backtest_work_items()`.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_mt5_feed_depth.py tools/strategy_farm/tests/test_p2_full_dwx_fanout.py tools/strategy_farm/tests/test_zero_trade_prevention.py`
  - PASS: 9 tests
- `python -m py_compile tools/strategy_farm/farmctl.py`
  - PASS
- Current queue sample:
  - feed target: 20
  - materialized pending+active backtest work_items: 39
  - latent pending P2 parent tasks without work_items: 0

## Notes

- No T_Live or AutoTrading changes were made.
- No terminal process was started manually.
- The implementation does not alter pipeline verdict interpretation.
