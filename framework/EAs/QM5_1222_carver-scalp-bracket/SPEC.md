# QM5_1222_carver-scalp-bracket

## Intent

V5 implementation of the approved Rob Carver intraday range bracket scalper.

## Card Mapping

- **No-trade:** Blocks all symbols except `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`; blocks D1 operation; blocks new brackets before warmup, after soft close, when spread exceeds `0.20 * R`, when the stop is below ten ticks, or when daily realized loss reaches `3 * RISK_FIXED`.
- **Entry:** On the configured signal timeframe, computes `R = High(HorizonSeconds) - Low(HorizonSeconds)` from completed intraday bars. When flat with no live bracket orders, it places symmetric buy/sell limit orders around the bid/ask midpoint using default `HorizonSeconds=900`, `F=0.75`, and `K=0.87`.
- **Management:** Uses a one-bracket state machine per symbol/magic. If one limit fills, the opposite limit remains as the profit-taking order and the filled order carries the range-scaled protective stop. If a stop exit leaves the opposite limit behind, the EA cancels that stale pending order on the next tick.
- **Exit:** Profit exits occur through the opposing bracket limit. Stop exits use the range-scaled stop attached to the filled pending order. At hard close, all working orders are cancelled and any open position is closed at market.
- **Sizing:** Lots use `QM_LotsForRisk()` with stop distance `(R / 2) * (K - F)`. Backtest setfiles use fixed risk; live proxy setfiles use percent risk.

## Scope Notes

- Symbol slots: `0=SP500.DWX`, `1=NDX.DWX`, `2=WS30.DWX`.
- `SP500.DWX` is the P2 baseline/backtest symbol. `NDX.DWX` and `WS30.DWX` are included for the Card's T6 live-promotion caveat.
- No backtests or pipeline phases are part of this build.
