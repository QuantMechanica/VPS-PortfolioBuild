# QM5_41029_wti-flow-agree - Strategy Spec

EA ID: `QM5_41029`

Slug: `wti-flow-agree`

Source: `WILLIAMS-MOP-WTI-WFLOW-2026`

Canonical card:
`strategy-seeds/cards/approved/QM5_41029_wti-flow-agree_card.md`

## Strategy

On the first executable tick of an exact broker Monday, reconstruct the exact
completed prior Monday-through-Friday `XTIUSD.DWX` D1 week plus its preceding
Friday anchor. Sum the five completed close-to-open log returns separately
from the five completed open-to-close log returns. Buy only when both sums are
strictly positive and sell only when both are strictly negative. Disagreement,
zero, invalid data, a holiday-shifted week, late attachment, or a consumed week
remains flat.

The current Monday bar is excluded from both sums. One slot-0 position carries
a frozen `3.0 * ATR(20,D1)` hard stop, no target, and the framework Friday
close at broker hour 21. Later-week and eight-calendar-day checks repair stale
exposure.

## Risk And Scope

- backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- magic: `410290000`
- news modes: OFF
- entry spread ceiling: 1,500 points
- no live/demo/shadow/stress/optimization setfile
- no external feed, line crossover, volatility or magnitude gate, retry,
  scale-in, grid, martingale, pyramid, target, or trailing stop

Q09 alone may establish realized correlation with the certified book. This
build is non-live and does not authorize portfolio admission.

## Q01 Evidence

- independent mechanic reference suite: 12 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check: 0 failures, 0 warnings
- static P1 artifact validation: PASS
- build report: `D:/QM/reports/framework/21/build_check_20260816_191153.json`
- P1 report: `D:/QM/reports/pipeline/QM5_41029/P1/P1_QM5_41029_result.json`

## Version History

| Version | Date | Change | Status |
|---|---|---|---|
| v1 | 2026-08-16 | approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic implementation | magic/resolver verified; strict compile and build check PASS |
