---
ea_id: QM5_1206
slug: lento-sp500-csa-ma
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Lento S&P 500 Combined MA Signal

Approved source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1206_lento-sp500-csa-ma.md`.

## Mechanik

At each `SP500.DWX` D1 close:

- Signal A: `SMA(1) > SMA(200)` is bullish, otherwise bearish.
- Signal B: `SMA(5) > SMA(150)` is bullish, otherwise bearish.
- If both signals are bullish, open or maintain long at the next D1 open.
- If both signals are bearish, hold flat or close an existing long.
- If signals disagree, hold an existing position for one bar; if still disagreeing at the next close, flatten.

Stop loss is `3.0 * ATR(20)` from entry. Minimum history is 220 D1 bars. Baseline is long/flat only.

## Build Notes

The local copy is URL-cleaned for `build_check.ps1`; the approved source card remains unchanged.
