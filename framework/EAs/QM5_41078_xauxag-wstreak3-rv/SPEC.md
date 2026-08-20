# QM5_41078 XAU/XAG Fresh Three-Week Sign-Streak Reversion

## Identity

- EA: `QM5_41078_xauxag-wstreak3-rv`
- Strategy ID: `SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41078_xauxag-wstreak3-rv_card.md`
- Exact host: `XAUUSD.DWX`, D1, slot 0, magic `410780000`
- Exact companion: `XAGUSD.DWX`, D1, slot 1, magic `410780001`
- Logical symbol: `QM5_41078_XAU_XAG_WSTREAK3_RV_D1`

## Mechanic

On the first tradable bar of a new Monday-anchored broker week, reconstruct
five consecutive synchronized completed week-end close pairs. Let `s0` be the
newest completed gold-minus-silver log price and `s4` the oldest, with adjacent
weekly returns `r0=s0-s1` through `r3=s3-s4`.

- `r0,r1,r2>0` and `r3<0`: SELL XAU, BUY XAG.
- `r0,r1,r2<0` and `r3>0`: BUY XAU, SELL XAG.
- Every zero or other sign path: flat.

The strict opposite predecessor makes the three-week streak fresh. The
package fades the streak for one broker week. Current-week prices and return
magnitudes do not enter the signal.

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
| v1 | 2026-08-21 | approved build-directory identity; source approval `83ec155ac`; EA ID allocation `a9f8e1214` |
| v2 | 2026-08-21 | Q01 build complete; paired V5 EA, 10 reference tests, strict compile/build PASS, and static P1 PASS |
