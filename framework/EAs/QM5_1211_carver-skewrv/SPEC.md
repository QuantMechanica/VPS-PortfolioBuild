# QM5_1211 Carver Relative-Value Skew Rule

## Scope

Build-only V5 Expert Advisor for approved strategy card `QM5_1211_carver-skewrv`.

## Card Mapping

- Universe: index group `GER40.DWX`, `NDX.DWX`, `WS30.DWX`; FX group `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.
- Timeframe: closed D1 bars only.
- Entry: compute log returns, rolling skew over `strategy_lookback_days`, group median skew, relative-value signal, rolling MAD over `strategy_mad_days`, capped forecast. Open long above `strategy_entry_forecast`, short below negative threshold.
- Rank cap: only symbols ranked within `strategy_max_slots_per_group` by absolute forecast are eligible.
- Exit: close long when forecast falls below zero; close short when forecast rises above zero.
- Stop: emergency stop at `strategy_atr_stop_mult * ATR(20,D1)`.
- Filters: group must have at least three valid symbols, required lookback + MAD history must exist, and current spread must not exceed `strategy_spread_mult * median D1 spread`.

## Framework Alignment

- No-Trade: symbol-slot match, D1 timeframe, parameter sanity, group enablement.
- Trade Entry: relative-value skew forecast, rank cap, spread gate, ATR stop.
- Trade Management: framework defaults.
- Trade Close: sign-flip forecast exit.
- Risk: V5 `RISK_FIXED` for backtest, `RISK_PERCENT` for live setfiles.

## Notes

- The EA uses only native MT5/DWX bar data and no external data/API calls.
- No backtests or pipeline phases are part of this build.
