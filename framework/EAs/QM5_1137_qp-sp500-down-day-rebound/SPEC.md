# QM5_1137 qp-sp500-down-day-rebound

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1137_qp-sp500-down-day-rebound.md`
- Strategy family: Quantpedia Significant Down-Day Rebound on `SP500.DWX`
- Status: build-only V5 implementation; no backtests or pipeline phases run.

## Framework Alignment

- No-Trade: framework kill switch, news, Friday close, one-symbol guard, M15/H1 guard, US regular cash-session day guard, early-close skip, and spread filter.
- Entry: after a completed D1 bar, rank its close-to-close return against the previous 250 completed D1 returns. If it is in the 25 lowest returns, open one long `SP500.DWX` slot at or after the next 09:30 New York cash open.
- Management: no trailing or discretionary management; initial ATR hard stop only.
- Exit: close at the regular cash-session close of the entry day by default. `strategy_holding_days` supports the card's P3 sweep of 1, 2, or 3 trading days. Safety exit runs after 16:00 New York.

## Inputs

- `strategy_return_lookback_days=250`
- `strategy_bottom_rank_count=25`
- `strategy_min_valid_closes=260`
- `strategy_holding_days=1`
- `strategy_entry_hour_ny=9`
- `strategy_entry_minute_ny=30`
- `strategy_exit_hour_ny=15`
- `strategy_exit_minute_ny=55`
- `strategy_atr_period=20`
- `strategy_atr_sl_mult=1.5`
- `strategy_spread_median_mult=3.0`
- `strategy_spread_lookback_days=20`

## Symbols And Magic

- Slot 0: `SP500.DWX`, magic `11370000`

## Notes

- The EA uses deterministic local US cash-session and early-close logic. This is sufficient for build/P2 but should be reviewed during pipeline testing.
- The card's T6 caveat remains: `SP500.DWX` is backtest-only and live promotion requires parallel validation on a broker-routable proxy such as `NDX.DWX` or `WS30.DWX`.
