# QM5_1130 Lou-Polk Overnight Intraday

## Source Card

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1130_lou-polk-overnight-intraday.md`
- `g0_status: APPROVED`
- Source: Lou, Polk, Skouras, "A Tug of War: Overnight Versus Intraday Expected Returns"

## Framework Alignment

- No-Trade: V5 kill-switch, news filter, Friday close, symbol/timeframe gate, spread gate, and optional volatility regime skip.
- Entry: one long market entry at each supported equity-index session close, excluding Friday entries by default.
- Management: no trailing stop, no add-on, no partial close.
- Close: close the position at the next local cash-session open.

## Supported Symbols

| Slot | Symbol | Session Clock |
| --- | --- | --- |
| 0 | `NDX.DWX` | US cash, 09:30-16:00 New York |
| 1 | `WS30.DWX` | US cash, 09:30-16:00 New York |
| 2 | `SP500.DWX` | US cash, 09:30-16:00 New York; backtest-only T6 caveat |
| 3 | `GDAXI.DWX` | Xetra proxy, 09:00-17:30 Germany |
| 4 | `UK100.DWX` | LSE proxy, 09:00-17:30 London |

Broker time follows the repository `CLAUDE.md` convention: Darwinex/DXZ NY-close is GMT+2 outside US DST and GMT+3 during US DST. The EA converts broker time through `QM_BrokerToUTC` and local DST calendars for session-clock decisions.

## Parameters

- `strategy_timeframe_minutes = 30`
- `strategy_atr_period = 14`
- `strategy_atr_sl_mult = 3.0`
- `strategy_skip_friday_entries = true`
- `strategy_use_vol_regime_filter = true`
- `strategy_vol_lookback_days = 252`
- `strategy_vol_threshold_mult = 1.5`
- `strategy_entry_offset_minutes = 0`
- `strategy_exit_offset_minutes = 0`
- `strategy_max_spread_points = 0`

## Risk Contract

- Backtest setfiles use `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
- Live setfiles use `RISK_PERCENT = 0.25` and `RISK_FIXED = 0`.

## Notes

- The card requests DXZ session-calendar handling. This implementation uses deterministic session clocks plus holiday handling for US symbols and DST-aware local clocks for Europe/UK.
- No backtests or pipeline phases are part of this build step.
