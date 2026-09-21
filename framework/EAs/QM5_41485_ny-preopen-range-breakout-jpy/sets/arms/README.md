# Second frozen arm (backtest-only)

`..._USDJPY.DWX_M30_backtest_armC3.set` = arm C3 (strategy_range_bars=3) on USDJPY. It is NOT a canonical
`<label>_<SYMBOL>_<TF>_backtest.set` (the compile lane and intake-first-q02 bind only the canonical sets in `sets/`); it is enqueued
as a universe expansion (`farmctl enqueue-backtest --target-setfile`) after the C2 canary PASS. It shares magic slot 0 with C2 for
backtests only; a live deployment of both arms on one symbol needs a second registry slot (not allocated).
