# WTI Fixed Week-Opening Segment Momentum - G0 Decision

Date: 2026-08-16

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-16_wti_week_opening_momentum_source_approval.md` at commit
`e6bc3ffff`.

## Candidate

- EA: `QM5_41019_wti-wopen-mom`, allocated by the deterministic registry
  command after source approval and semantic dedup review
- slug: `wti-wopen-mom`
- strategy ID: `MOP-WTI-WOPEN-MOM-2026_S01`
- source ID: `MOP-WTI-WOPEN-MOM-2026`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410190000`
- lifecycle: one Wednesday continuation entry from the completed
  Friday-to-Tuesday broker-week opening segment, held to Friday close

## Source Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-WOPEN-MOM-2026/source.md`. Moskowitz, Ooi,
and Pedersen (2012) supply the own-return-sign continuation family and WTI's
membership in their commodity-futures universe. They do not test this exact
weekly formation or executable CFD package.

The fixed Friday-Monday-Tuesday sequence, Wednesday entry, 180-minute restart
boundary, Friday close, CFD mapping, ATR stop, and fixed-dollar risk are QM
translation choices. No source return, coefficient, significance, cost,
density, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Rule

1. Admit decisions only on a genuine broker Wednesday D1 bar whose immediately
   preceding completed bars are exactly Tuesday, Monday, and prior Friday.
   Never shift a missing holiday session.
2. Require the first observed Wednesday tick within 180 minutes of the current
   D1 bar timestamp; consume a later observation flat.
3. Persist the exact Wednesday `yyyymmdd` attempt before history, signal,
   news, spread, quote, ATR, sizing, or order gates and never retry it.
4. Compute `log(TuesdayClose / PriorFridayClose)` from positive finite
   completed closes only. BUY on a positive sign, SELL on a negative sign,
   and stay flat on exact zero or invalid history. Monday close provides
   sequence continuity only; current Wednesday prices never enter the signal.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0` budget, frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread cap.
   Signal magnitude never scales risk.
6. Hold through the balance of the broker week and flatten with framework
   Friday close at broker hour 21. Close malformed exposure, a position still
   open on Sunday/Monday/Tuesday, or a position six calendar days old before
   entry-only gates.
7. Both news axes remain OFF. One owned position, no re-entry, scale-in,
   pyramid, grid, martingale, partial exit, trailing stop, or break-even move.

The weekday sequence, completed endpoints, sign, entry grace, no-shift and
no-retry rules, fixed risk, stop, spread, Friday close, and stale repair are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_TRANSLATION_RISK`: peer-reviewed JFE paper, named
  authors, DOI, complete-paper receipt, durable hash, WTI membership, and an
  explicit untested weekly-horizon boundary.
- R2 `PASS`: signal endpoints, weekday sequence, sign, timing, attempt, risk,
  stop, spread, and exits are deterministic and frozen.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history supplies all runtime
  inputs.
- R4 `PASS`: native deterministic arithmetic and framework state only,
  without trained output, banned signal methods, external feeds, grid,
  martingale, scale-in, or pyramid.

Both deterministic card linters returned `status: ok` before this decision
was committed.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,506 registry rows and 602 root cards
and found no exact or fuzzy match. Manual review separates:

- the fixed five-session monthly-opening momentum build, which holds to the
  next month;
- the weekly opening-range breakout, which uses Monday high/low plus trend,
  range, buffer, and close-location filters;
- the rolling thresholded five-D1 momentum build, which requires a realized-
  volatility percentile state;
- the Wednesday 252-D1 trend build;
- the Monday weekend-gap continuation build; and
- the incumbent cross-commodity cumulative-RSI2 pullback.

Verdict:
`CLEAN_WTI_FIXED_WEEK_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41019`; no ID was
inferred or hand-edited. Expected cadence is approximately 45-52 completed
positions/year. Q02 must retire on zero trades, below five/year, wrong or
shifted weekdays, current-bar leakage, late/repeated entries, weekend carry
past repair, invalid risk mode, nondeterminism, or nonpositive governed
economics. Q09 alone may establish realized portfolio correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes manual
backtests; live, demo, shadow, stress, and optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio-gate edits; portfolio
admission; and correlation waivers. Enqueue Q02 once, but do not dispatch or
control a tester when the factory resource ceiling is binding.
