# WTI Fresh Monthly Return-Sign Handoff - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one new non-duplicate,
structural, low-frequency commodity edge with reputable-source criteria and
`RISK_FIXED` backtests; explicitly names structural WTI as a candidate; and
forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mflip-mom`
- proposed strategy ID: `MOP-WTI-MFLIP-MOM-2026_S01`
- source ID: `MOP-WTI-MFLIP-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: strict sign change between two adjacent completed broker-month
  returns
- action: follow the newest completed-month sign for one broker month
- lifecycle: one persisted attempt per broker month, next-month exit

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, which records the
   complete-paper review, retrieval receipt and SHA-256 for Moskowitz, Ooi,
   and Pedersen (2012), *Time Series Momentum*, *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.
2. `strategy-seeds/sources/MOP-WTI-MFLIP-MOM-2026/source.md`, which bounds the
   adjacent-month transition test and its claim, duplicate, risk, and safety
   limits.

The paper documents positive continuation over monthly lags, mechanically
maps past own-return sign to trade direction, reports the commodity portfolio
at `k=1`, `h=1`, and includes NYMEX WTI. It does not test a WTI-only fresh
adjacent-month sign change or Darwinex CFD implementation. The transition
gate is a predeclared QM timing hypothesis. No parent or sibling result,
density, cost, CFD equivalence, or portfolio-correlation claim transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new broker month, within five minutes of
   its executable open, reconstruct exactly three consecutive completed
   broker-month-end closes.
3. Compute the older and newest adjacent non-overlapping monthly log returns.
   BUY only on negative-to-positive and SELL only on positive-to-negative.
   Same signs, exact zero, or invalid arithmetic stay flat.
4. Persist the exact broker `yyyymm` attempt before every fallible downstream
   gate. Rejection, order failure, or restart cannot retry that month.
5. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
6. Close on the first tick of a later broker month or after forty calendar
   days. Never trail, partially close, scale in, grid, martingale, pyramid, or
   add an external runtime dependency.

## Non-Duplicate Decision

The canonical checker scanned 4,551 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- unconditional monthly WTI continuation in `QM5_20187`;
- older-twelve-month trend continuation against the newest pullback in
  `QM5_20239`;
- completed-month/final-five-session agreement and five-session ownership in
  `QM5_41021`;
- current-month opening-move reversal in `QM5_41027`; and
- the incumbent two-day multi-commodity cumulative-RSI2 pullback in
  `QM5_12567`.

The new identity requires two separate full-month returns to disagree, then
trades the newest sign for the next full month. Verdict:
`CLEAN_WTI_ADJACENT_MONTH_SIGN_HANDOFF_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_CONDITIONAL_STATE_RISK`: named authors, peer-reviewed JFE
  paper, DOI, complete-read evidence, durable retrieval identity, explicit
  WTI membership, and the untested sign-transition condition disclosed.
- R2 `PASS`: exact clock, endpoints, strict transition, side, attempt, risk,
  stop, spread, and lifecycle are locked before testing.
- R3 `PASS`: registered `XTIUSD.DWX` D1 and MT5-native state provide every
  runtime input; Q02 owns history and CFD-basis falsification.
- R4 `PASS`: deterministic timestamp and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Kill And Safety Boundary

Expected cadence is five to eight completed positions per full post-warm-up
year. Q02 must retire below five trades per year, at zero trades or
nonpositive governed economics, or on any month endpoint, sign, direction,
attempt, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
