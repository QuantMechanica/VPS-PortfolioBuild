# QM5_41463 WTI Winter Upper-CLV Continuation — G0 Decision

Date: 2026-09-13

Decision: `APPROVED` for one non-live V5 build, strict Q01 validation, and one
paced Q02 handoff only.

Authority: the current OWNER mission requests one new structural,
low-frequency commodity/energy sleeve, reputable-source criteria,
`RISK_FIXED` backtests, branch-only commits, and Q02 enqueue. Live and
portfolio-gate work is excluded.

## Candidate

- EA: `QM5_41463_wti-winter-hclv-cont`
- Strategy ID:
  `BURAKOV-CRABEL-MOP-WTI-WINTER-HCLV-CONT-20260913_S01`
- Host/slot/magic: `XTIUSD.DWX`, D1, slot 0, `414630000`
- Driver: strict upper-tercile close location of exactly one completed week
  during November through May
- Side/lifecycle: long only; one consumed attempt per week; exit next week;
  ten-day stale repair; frozen `3.5*ATR(20,D1)` hard stop

## G0 gates

- R1: PASS with disclosed cross-source/horizon and CFD translation risk.
- R2: PASS; every signal, calendar, attempt, risk, and exit rule is mechanical.
- R3: PASS; registered `XTIUSD.DWX` D1 supplies all runtime market inputs.
- R4: PASS; deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, or martingale.

The canonical scan found no exact or fuzzy repository duplicate. Manual
review separates two-week range-state siblings and calendar-month sign
siblings. The unavailable external Wiki mount remains an explicit limitation
rather than an inferred pass; the OWNER-authorized repository review is the
durable approval basis.

## Locked contract

At the first tradable D1 bar of each normalized Monday-anchored November-May
week, consume the attempt, aggregate exactly the prior completed three-to-five
session week, compute `CLV=(close-low)/(high-low)`, and buy only for
`CLV > 2/3`. Equality is flat. Never require range rank or body sign. Use one
fixed-risk WTI position, no target, a frozen ATR stop, next-week exit, and no
same-week retry.

Only `strategy_*`, `qm_ea_id`, `qm_magic_slot_offset`, and the backtest risk
mode may be equality pinned. RNG, news, and Friday inputs remain configurable;
stress rejection receives only finiteness and inclusive `0..1` validation.

## Allocation and safety

The deterministic registry allocated `QM5_41463`; slot zero is the only
authorized magic row after the governed magic-allocation step. Q02 uses
exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

No manual backtest, optimization, demo/shadow/live set, terminal control,
portfolio admission/gate change, correlation waiver, deploy/live manifest,
`T_Live`, or AutoTrading action is authorized.

