# QM5_1226_psaradellis-oil-channel

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1226_psaradellis-oil-channel.md`
- Source: Psaradellis, Laws, Pantelous, and Sermpinis, "Performance of Technical Trading Rules: Evidence from the Crude Oil Market" (European Journal of Finance, 2019 / SSRN 2832600).

## Framework Alignment

- No-Trade: blocks unsupported symbols, non-D1 charts, mismatched magic slot, invalid channel/ATR inputs, insufficient D1 history, and optional spread excess.
- Entry: on a confirmed D1 close, goes long when `Close[1]` is above the prior 55-bar high and short when `Close[1]` is below the prior 55-bar low.
- Management: hard ATR stop is set on entry; optional trailing stop uses `2.5 * ATR(20)` only after unrealized move reaches `+2R`.
- Exit: closes long when `Close[1]` is below the prior 20-bar low; closes short when `Close[1]` is above the prior 20-bar high.

## Symbols and Slots

| Slot | Symbol |
| --- | --- |
| 0 | XTIUSD.DWX |

## Parameters

- `strategy_signal_tf=PERIOD_D1`
- `strategy_entry_channel=55`
- `strategy_exit_channel=20`
- `strategy_atr_period=20`
- `strategy_atr_sl_mult=3.0`
- `strategy_use_trailing_stop=true`
- `strategy_trail_atr_mult=2.5`
- `strategy_trail_trigger_r=2.0`
- `strategy_min_bars=120`

## Notes

- The source's crude-oil technical-rule family is ported directly to the approved `XTIUSD.DWX` CFD symbol.
- Reverse behavior is handled by the framework sequence: existing position exits first on the 20-bar channel rule; any opposite 55-bar breakout can only open after the EA is flat on a later entry evaluation.
- No backtests or pipeline phases are part of this build.
