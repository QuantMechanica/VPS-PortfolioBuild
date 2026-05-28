---
ea_id: QM5_1162
slug: unger-nasdaq-close-channel
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Unger Nasdaq Close Channel - Multiday Highest/Lowest Close Breakout

## Quelle

- Source: `sources/unger-robbins-cup` - Unger Academy December 2025 Strategy of the Month article.
- Article: Strategy of the Month, December 2025, Unger Academy. External URL omitted in EA-local copy for build-check compliance.
- Supporting source: The Unger Method - Andrea Unger's Trading Method, Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164.

## Mechanik

Universe: `NDX.DWX` primary, optional `WS30.DWX` and `SP500.DWX` backtest-only robustness ports. Execution timeframe H1.

### Entry

1. Compute highest and lowest close over completed H1 bars, default lookback `24`.
2. Compute EMA(50,H1) and EMA(200,H1).
3. Long setup: current H1 close breaks above the prior highest close and EMA(50) is above EMA(200).
4. Short setup: current H1 close breaks below the prior lowest close and EMA(50) is below EMA(200).
5. Enter at market on signal-bar close.
6. One position per magic.

### Exit

- Close on stop loss or breakeven stop.
- Close long when H1 closes below EMA(50); close short when H1 closes above EMA(50).
- Force-close all open positions at the end of the Friday session.
- Max hold default: `120` H1 bars.

### Stop Loss

- `SL = 2.5 * ATR(14,H1)`.
- Move stop to breakeven after `2.0 * ATR(14,H1)` favorable excursion.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

## R3

Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
