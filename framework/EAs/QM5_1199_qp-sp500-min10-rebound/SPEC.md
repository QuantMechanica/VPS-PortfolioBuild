# QM5_1199 qp-sp500-min10-rebound

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1199_qp-sp500-min10-rebound.md`
- Strategy family: Quantpedia SP500 10-day rolling minimum rebound on `SP500.DWX`
- Status: build-only V5 implementation; no backtests or pipeline phases run.

## Framework Alignment

- No-Trade: framework kill switch, news, Friday close, one-symbol guard, M15/H1 guard, US regular cash-session day guard, early-close skip, and spread filter.
- Entry: after a completed D1 bar, compute the rolling 10-day minimum of D1 closes including that completed close. If the completed close is equal to that minimum, open one long `SP500.DWX` slot at or after the next 09:30 New York cash open.
- Management: no trailing or discretionary management; initial ATR hard stop only.
- Exit: close after one trading day at the regular cash-session close. Safety exit runs after 16:00 New York if the scheduled close is missed.

## Inputs

- `strategy_minimum_lookback_days=10`
- `strategy_min_valid_closes=60`
- `strategy_holding_days=1`
- `strategy_entry_hour_ny=9`
- `strategy_entry_minute_ny=30`
- `strategy_exit_hour_ny=15`
- `strategy_exit_minute_ny=55`
- `strategy_atr_period=20`
- `strategy_atr_sl_mult=2.0`
- `strategy_spread_median_mult=3.0`
- `strategy_spread_lookback_days=20`

## Symbols And Magic

- Slot 0: `SP500.DWX`, magic `11990000`

## Notes

- The EA uses deterministic local US cash-session and early-close logic. This is sufficient for build/P2 but should be reviewed during pipeline testing.
- The card's T6 caveat remains: `SP500.DWX` is backtest-only and live promotion requires parallel validation on a broker-routable proxy such as `NDX.DWX` or `WS30.DWX`.
