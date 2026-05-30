# QM5_1146 Unger DAX Overnight Bias

## Source Card

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1146_unger-dax-overnight-bias.md`
- `g0_status: APPROVED`
- Source: Unger Academy DAX bias article and *The Unger Method*.

## Framework Alignment

- No-Trade: V5 kill-switch, news filter, Friday close, supported symbol/timeframe gate, German cash-calendar gate, and spread median gate.
- Entry: one long market entry after `17:15` Europe/Berlin on eligible Sunday-Thursday evening sessions.
- Management: no trailing stop, no add-on, no partial close.
- Close: close the long at the next regular `09:00` Europe/Berlin DAX cash open, or earlier by stop loss.

## Supported Symbols

| Slot | Symbol | Role |
| --- | --- | --- |
| 0 | `GDAXI.DWX` | primary DAX/Xetra proxy |
| 1 | `NDX.DWX` | optional robustness port |
| 2 | `WS30.DWX` | optional robustness port |

Broker time follows the repository Darwinex/DXZ convention. The EA converts broker time through `QM_BrokerToUTC`, applies Europe/Berlin DST rules, and evaluates the strategy clock in Berlin local time.

## Parameters

- `strategy_timeframe_minutes = 15`
- `strategy_entry_hour_berlin = 17`
- `strategy_entry_minute_berlin = 15`
- `strategy_exit_hour_berlin = 9`
- `strategy_exit_minute_berlin = 0`
- `strategy_atr_period = 14`
- `strategy_atr_sl_mult = 1.5`
- `strategy_spread_lookback_days = 20`
- `strategy_spread_median_mult = 2.0`
- `strategy_allow_ports = true`

## Risk Contract

- Backtest setfiles use `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
- Live setfiles use `RISK_PERCENT = 0.25` and `RISK_FIXED = 0`.

## Notes

- Holiday handling is deterministic for core German cash-market closures. The next morning must have a regular Berlin `09:00` cash open.
- The source defines timed entry/exit and no exact stop; this first build implements the card default `SL = 1.5 * ATR(14,M15)`.
- No backtests or pipeline phases are part of this build step.
