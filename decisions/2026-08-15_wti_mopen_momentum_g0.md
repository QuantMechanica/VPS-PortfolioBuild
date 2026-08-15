# WTI Fixed Month-Opening Momentum — G0 Decision

Date: 2026-08-15

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-15_wti_mopen_momentum_source_approval.md` at commit
`97289ee9f`.

## Candidate

- EA: `QM5_41013_wti-mopen-mom` (allocated after this decision by the
  deterministic registry command)
- slug: `wti-mopen-mom`
- Strategy ID: `MOP-WTI-MOPEN-MOM-2026_S01`
- Source ID: `MOP-WTI-MOPEN-MOM-2026`
- host/traded symbol, slot, and magic: `XTIUSD.DWX`, D1, slot 0,
  `410130000`
- driver: exact prior-month-end-to-fifth-current-month-close return sign
- decision clock: first processed tick of the sixth tradable D1 bar
- lifecycle: one consumed monthly attempt, one fixed-risk WTI position,
  frozen `3.5 * ATR(20,D1)` stop, next-month replacement, thirty-five-day
  stale guard, and fixed spread cap

## Source Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-MOPEN-MOM-2026/source.md`. It binds one
translation to the completely reviewed governed MOP paper packet.

Moskowitz, Ooi, and Pedersen supply WTI membership, own-return-sign
continuation, and monthly renewal. They do not test a five-D1-bar formation,
fixed broker-month entry clock, residual-month hold, WTI alone, or the
continuous Darwinex CFD. Those distances are explicit and no source efficacy,
WTI alpha, density, cost, CFD equivalence, decorrelation, or portfolio result
transfers.

## Locked Rule

On each new WTI D1 bar:

1. Close prior-month, stale, or malformed owned exposure before entry-only
   gates; retry until flat.
2. Count completed positive finite D1 closes in the current broker month.
3. Below five bars, wait. Above five bars without a durable attempt, consume
   the month flat and never enter late.
4. At exactly five bars, persist the current `yyyymm` attempt before every
   fallible gate and never retry.
5. Require the next older completed close to be the prior broker-month-end
   close and compute the exact log return to the fifth current-month close.
6. Buy for a strictly positive return, sell for a strictly negative return,
   and remain flat on exact zero or invalid arithmetic.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
   cap. Signal magnitude never scales risk.
8. Close at the next broker-month boundary, after thirty-five calendar days,
   or on malformed owned state. Friday close and both news axes are OFF.

The carrier, first-five segmentation, prior-month anchor, sixth-bar clock,
return sign, no-late-entry policy, one-attempt state, direction, risk, stop,
spread, and lifecycle are locked.

## Reputable-Source Criteria

- R1 `PASS`: one governed source ID with a named peer-reviewed JFE paper, DOI,
  complete-paper review evidence, durable hash, and explicit translation gap.
- R2 `PASS`: fixed endpoints, count, clock, direction, attempt, risk, stop,
  spread, and exit.
- R3 `PASS`: registered `XTIUSD.DWX` D1 provides every runtime input.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,500 registry rows and 596 root-card
files and returned `CLEAN`. The expected post-draft exact hit is the card
itself. Manual review separates month-opening high/low breakout (`QM5_12810`),
rolling five-day volatility-gated momentum (`QM5_13049`), prior-full-month
TSMOM (`QM5_20187`), monthly three-close channel (`QM5_20008`), and the
incumbent multi-commodity cumulative oscillator (`QM5_12567`).

Verdict:
`CLEAN_WTI_FIXED_MONTH_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The deterministic registry command allocated `QM5_41013` after this decision
from the global next-ID sequence; no ID was inferred or hand-edited. Expected
cadence is approximately twelve completed positions per full post-warm-up
year; Q02 must retire on zero trades, below five/year, nondeterministic
segmentation, late restart entries, or nonpositive governed economics. Q09
alone may establish realized book correlation.

## Safety Boundary

Create exactly one `XTIUSD.DWX` D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests; portfolio-gate
edits; portfolio admission; and correlation waivers. Enqueue once, but do not
dispatch or control a tester when the factory resource ceiling is binding.
