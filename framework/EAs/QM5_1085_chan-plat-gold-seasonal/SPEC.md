# QM5_1085_chan-plat-gold-seasonal SPEC

## Strategy

Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1085_chan-plat-gold-seasonal.md`

Chan seasonal precious-metals spread proxy. Platinum is unavailable in the DWX baseline, so the approved G0 port is:

- Long `XAUUSD.DWX`
- Short `XAGUSD.DWX`
- Evaluate on D1 only
- Enter once per year when the closed D1 bar crosses February 26
- Exit all open legs when the closed D1 bar crosses April 19
- No pyramiding, no averaging-in

## V5 Modules

| Module | Implementation |
| --- | --- |
| No-Trade | Blocks non-D1 charts, wrong host symbol/slot combinations, missing `.DWX` legs, insufficient D1 history, and optional spread caps. |
| Trade Entry | Opens both basket legs through `QM_BasketOpenPosition`; `Strategy_EntrySignal` returns false so the framework does not open a host-only order. |
| Trade Management | Empty by design. The card has no trailing, break-even, partial close, add-on, or rebalance rule. |
| Trade Close | Closes both legs on Apr-19 seasonal exit or when the long-spread proxy falls by `strategy_spread_atr_mult * spread ATR` from entry spread. |

## Inputs

| Input | Default | Constraint | Purpose |
| --- | ---: | --- | --- |
| `strategy_entry_month` | 2 | 1-12 expected | Seasonal entry month. |
| `strategy_entry_day` | 26 | valid calendar day expected | Seasonal entry day. |
| `strategy_exit_month` | 4 | 1-12 expected | Seasonal exit month. |
| `strategy_exit_day` | 19 | valid calendar day expected | Seasonal exit day. |
| `strategy_spread_atr_period` | 20 | `>=2` | D1 average absolute spread-change lookback. |
| `strategy_spread_atr_mult` | 3.0 | `>0` | Spread stop multiplier. |
| `strategy_xag_hedge_ratio` | 1.0 | `>0` expected | XAG hedge coefficient in `XAU - ratio * XAG`. |
| `strategy_max_spread_points` | 0 | `>=0` | Optional per-leg spread cap; 0 disables. |
| `strategy_order_deviation_points` | 20 | `>0` expected | Basket order deviation. |

## Symbol Slots

| Slot | Symbol | Direction |
| ---: | --- | --- |
| 0 | `XAUUSD.DWX` | Long |
| 1 | `XAGUSD.DWX` | Short |

## Operational Notes

Friday close is disabled by default because the approved seasonal hold spans multiple weekends. News filters default to off for the same reason as neighboring asset-allocation/seasonality sleeves: this is a D1 calendar strategy, not an intraday event strategy.
