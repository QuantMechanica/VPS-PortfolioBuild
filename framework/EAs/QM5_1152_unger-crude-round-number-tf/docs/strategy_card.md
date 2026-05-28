---
ea_id: QM5_1152
slug: unger-crude-round-number-tf
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Unger Crude Round Number TF - Five-Dollar Level Momentum

Approved card source: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1152_unger-crude-round-number-tf.md`.

## Mechanics

Universe: `XTIUSD.DWX` primary. Execution timeframe M5 or M15.

Entry:
- Build the active round-number grid for crude at every `ROUND_STEP = 5.00` price units.
- Trade only inside the default 08:00-14:30 New York entry window.
- If price breaks above the next round level from below, use a long stop at `ROUND_LEVEL + BUFFER`.
- If price breaks below the next round level from above, use a short stop at `ROUND_LEVEL - BUFFER`.
- Default `BUFFER = max(0.02, 0.05 * ATR(14,M15))`.
- No entries on Fridays. First fill cancels the opposite pending order.

Exit:
- Close through stop loss or take profit.
- Flatten all open positions before the crude reference session end.
- Cancel unfilled pending orders after entry cutoff.

Stops:
- Stop loss: `1.5 * ATR(14,M15)`.
- Take profit: `2.0 * ATR(14,M15)`.

Filters:
- Skip EIA crude inventory release windows.
- Skip if M15 spread is above 2x the 20-session median.
- One position per magic; one trade per direction per session.
