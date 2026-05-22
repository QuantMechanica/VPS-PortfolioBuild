# MT5 Feed Depth Artifact

Date: 2026-05-22
Task: `dc67de57-47fe-4d0f-b200-5e62481e79ec`
Status: REVIEW_READY

## Change

- Added an MT5 work-item feed target of `max(20, active_factory_terminals * 2)`.
- Pump now expands latent pending Q02 parent tasks into `work_items` until pending+active backtest depth reaches the feed target.
- Auto-created review/P2 enqueue loop now uses the same feed target instead of a fixed three-EA cap.
- Existing universe discipline remains in force because expansion uses `_create_backtest_work_items`.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_mt5_feed_depth.py tools/strategy_farm/tests/test_zero_trade_prevention.py tools/strategy_farm/tests/test_p2_full_dwx_fanout.py` -> 9 passed.
- `python -m py_compile tools/strategy_farm/farmctl.py` -> PASS.
- `python tools/strategy_farm/farmctl.py health` showed `mt5_dispatch_idle` OK with `30 pending, 9 active, 20 pwsh workers, 10 fresh work_item logs`.

## Guardrails

No verdict semantics changed. Model=4 remains unchanged. No T_Live, AutoTrading, or manual `terminal64.exe` start was used.
