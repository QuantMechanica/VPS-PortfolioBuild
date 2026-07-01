---
ea_id: QM5_12848
slug: wti-brent-brk
type: strategy
strategy_id: CME-WTI-BRENT-SPREAD-2026_S02
source_id: CME-WTI-BRENT-SPREAD-2026
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
---

# WTI-Brent Spread Breakout

This local EA copy follows the approved card at
`strategy-seeds/cards/wti-brent-brk_card.md`.

The strategy is a D1 two-leg crude benchmark basket on `XTIUSD.DWX` and
`XBRUSD.DWX`. It computes `log(XBRUSD.DWX) - beta * log(XTIUSD.DWX)`, buys Brent
and sells WTI on upside channel breakouts, sells Brent and buys WTI on downside
channel breakouts, and exits on the shorter opposite-channel break, max hold,
Friday close, broken-package repair, or per-leg ATR stops.

Backtests use `RISK_FIXED=1000`. No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.
