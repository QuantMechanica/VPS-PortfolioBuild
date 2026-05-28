# QM5_1209 Carver Within-Asset Mean Reversion

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1209_carver-mrinasset.md`
- Status: APPROVED
- EA label: `QM5_1209_carver-mrinasset`
- Framework: QuantMechanica V5

## Framework Alignment

- No-trade: D1 only, registered symbol-slot only, warmup validation, spread cap, V5 news and Friday-close guardrails.
- Entry: per D1 closed bar, compute within-group Carver-style idiosyncratic normalized move versus group median, EMA-smoothed and capped forecast. Trade only top `strategy_max_slots_per_group` absolute forecasts per group.
- Management: structural-break guard closes and blocks the symbol after adverse `strategy_break_atr_mult * ATR(20)`.
- Exit: close when the forecast crosses neutral/opposite or the symbol drops out of the top forecast set.
- Stop: emergency ATR stop via `QM_StopATR`, default `2.5 * ATR(20, D1)`.

## Universe And Slots

Slots `0..2` are the equity-index group: `GER40.DWX`, `NDX.DWX`, `WS30.DWX`.

Slots `3..8` are the FX-major group: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `USDCAD.DWX`.

## Notes

- Build only. No backtests or pipeline phases were run.
- `.DWX` suffixes remain in build and setfiles. Deploy-time stripping is outside this scope.
