# QM5_1140 Quantpedia SP500 MA10 Breakout

## Source Card

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1140_qp-sp500-ma10-breakout.md`
- Local build copy: `docs/strategy_card.md`
- EA id: `1140`
- Slug: `qp-sp500-ma10-breakout`

## Universe

| Slot | Symbol | Role |
|---:|---|---|
| 0 | `SP500.DWX` | Primary research/backtest symbol from the approved card. |
| 1 | `NDX.DWX` | Parallel-validation candidate for T6 live promotion caveat. |
| 2 | `WS30.DWX` | Parallel-validation candidate for T6 live promotion caveat. |

## Timeframe

- Execution timeframe: `M15`
- Signal timeframe: `D1`
- M15 is used to execute the D1 close signal at the next regular US cash open (`09:30` New York).

## Strategy Mapping

### No-Trade

- Blocks symbols outside `SP500.DWX`, `NDX.DWX`, `WS30.DWX`.
- Blocks non-`M15` charts to preserve the cash-open execution contract.
- Blocks non-regular US cash days using deterministic NYSE holiday logic.
- Blocks current spread above `strategy_spread_median_mult` times the median M30 spread over `strategy_spread_lookback_days`.
- Framework kill-switch, news, Friday close, and risk checks remain active.

### Entry

- Long only.
- Evaluates only on the `09:30` New York M15 bar.
- Requires at least `strategy_min_d1_closes=60` valid D1 closes.
- Opens when the prior closed D1 close crosses above `SMA(strategy_sma_period_d1=10)`.
- Does not add to an existing same-symbol/same-magic position.
- Hard stop is `strategy_atr_sl_mult=2.0 * ATR(strategy_atr_period_d1=20, D1)` below entry.

### Trade Management

- No trailing stop, break-even, partial close, pyramiding, or take profit.

### Exit

- Baseline exit closes at the next regular cash open after the prior D1 close crosses below SMA(10).
- Optional P3 variant `strategy_fixed_hold_enabled=true` closes after `strategy_fixed_hold_days=3` completed D1 bars, with a same-day safety close near the cash-session end.
- Broker SL can close first.

## Risk Contract

- Backtest sets use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live sets use `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- `PORTFOLIO_WEIGHT=1.0` unless portfolio construction overrides it.

## Caveat

The approved card names `SP500.DWX` as the primary research leg and states that SP500-only success requires parallel validation on `NDX.DWX` or `WS30.DWX` before T6 deploy.
