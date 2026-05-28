# QM5_1144 baur-gold-autumn-effect

## Strategy

Approved Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1144_baur-gold-autumn-effect.md`

Single-symbol XAUUSD calendar seasonality from Baur's gold autumn effect. The baseline enters long on the first trading session of September and November and exits on the final weekday session of the entry month. The EA also exposes P3 sweep controls for an October overlay and first-half-month holding.

## Framework Alignment

- No-Trade: V5 framework guards plus symbol/timeframe/parameter checks in `Strategy_NoTradeFilter`.
- Entry: `Strategy_EntrySignal` checks first trading session of configured month, one open position, spread filter, then opens a long with ATR(D1,14) stop.
- Management: no trailing or partial close; card specifies fixed ATR stop and calendar exit.
- Close: `Strategy_ExitSignal` closes on the last weekday session of the entry month, or on day 15 for half-month sweep.
- Risk: V5 standard `RISK_FIXED` for backtest, `RISK_PERCENT` for live.
- Magic: `ea_id=1144`, slot `0`, `XAUUSD.DWX`.

## Parameters

- `strategy_entry_months`: baseline `"9,11"`.
- `strategy_enable_october`: optional October overlay.
- `strategy_half_month_hold`: optional first-2-weeks hold approximation.
- `strategy_atr_period_d1`: default `14`.
- `strategy_atr_sl_mult`: default `3.0`.
- `strategy_spread_median_mult`: default `2.0` over `20` D1 samples.

## Notes

The Card's FOMC entry-day skip is represented by the framework news filter setfiles rather than a custom hard-coded event calendar. No backtests or pipeline phases are part of this build.
