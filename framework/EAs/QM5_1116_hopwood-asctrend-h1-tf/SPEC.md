# QM5_1116 Hopwood ASCTrend H1 Trend-Follower

## Registry Note

Pre-flight found `ea_id=1116` registered as `qp-comm-mom12` while this APPROVED card allocates `QM5_1116_hopwood-asctrend-h1-tf`. No `framework/EAs/QM5_1116_*` folder existed. The existing `qp-comm-mom12` EA is `QM5_1101_qp-comm-mom12`, so only the `1116` rows were corrected for this build.

## Framework Alignment

- No-Trade: central V5 kill-switch, news and Friday-close checks, plus card spread cap of 25 points and warmup guard.
- Trade Entry: closed H1 ASCTrend flip in trend direction, filtered by H1 EMA(200), market entry on the next new bar.
- Trade Management: none. The card forbids grid, martingale, scale-in, trailing and partial exits.
- Trade Close: opposite closed H1 ASCTrend flip. Broker SL/TP handles ATR stop and fixed RR target.

## Strategy Defaults

- Timeframe: H1.
- ASCTrend risk: 3.
- EMA filter: 200 H1 close.
- Initial stop: ATR(14) x 2.0 by default.
- Optional P3 stop variant: prior H1 structure over 10 bars.
- Take profit: fixed RR target 2.0.
- Spread cap: 25 points.
- P2 symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, EURJPY.DWX, GBPJPY.DWX.

## Boundary

Build-only implementation. No backtests or pipeline phases were run from this folder.

