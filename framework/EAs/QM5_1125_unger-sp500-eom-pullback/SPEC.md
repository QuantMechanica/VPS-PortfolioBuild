# QM5_1125 Unger SP500 End-of-Month Pullback

## Source Card

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1125_unger-sp500-eom-pullback.md`
- Local build copy: `docs/strategy_card.md`
- EA id: `1125`
- Slug: `unger-sp500-eom-pullback`

## Universe

| Slot | Symbol | Role |
|---:|---|---|
| 0 | `SP500.DWX` | Primary S&P replication; backtest/research only caveat from card. |
| 1 | `NDX.DWX` | Live-routable US index port. |
| 2 | `WS30.DWX` | Live-routable US index port. |

## Timeframe

- Execution timeframe: `D1`
- Entries are evaluated once per D1 closed bar via `QM_IsNewBar()`.

## Strategy Mapping

### No-Trade

- Blocks symbols outside `SP500.DWX`, `NDX.DWX`, `WS30.DWX`.
- Optional spread cap via `strategy_spread_filter_enabled` and `strategy_max_spread_points`.
- Framework news, kill-switch, Friday close, and risk checks remain active.

### Entry

- Long only.
- Uses the prior closed D1 bar as the signal bar.
- Requires `strategy_entry_trading_days_to_month_end == 4` using weekday-count month-end logic.
- Requires the signal close to be below the prior calendar month's midpoint:
  `MONTH_LOW + strategy_midpoint_fraction * (MONTH_HIGH - MONTH_LOW)`.
- Opens at the next D1 bar market price.
- Skips if the open gap from signal close exceeds `strategy_max_gap_stop_mult * planned_stop_distance`.
- Stop is `strategy_atr_sl_mult * ATR(strategy_atr_period, D1)` below entry.

### Trade Management

- No trailing stop, break-even, pyramiding, or partial close.

### Exit

- Broker SL can close first.
- Strategy exit closes on the first trading day after the entry month changes.
- No take profit.

## Risk Contract

- Backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live sets use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT=1.0` unless portfolio construction overrides it.

## Caveat

`SP500.DWX` is included because the approved card identifies it as the primary research leg. T6 deployment must respect the card caveat: if only `SP500.DWX` passes P0-P9, deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
