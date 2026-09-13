# QM5_41465 XNG Shoulder Upper-CLV Fade — G0 Decision

Date: 2026-09-13

Decision: `APPROVED` for one non-live V5 build, strict Q01 validation, and one
paced Q02 handoff only.

Authority: the current OWNER mission requests one new structural,
low-frequency commodity/energy sleeve, reputable-source criteria,
`RISK_FIXED` backtests, branch-only commits, and Q02 enqueue. It explicitly
permits a second XNG edge whose logic differs from `QM5_12567`. Live and
portfolio-gate work is excluded.

## Candidate

- EA: `QM5_41465_xng-shoulder-hclv-fade`
- Strategy ID:
  `EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913_S01`
- Host/slot/magic: `XNGUSD.DWX`, D1, slot 0, `414650000`
- Driver: strict upper-tercile close location of exactly one completed week
  during April, May, September, and October
- Side/lifecycle: short only; one consumed attempt per week; exit next week;
  ten-day stale repair; frozen `3.5*ATR(20,D1)` hard stop

## G0 gates

- R1: PASS with disclosed cross-source/horizon and CFD translation risk.
- R2: PASS; every signal, calendar, attempt, risk, and exit rule is mechanical.
- R3: PASS; registered `XNGUSD.DWX` D1 supplies all runtime market inputs.
- R4: PASS; deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

The canonical scan found no exact collision and one expected WTI fuzzy match.
Manual review separates that carrier/calendar sibling and the XNG return-sign,
two-week, SMA/stretch/wick, and certified cumulative-RSI families. The
unavailable external Wiki mount remains an explicit limitation rather than an
inferred pass; the OWNER-authorized repository review is the durable approval
basis.

## Locked contract

At the first tradable D1 bar of each normalized Monday-anchored April-May or
September-October week, consume the attempt, aggregate exactly the prior
completed three-to-five-session week, compute
`CLV=(close-low)/(high-low)`, and sell only for `CLV > 2/3`. Equality is flat.
Never require return sign, range rank, candle body, wick, stretch, or a moving
average. Use one fixed-risk XNG position, no target, a frozen ATR stop,
next-week exit, and no same-week retry.

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and the backtest risk
mode may be equality pinned. RNG, news, and Friday inputs remain configurable;
stress rejection receives only finiteness and inclusive `0..1` validation.

## Allocation and safety

The deterministic identity registry allocated `QM5_41465`; slot zero is the
only authorized magic row after the governed magic-allocation step. Q02 uses
exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No manual backtest, optimization, demo/shadow/live set, terminal control,
portfolio admission/gate change, correlation waiver, deploy/live manifest,
`T_Live`, or AutoTrading action is authorized.
