# QM5_1129 Gatev Pairs Trading Distance

## Source

Approved strategy card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1129_gatev-pairs-trading-distance.md`

## Framework Alignment

- No-Trade: uses V5 kill-switch, news, Friday close, and symbol gating. New entries are blocked unless the chart symbol is one of the configured pair legs.
- Entry: D1 closed-bar Gatev distance method. A 252-bar formation window normalizes both legs to price-relative index values, computes spread mean/stdev, and enters when `abs(z) >= 2.0`.
- Trade Management: per-leg ATR(D1,14) * 3 hard stop; risk is split equally across the two legs.
- Close: closes both legs when `abs(z) <= 0.1`, `abs(z) >= 4.0`, or the pair has been held for 126 D1 bars.

## Instruments

Baseline pair: `AUDUSD.DWX` / `NZDUSD.DWX`.

Sweep-ready pairs are exposed through `strategy_pair_a` and `strategy_pair_b` inputs and setfiles:

- `EURUSD.DWX` / `GBPUSD.DWX`
- `GDAXI.DWX` / `UK100.DWX`
- `USDJPY.DWX` / `EURJPY.DWX`

## Notes

The EA opens two independent leg positions with magic slots `0` and `1`. If the second leg fails, the first leg is immediately closed through the trade-management close path.

No backtests or pipeline phases are part of this build.
