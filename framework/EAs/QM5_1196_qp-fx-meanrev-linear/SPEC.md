# QM5_1196_qp-fx-meanrev-linear

## Summary

Quantpedia FX Linear Mean Reversion port for the V5 framework. The EA trades one FX leg per chart and uses the six-card universe:

- `EURUSD.DWX`
- `GBPUSD.DWX`
- `USDJPY.DWX`
- `AUDUSD.DWX`
- `USDCAD.DWX`
- `USDCHF.DWX`

## Card Mapping

- Entry: on D1 month-end closed bar, normalize each currency leg to a USD-base cumulative monthly return over 24 MN1 observations, compute the basket average, and trade mean reversion for legs away from the average.
- Exit: on monthly rebalance when the leg crosses/loses the signal or flips side; stale safety exit after a missed rebalance window.
- Stop: per-leg ATR(20) D1 stop at `3.0x`.
- Sizing: V5 risk model with total basket cap represented by per-leg `PORTFOLIO_WEIGHT=0.1667`; signal direction uses the linear deviation from basket average and logs the deviation.
- Risk guard: portfolio basket kill closes all 1196 magic slots at `2.5x` planned basket risk.

## Framework Alignment

- No-trade: D1-only, symbol/slot guard, minimum monthly history, spread gate.
- Entry: `Strategy_EntrySignal`.
- Management: `Strategy_ManageOpenPosition` handles basket kill.
- Close: `Strategy_ExitSignal` handles rebalance/cross/stale exits.

## Boundary

No backtests or pipeline phases are included in this build. The EA uses only Darwinex/DWX MT5 symbol history; no external market-data calls are made.
