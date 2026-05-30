---
ea_id: QM5_1153
slug: unger-nasdaq-priorclose-expansion
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-17
---

# Unger Nasdaq Prior-Close Expansion

Approved source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1153_unger-nasdaq-priorclose-expansion.md`.

Universe: `NDX.DWX` primary, `WS30.DWX` robustness port, optional `SP500.DWX` backtest-only. Execution timeframe M5.

Entry: compute previous D1 close and completed D1 ATR(14). Place buy-stop at previous close plus `EXPANSION_MULT * ATR_D1`, and sell-stop at previous close minus that expansion. Default expansion multiple is `0.25`.

Exit: stop loss or take profit, intraday session flatten, and cancellation of unfilled pending orders after 15:30 New York time.

Risk: backtest uses `RISK_FIXED=1000`; live uses `RISK_PERCENT=0.25`.

Filters: trade Tuesday-Friday only, skip previous full-session exhaustion days where previous D1 range is above `2.5 * ATR_D1`, and retain standard V5 news/spread controls.

T6 caveat: `SP500.DWX` is not broker-routable. If pipeline evidence is only on `SP500.DWX`, live deploy needs parallel validation on `NDX.DWX` or `WS30.DWX`.
