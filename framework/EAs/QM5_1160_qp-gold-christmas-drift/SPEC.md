# QM5_1160 qp-gold-christmas-drift

## Strategy

Approved Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1160_qp-gold-christmas-drift.md`

Single-symbol XAUUSD.DWX Christmas seasonality. The EA opens long at the close-hour of the second U.S. trading day before December 25 and exits at the close-hour of the fifth U.S. trading day after December 25. The stop is a hard ATR(D1,20) multiple with baseline multiplier 2.0.

## Framework Alignment

- No-Trade: V5 framework guards plus symbol, timeframe, parameter, spread, and magic-slot checks in `Strategy_NoTradeFilter`.
- Entry: `Strategy_EntrySignal` requires at least 60 D1 bars, D-2 U.S. trading day before Christmas, one entry per year, no open position, and ATR stop validity.
- Management: no trailing, break-even, or partial close; the card specifies fixed ATR stop and time exit.
- Close: `Strategy_ExitSignal` closes on D+5 U.S. trading day after Christmas, or on the next available bar day after that scheduled date.
- Risk: V5 standard `RISK_FIXED` for backtest, `RISK_PERCENT` for live.
- Magic: `ea_id=1160`, slot `0`, `XAUUSD.DWX`.

## Parameters

- `strategy_entry_offset_trading_days`: baseline `-2`.
- `strategy_exit_offset_trading_days`: baseline `5`.
- `strategy_atr_period_d1`: default `20`.
- `strategy_atr_sl_mult`: default `2.0`.
- `strategy_min_d1_bars`: default `60`.
- `strategy_entry_hour_broker`: default `20`.
- `strategy_exit_hour_broker`: default `20`.
- `strategy_max_spread_points`: default `300`.

## Notes

The U.S. trading-day calendar is implemented locally for the Christmas window using weekends plus observed Christmas and New Year holidays. No backtests or pipeline phases are part of this build.
