---
ea_id: QM5_1190
slug: qp-index-double-bottom
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "R1 PASS Quantpedia URL/title/author cited; R2 PASS deterministic local-low neckline-break entry and explicit exits; R3 PASS SP500.DWX D1 backtest-only with NDX/WS30 live caveat; R4 PASS no ML/grid/martingale and one-position cap."
---

# Quantpedia Index Double-Bottom Breakout

Source: Quantpedia, How to Analyze Individual Equity Curves, published 2026-04-23, author David Mesicek / Quantpedia.

## Mechanik

Universe: `SP500.DWX` for backtest research. Alternate route: `NDX.DWX` or `WS30.DWX` if QB wants a broker-routable U.S. index route for later live validation.

Period: D1 daily bars.

Entry:

1. Mark a local low when the low is the minimum over a centered 5-bar window.
2. Identify two local lows separated by 5 to 60 trading sessions.
3. Require the second low to be within 1.0 ATR(20) of the first low.
4. Define the neckline as the highest high between the two lows.
5. Open long when daily close breaks above the neckline.

Exit on the earliest of:

- close below the second-low price minus 0.5 ATR(20),
- 20 trading sessions after entry,
- close below SMA(50).

Initial stop: second-low price minus 0.5 ATR(20).

Position sizing: fixed fractional risk by stop distance, one open position per symbol and magic. No pyramiding on repeated neckline breaks from the same pattern.

Additional filters:

- Long-only.
- Pattern parameters must be frozen before P2.
- Ignore patterns where neckline distance from the second low is below 0.5 ATR(20).

## Broker Route Caveat

Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
