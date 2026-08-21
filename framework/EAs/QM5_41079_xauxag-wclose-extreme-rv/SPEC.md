# QM5_41079 XAU/XAG Completed-Week Closing-Extreme Reversion

## Identity

- EA: `QM5_41079_xauxag-wclose-extreme-rv`
- Strategy ID: `SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41079_xauxag-wclose-extreme-rv_card.md`
- Exact host: `XAUUSD.DWX`, D1, slot 0, active magic `410790000`
- Exact companion: `XAGUSD.DWX`, D1, slot 1, active magic `410790001`
- Logical symbol: `QM5_41079_XAU_XAG_WCLOSE_EXTREME_RV_D1`

## Mechanic

On the first tradable bar of a new Monday-anchored broker week, collect every
synchronized completed XAU/XAG D1 close pair belonging to the immediately
preceding week. Require three to five sessions and order their gold-minus-
silver log ratios oldest to newest.

- Newest ratio strictly above every earlier ratio: SELL XAU, BUY XAG.
- Newest ratio strictly below every earlier ratio: BUY XAU, SELL XAG.
- Equality, an interior close, or invalid week membership: flat.

The package fades the completed-week closing extreme for one broker week.
Current-week prices, intraday highs/lows, and excursion magnitude do not enter
the signal.

## Locked Risk And Lifecycle

- One aggregate backtest `RISK_FIXED=1000` budget; `RISK_PERCENT=0`.
- One-to-one absolute notional target, rounded down, maximum mismatch 20%.
- Frozen `3.5*ATR(20,D1)` hard stop on each leg; no target.
- XAU/XAG spread ceilings: 1,500/500 points.
- Both news axes and Friday close OFF.
- Persist the weekly attempt before fallible entry gates; no retry.
- Flatten malformed or one-leg exposure immediately.
- Close at the first later Monday anchor; ten-calendar-day stale guard.
- No scale-in, grid, martingale, pyramid, trail, break-even, or partial exit.

## Gate Boundary

Q02 must retire below five completed packages per full post-warm-up year or on
nonpositive governed economics. Q09 alone may determine realized correlation
with the certified book. No live, demo, shadow, stress, optimization,
portfolio-gate, T_Live, manifest, or AutoTrading action is authorized.

## Revision History

| Version | Date | Change |
|---|---|---|
| v1 | 2026-08-21 | approved build-directory identity; source approval `37d65f4e0`; EA ID allocation `4a7c2d633` |
| v2 | 2026-08-21 | active basket magics `89c51ac42`; paired implementation; 10-test reference suite; Q01 strict build and static validation PASS |
