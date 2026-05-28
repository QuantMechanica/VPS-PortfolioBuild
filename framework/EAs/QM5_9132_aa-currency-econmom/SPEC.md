# QM5_9132 aa-currency-econmom

## Strategy Logic

Monthly currency economic momentum from the approved Alpha Architect source. A currency leg is eligible when the approved point-in-time macro panel ranks it in the strongest or weakest tercile. Strongest-tercile symbols open long; weakest-tercile symbols open short. Neutral or missing macro-panel states do not trade.

The EA exposes the computed monthly macro rank as `strategy_macro_signal`: `+1` for strongest tercile, `-1` for weakest tercile, and `0` for missing or inactive. `strategy_macro_data_approved` must be true before any entry can fire.

## Parameters

| Input | Default | Meaning |
|---|---:|---|
| `qm_ea_id` | `9132` | V5 EA ID. |
| `qm_magic_slot_offset` | `0` | Symbol slot from `magic_numbers.csv`. |
| `RISK_PERCENT` | `0.0` | Live percent-risk input, enabled by live setfiles. |
| `RISK_FIXED` | `1000.0` | Backtest fixed-risk input. |
| `PORTFOLIO_WEIGHT` | `1.0` | Portfolio sleeve weight. |
| `strategy_macro_signal` | `0` | Monthly tercile signal: long, short, or skip. |
| `strategy_macro_data_approved` | `false` | Confirms point-in-time macro panel is approved and lag-aligned. |
| `strategy_rebalance_day` | `3` | Calendar day used for monthly rebalance execution. |
| `strategy_atr_period` | `20` | D1 ATR stop period. |
| `strategy_atr_sl_mult` | `2.5` | ATR stop multiplier. |
| `strategy_tp_rr` | `0.0` | Optional R-multiple take profit; zero means no fixed TP. |
| `strategy_max_spread_points` | `35.0` | Per-tick spread no-trade filter. |

## Symbol Universe

Registered DWX FX symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`.

## Timeframe

Card signal cadence is MN1. Execution and ATR stop controls are D1.

## Expected Behaviour

One monthly rebalance opportunity per registered symbol. Positions remain open until the next monthly rebalance if the signal leaves the active tercile or flips direction, with SL protection at `2.5 x ATR(20,D1)`.

## Source Citation

Larry Swedroe, "Fundamental Momentum, the Carry Trade, and Currency Returns", Alpha Architect, 2020-07-23.

## Risk Model

Backtests use `RISK_FIXED = 1000` and `RISK_PERCENT = 0`. Live deployment uses `RISK_PERCENT = 0.5` and disables fixed risk through live setfiles and manifest controls.
