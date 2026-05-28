# QM5_1138_qp-sp500-lowvol-nextday SPEC

## Strategy

Quantpedia Low-Volatility Next-Day Edge on `SP500.DWX`.

## Card Mapping

- Entry module: after a completed D1 bar, compute 21-day close-to-close realized volatility and rank it against the previous 250 completed volatility observations. If it is in the lowest 25 observations, enter long at the next regular US cash-session open.
- Trade management module: no dynamic management beyond the initial hard ATR stop.
- Close module: close at the regular US cash-session close on the entry day by default; `strategy_holding_days` supports the P3 sweep for 1, 2, or 3 trading days.
- No-trade constraints: only `SP500.DWX`, M15/H1 charts, regular US cash-session days only, skip US full holidays and early closes, skip if spread exceeds 3x the prior 20-day median H1 spread.

## Inputs

- `strategy_vol_period_days = 21`
- `strategy_rank_lookback_days = 250`
- `strategy_lowest_count = 25`
- `strategy_min_valid_closes = 280`
- `strategy_holding_days = 1`
- `strategy_entry_hour_ny = 9`
- `strategy_entry_minute_ny = 30`
- `strategy_exit_hour_ny = 15`
- `strategy_exit_minute_ny = 55`
- `strategy_safety_exit_hour_ny = 16`
- `strategy_atr_period = 20`
- `strategy_atr_sl_mult = 1.2`
- `strategy_spread_median_mult = 3.0`
- `strategy_spread_lookback_days = 20`

## Risk

- Backtest defaults use fixed risk: `RISK_FIXED = 1000`, `RISK_PERCENT = 0`.
- Live defaults use percent risk in live setfile: `RISK_PERCENT = 0.25`, `RISK_FIXED = 0`.

## Registry

- `ea_id = 1138`
- `symbol_slot = 0`
- `symbol = SP500.DWX`
- `magic = 11380000`

## Boundaries

No external data API, ML, grid, martingale, or manual `.DWX` stripping. No backtests or pipeline phases are part of this build.
