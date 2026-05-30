---
ea_id: QM5_1163
slug: unger-dax-bb-multiday
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Unger DAX Bollinger Multiday - Band Breakout Trend Following

Approved Strategy Card build copy for `QM5_1163_unger-dax-bb-multiday`.

## Source

Unger Academy DAX strategy articles and *The Unger Method - Andrea Unger's Trading Method*.

## Mechanics

Universe: `GDAXI.DWX` primary, optional `NDX.DWX` and `WS30.DWX` robustness ports. Execution timeframe H1 or H4; first build H1.

Entry:
- Bollinger Bands on completed timeframe closes, default `BB_PERIOD=40`, `BB_DEV=2.0`.
- Long when completed close crosses above upper Bollinger Band.
- Short when completed close crosses below lower Bollinger Band.
- Enter at market on the signal bar close.
- One position per magic.

Exit:
- Stop loss, take profit, or trailing stop.
- Close long when close is below Bollinger middle band.
- Close short when close is above Bollinger middle band.
- Max hold default `MAX_HOLD_BARS=40`.

Risk:
- Backtest default fixed risk `1000`.
- Live default risk percent `0.25`.

Filters:
- Prefer European index session and first two hours after US open.
- Do not open new positions late Friday.
- Standard V5 spread/news filters.
