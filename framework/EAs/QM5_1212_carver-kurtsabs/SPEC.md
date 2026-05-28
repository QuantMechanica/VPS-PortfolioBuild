# QM5_1212 carver-kurtsabs SPEC

## Scope
- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1212_carver-kurtsabs.md`
- Framework: QuantMechanica V5
- Build-only status: no backtests and no pipeline phase execution

## Strategy Mapping
- No-Trade: blocks unsupported symbols, wrong magic slot, non-D1 charts, invalid parameters, and over-wide live spread versus 20D median spread.
- Entry: on each closed D1 bar compute log returns, rolling skew, rolling excess kurtosis, `raw_signal = (skew - baseline_skew) * max(kurtosis - baseline_kurtosis, 0)`, scale by 252-bar rolling absolute-median raw signal, cap forecast to +/-20, then enter long above +2 or short below -2.
- Management: none beyond framework risk, kill-switch, Friday-close, and SL handling.
- Exit: close long when forecast falls below 0, close short when forecast rises above 0, or close either side when the kurtosis gate is non-positive for 3 consecutive closed D1 bars.
- Stop: emergency stop at `3.0 * ATR(20, D1)`.

## Universe And Slots
- Slot 0: `GER40.DWX`
- Slot 1: `NDX.DWX`
- Slot 2: `WS30.DWX`
- Slot 3: `EURUSD.DWX`
- Slot 4: `GBPUSD.DWX`
- Slot 5: `USDJPY.DWX`
- Slot 6: `XAUUSD.DWX`
- Slot 7: `XTIUSD.DWX`

## Defaults
- `strategy_lookback_bars=180`
- `strategy_median_lookback_bars=252`
- `strategy_baseline_skew=0`
- `strategy_baseline_kurtosis=0`
- `strategy_entry_forecast=2`
- `strategy_exit_confirm_bars=3`
- `strategy_atr_period=20`
- `strategy_atr_stop_mult=3.0`

## Notes
- The card writes `XAUUSD` in one universe line; this build uses `XAUUSD.DWX` per V5 symbol discipline.
- `QM_MagicResolver.mqh` is regenerated from `magic_numbers.csv`.
