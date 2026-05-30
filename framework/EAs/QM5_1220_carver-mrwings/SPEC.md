# QM5_1220 Carver Mean Reversion In The Wings

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1220_carver-mrwings.md`
- Status: APPROVED
- EA label: `QM5_1220_carver-mrwings`
- Framework: QuantMechanica V5

## Framework Alignment

- No-trade: D1 only, registered symbol-slot only, strict warmup for `WingStdLookback + Lslow + StdDev`, spread cap, V5 news and Friday-close guardrails.
- Entry: once per closed D1 bar, compute `EWMAC=(EMA(Lfast)-EMA(Lslow))/StdDev(close changes,25)`, estimate rolling EWMAC standard deviation, and stay flat unless `abs(EWMAC) >= WingSigma * wing_std`.
- Signal: the wing forecast is contrarian, `forecast = ForecastScalar * -EWMAC`, capped to `[-20,+20]`; long above `EntryForecast`, short below `-EntryForecast`.
- Management: one position per symbol/magic; no intraday re-entry loop because entries are keyed to the last closed D1 bar.
- Exit: close long when forecast is non-positive or the EWMAC reading falls below `ExitSigma * wing_std`; close short symmetrically.
- Stop: emergency ATR stop via `QM_StopATR`, default `3.0 * ATR(20, D1)`.

## Universe And Slots

Slots `0..6`: `GER40.DWX`, `NDX.DWX`, `WS30.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`.

## Notes

- Build only. No backtests or pipeline phases were run.
- `.DWX` suffixes remain in build and setfiles. Deploy-time stripping is outside this scope.
- Strict Card default uses `WingStdLookback=5000`; if history is insufficient, P1/P2 can test the approved deviation `1250` through setfile parameters.
