# QM5_1221 Carver Relative-Value Kurtosis-Conditioned Skew

## Scope

Build-only V5 Expert Advisor for approved strategy card `QM5_1221_carver-kurtsrv`.

## Card Mapping

- Universe: FX group `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`; index group `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`, `FRA40.DWX`.
- Timeframe: closed D1 bars only.
- Entry: compute rolling log-return skew and excess kurtosis, demean both against same-group averages, scale relative kurtosis by rolling robust volatility, condition direction by the sign of relative skew, smooth with EMA, cap forecast to `[-20,+20]`.
- Signal: long above `strategy_entry_forecast`, short below negative threshold.
- Slot cap: only the top `strategy_max_slots_per_side` long forecasts and top `strategy_max_slots_per_side` short forecasts per group are eligible.
- Exit: close long when forecast falls below zero; close short when forecast rises above zero; exit if group validity falls below `strategy_min_group_symbols`.
- Stop: emergency stop at `strategy_atr_stop_mult * ATR(20,D1)`.
- Filters: one D1 rebalance, minimum group validity, symbol-slot match, spread cap against median D1 spread, and parameter sanity gates.

## Framework Alignment

- No-Trade: symbol-slot match, D1 timeframe, group enablement, minimum group size, and parameter sanity.
- Trade Entry: relative-value kurtosis conditioned by skew, EMA forecast, side-specific rank cap, spread gate, ATR stop.
- Trade Management: framework defaults.
- Trade Close: sign-flip forecast exit and invalid group exit.
- Risk: V5 `RISK_FIXED` for backtest and `RISK_PERCENT` for live setfiles.

## Notes

- The EA uses only native MT5/DWX bar data and no external data/API calls.
- No backtests or pipeline phases are part of this build.
