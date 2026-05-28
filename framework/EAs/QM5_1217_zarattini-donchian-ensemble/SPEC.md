# QM5_1217_zarattini-donchian-ensemble

## Source

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1217_zarattini-donchian-ensemble.md`
- Source: Zarattini, Pagani, and Barbon, "Catching Crypto Trends; A Tactical Approach for Bitcoin and Altcoins" (SSRN / Swiss Finance Institute Research Paper No. 25-80, 2025).

## Framework Alignment

- No-Trade: blocks unsupported symbols, non-D1 charts, mismatched symbol slot, invalid inputs, insufficient history, and excessive spread.
- Entry: on each confirmed D1 close, computes the 20/55/100 Donchian ensemble score. A flat EA buys when score is at least `+0.34` and sells when score is at most `-0.34`.
- Management: no trailing, partial close, or adaptive sizing beyond the initial ATR safety stop.
- Exit: closes long when the confirmed ensemble score is `<= 0`; closes short when the score is `>= 0`.

## Symbols and Slots

| Slot | Symbol |
| --- | --- |
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | XAUUSD.DWX |
| 4 | GER40.DWX |
| 5 | NDX.DWX |

## Parameters

- `strategy_signal_tf=PERIOD_D1`
- `strategy_lookback_fast=20`
- `strategy_lookback_mid=55`
- `strategy_lookback_slow=100`
- `strategy_entry_threshold=0.34`
- `strategy_atr_period_d1=20`
- `strategy_atr_sl_mult=2.50`
- `strategy_min_bars=120`
- `strategy_reentry_wait_bars=5`

## Notes

- The crypto source logic is ported exactly as a deterministic trend ensemble onto the approved DWX FX/metal/index basket.
- The card's prior-score Donchian rule is implemented by replaying historical closed D1 bars up to the latest confirmed bar and carrying each lookback vote forward until a new breakout updates it.
- `PORTFOLIO_WEIGHT=0.66` in canonical setfiles approximates the card's max 4R basket exposure when all six symbols are active.
- No backtests or pipeline phases are part of this build.
