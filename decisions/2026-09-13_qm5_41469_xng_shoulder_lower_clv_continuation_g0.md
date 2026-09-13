# QM5_41469 XNG Shoulder Lower-CLV Continuation — G0 Decision

Date: 2026-09-13

Decision: `APPROVED` for one non-live V5 build, strict Q01 validation, and one
paced Q02 handoff only.

Authority: the current OWNER mission requests one new structural,
low-frequency commodity/energy sleeve, reputable-source criteria,
`RISK_FIXED` backtests, branch-only commits, and Q02 enqueue. It explicitly
names a second XNG edge with logic different from `QM5_12567` as eligible.
Live and portfolio-gate work is excluded.

## Candidate

- EA: `QM5_41469_xng-shoulder-lclv-cont`
- Strategy ID: `EIA-MOP-XNG-SHOULDER-LCLV-CONT-20260913_S01`
- Host/slot/magic: `XNGUSD.DWX`, D1, slot 0, `414690000`
- Driver: strict lower-tercile close location of exactly one completed week
  during April-May and September-October natural-gas shoulder months
- Side/lifecycle: short only; one consumed attempt per week; exit next week;
  ten-day stale repair; frozen `3.5*ATR(20,D1)` hard stop

## G0 gates

- R1: PASS with disclosed cross-source, weekly-horizon, and continuous-CFD
  translation risk.
- R2: PASS; every signal, calendar, attempt, risk, and exit rule is mechanical.
- R3: PASS; registered `XNGUSD.DWX` D1 supplies all runtime market inputs.
- R4: PASS; deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

The canonical scan found no exact collision and five fuzzy family matches.
Manual review separates the WTI carrier siblings, the upper-tercile XNG fade,
the symmetric weekly-return reversal, and the two-week sign continuation.
The unavailable external Wiki mount remains an explicit limitation rather
than an inferred pass; the OWNER-authorized repository review is the durable
approval basis.

## Locked contract

At the first tradable D1 bar of each normalized Monday-anchored April-May or
September-October week, consume the attempt, aggregate exactly the prior
completed three-to-five-session week, compute
`CLV=(close-low)/(high-low)`, and sell only for `CLV < 1/3`. Equality is flat.
Never require return sign, range rank, candle body, wick, stretch, or a moving
average. Use one fixed-risk XNG position, no target, a frozen ATR stop,
next-week exit, and no same-week retry.

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and the backtest risk
mode may be equality pinned. RNG, news, and Friday inputs remain configurable;
stress rejection receives only finiteness and inclusive `0..1` validation.

This differs from certified `QM5_12567`, which is an all-year long-only
two-day cumulative-RSI pullback above a slow trend filter. Q09 alone may
measure portfolio correlation; G0 makes no decorrelation claim.

## Allocation and safety

The deterministic identity registry allocates `QM5_41469`; slot zero is the
only authorized magic row after the governed magic-allocation step. Q02 uses
exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Authorized: source/card records, deterministic allocation, branch-only
non-live build, Q01 compile, and one paced Q02 enqueue below the CPU ceiling.
Forbidden: manual backtests, parameter sweeps, portfolio-gate changes or
admission, correlation waivers, live/deploy manifests, `T_Live`, AutoTrading,
terminal control, and live use.

