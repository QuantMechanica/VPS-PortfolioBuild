# QM5_12930 Build Specification

- Strategy card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12930_classical-ascending-triangle-breakout-h4.md`
- G0 status: `APPROVED`
- EA ID / slug: `12930` / `classical-ascending-triangle-breakout-h4`
- Timeframe: `H4`
- Direction: bullish-only baseline
- Build scope: compile and non-live pipeline preparation only

## Framework alignment

| Card rule | Implementation |
|---|---|
| Williams 2+2 fractals, 200-bar scan | `Strategy_IsFractalHigh`, `Strategy_IsFractalLow` |
| Two resistance pivots within 0.50 ATR, 8–60 bars apart | `Strategy_FindAscendingTriangle` |
| Two rising support pivots by at least 0.50 ATR | `Strategy_CollectSupportPivots` and `Strategy_FindAscendingTriangle` |
| Best-fit support slope 0.10–0.50 ATR/bar | `Strategy_SupportRegressionSlope` |
| Pattern age 25–80 bars | `Strategy_FindAscendingTriangle` |
| At least 50% range contraction | `Strategy_FindAscendingTriangle` |
| Close > resistance + 0.50 ATR | `Strategy_EntrySignal` |
| Optional 1.2 × tick-volume confirmation | `Strategy_VolumeAllowsEntry`, default OFF |
| Optional SMA200 macro bias | `Strategy_EntrySignal`, default ON |
| Projected-support SL with 0.50 ATR buffer and 3 ATR cap | `Strategy_EntrySignal` |
| Measured-move TP | `Strategy_EntrySignal` |
| 60-bar time stop | `Strategy_ExitSignal` |
| 30-bar reuse guard | `Strategy_ReuseGuardActive` |
| Current spread ≤ 1.5 × 20-bar average | `Strategy_SpreadAllowsEntry` |
| Central news and Friday-close controls | V5 framework two-axis news gate and Friday-close handler |

## Registered P2 surface

`GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`, `XAUUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`.

## Open implementation question

The card mentions an optional failed-breakout reverse-short P3 variant but does not specify its reverse-side SL or TP. The governed baseline keeps that variant OFF and does not invent missing mechanics; a separate approved card amendment is required before exposing it.

Backtest sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The EA contains no ML, grid, martingale, live enablement, or terminal-launch logic.
