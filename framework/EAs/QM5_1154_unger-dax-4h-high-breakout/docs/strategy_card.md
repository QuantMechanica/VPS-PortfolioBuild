---
ea_id: QM5_1154
slug: unger-dax-4h-high-breakout
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-17
---

# Unger DAX 4H High Breakout - Morning Long Trend Filter

Approved Strategy Card source: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1154_unger-dax-4h-high-breakout.md`.

## Mechanik

Universe: `GDAXI.DWX`. Execution timeframe: `M15`.

Entry:
- Trade only Monday, Tuesday, and Wednesday.
- During the DAX morning entry window, default `09:00-12:00`, compute `HH4H` as the highest high of the previous 16 completed M15 bars.
- Place a long-only buy-stop at `HH4H + 0.05 * ATR(14, M15)`.
- One entry per session.

Exit:
- Close on stop loss or take profit.
- If neither is hit, exit after `MAX_HOLD_SESSIONS = 2`.
- Standard V5 Friday close remains enabled.

Stops and filters:
- Stop loss: `2.0 * ATR(14, M15)`.
- Take profit: `3.0 * ATR(14, M15)`.
- Skip when the four-hour range is below `0.25 * ATR(14, D1)` or above `1.25 * ATR(14, D1)`.
- Standard V5 spread and news filters.

Position sizing:
- Backtest default `RISK_FIXED = 1000`.
- Live default `RISK_PERCENT = 0.25`.
