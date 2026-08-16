# QM5_41030 XAU/XAG Weekly Relative-Flow Divergence - Strategy Spec

EA ID: `QM5_41030`

Slug: `xauxag-flowdiv`

Source: `WILLIAMS-SCHWEIKERT-XAUXAG-FLOWDIV-2026`

Canonical card:
`strategy-seeds/cards/approved/QM5_41030_xauxag-flowdiv_card.md`

## Strategy

On the first executable tick of an exact synchronized broker Monday, read the
six immediately preceding completed XAU/XAG D1 bars. They must be the prior
Friday through Monday plus the preceding Friday anchor, with exact timestamps
on both metals and no holiday substitution.

For the five formation sessions, separately sum gold-minus-silver close-to-
open and open-to-close log returns. Trade only when those two relative flows
have strict opposite signs. Follow the session-relative sign with opposite
legs: positive buys XAU and sells XAG; negative sells XAU and buys XAG.

The current Monday price is excluded. A logical package targets equal absolute
USD notionals, caps combined frozen-stop risk at one fixed-dollar budget, uses
per-leg `3.0 * ATR(20,D1)` hard stops, has no target, and closes both legs at
broker Friday hour 21. Later-week and eight-day checks repair stale exposure.

## Risk And Scope

- backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`
- logical basket: `QM5_41030_XAU_XAG_FLOWDIV_D1`
- host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `410300000`
- companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `410300001`
- post-rounding absolute-notional mismatch cap: 20%
- news modes: OFF
- entry spread ceiling: 1,500 points on each leg
- no live/demo/shadow/optimization setfile
- no ratio level, fitted residual, magnitude threshold, retry, scale-in, grid,
  martingale, pyramid, target, trailing stop, or standalone leg

Q02 may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book. This build is non-live and does
not authorize portfolio admission.

## Q01 Evidence

- independent mechanic reference suite: 12 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check: 0 failures, 0 warnings
- basket manifest JSON and locked preset identity: PASS
- static P1 artifact validation: PASS
- build report: `D:/QM/reports/framework/21/build_check_20260816_200126.json`
- P1 report: `D:/QM/reports/pipeline/QM5_41030/P1/P1_QM5_41030_result.json`

## Version History

| Version | Date | Change | Status |
|---|---|---|---|
| v1 | 2026-08-16 | approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic logical-basket implementation | strict compile and Q01 PASS |
| v1-q02-hold | 2026-08-16 | paced handoff stopped before queue commands | Q02 NOT_ENQUEUED; 8 factory testers exceeded the 7-terminal ceiling |
