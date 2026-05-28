# QM5_1145 Cliff-Cooper Intraday-Only Index

## Source Card

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1145_cliff-cooper-intraday-only-idx.md`
- `g0_status: APPROVED`
- Source: Cliff, Cooper, Gulen, "Return Differences Between Trading and Non-Trading Hours: Like Night and Day"

## Framework Alignment

- No-Trade: V5 kill-switch, news filter, Friday close, symbol/timeframe gate, spread gate, regular-session day gate, and optional overnight-gap skip.
- Entry: one market position at the first M30 bar after each supported index cash-session open. Baseline direction is short; long-side is exposed only for the card-authorized P3 sweep.
- Management: no trailing stop, no add-on, no partial close.
- Close: close the position at the last M30 bar before same-day cash-session close. The EA is flat overnight.

## Supported Symbols

| Slot | Symbol | Session Clock |
| --- | --- | --- |
| 0 | `GDAXI.DWX` | Xetra proxy, 09:00-17:30 Germany |
| 1 | `NDX.DWX` | US cash, 09:30-16:00 New York |
| 2 | `UK100.DWX` | LSE proxy, 09:00-17:30 London |
| 3 | `WS30.DWX` | US cash, 09:30-16:00 New York |
| 4 | `SP500.DWX` | US cash, 09:30-16:00 New York; backtest-only T6 caveat |

Broker time follows the repository Darwinex/DXZ NY-close convention. The EA converts broker time through `QM_BrokerToUTC` and local DST calendars for session-clock decisions.

## Parameters

- `strategy_timeframe_minutes = 30`
- `strategy_atr_period = 14`
- `strategy_atr_sl_mult = 4.0`
- `strategy_use_gap_filter = true`
- `strategy_max_overnight_gap_pct = 1.0`
- `strategy_trade_short_side = true`
- `strategy_entry_offset_minutes = 0`
- `strategy_exit_offset_minutes = 0`
- `strategy_max_spread_points = 0`

## Risk Contract

- Backtest setfiles use `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
- Live setfiles use `RISK_PERCENT = 0.25` and `RISK_FIXED = 0`.

## Notes

- `SP500.DWX` is included as backtest-only, matching the card caveat.
- The FOMC skip is handled through the V5 news filter inputs; no external market-data API or pipeline phase is used in this build.
- No backtests or pipeline phases are part of this build step.
