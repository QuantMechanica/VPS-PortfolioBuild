# 1d72d68a Intraday DD Capture Evidence - 2026-06-30

Task: `1d72d68a-d6e5-47ca-ba37-f668e5c1a801`

## Scope

- `framework/include/QM/QM_Common.mqh` / `QM_KillSwitch.mqh` at current `HEAD` carry the in-memory per-position MAE tracker:
  - keyed by MT5 `POSITION_IDENTIFIER` / `DEAL_POSITION_ID`
  - updated from the existing per-tick `QM_KillSwitchCheck()` path
  - no per-tick log emission
  - `TRADE_CLOSED` emits `entry_time` and `mae_acct`
- `tools/strategy_farm/portfolio/portfolio_common.py` now parses `entry_time` and `mae_acct` into `Trade`, defaulting to `None` for legacy streams.
- `tools/strategy_farm/tests/test_portfolio_common.py` covers new-field and legacy-row parsing.

Field semantics:

- `entry_time`: epoch seconds for the position entry time.
- `mae_acct`: running minimum floating PnL in account currency, emitted once on close. Values are zero or negative.

## Verification

- `python -m py_compile tools\strategy_farm\portfolio\portfolio_common.py tools\strategy_farm\tests\test_portfolio_common.py`
  - PASS
- `python -m pytest tools\strategy_farm\tests\test_portfolio_common.py tools\strategy_farm\tests\test_portfolio_q08_contribution.py -q`
  - PASS, `10 passed`
- `python -m pytest tools\strategy_farm\tests\test_portfolio_common.py tools\strategy_farm\tests\test_portfolio_correlation.py tools\strategy_farm\tests\test_prop_challenge_sim.py -q`
  - PASS, `9 passed`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File framework\scripts\compile_one.ps1 -EALabel QM5_10000_ff-tasayc-cci-breakout -Strict`
  - PASS, 0 errors, 0 warnings
  - Compile log: `C:\QM\repo\framework\build\compile\20260630_192404\QM5_10000_ff-tasayc-cci-breakout.compile.log`
  - Summary: `D:\QM\reports\compile\20260630_192404\summary.csv`
  - Output: `C:\QM\repo\framework\EAs\QM5_10000_ff-tasayc-cci-breakout\QM5_10000_ff-tasayc-cci-breakout.ex5`

## Runtime Stream Note

No fresh Q08 backtest was started from this headless orchestration cycle because the cycle rules prohibit manual `terminal64.exe` starts and require not interfering with active T1-T10 backtests. Existing Common `q08_trades` streams were checked for `"entry_time"` / `"mae_acct"` and no current stream contained the new fields, so live stream proof remains the next pipeline/runtime verification item.

No `T_Live` or AutoTrading setting was changed.
