# Natural Gas Fresh Weekly Return-Sign Handoff - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one new non-duplicate,
structural, low-frequency commodity edge with reputable-source criteria and
`RISK_FIXED` backtests; explicitly permits a second XNG edge with logic
different from `QM5_12567`; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-wflip-mom`
- proposed strategy ID: `MOP-XNG-WFLIP-MOM-2026_S01`
- source ID: `MOP-XNG-WFLIP-MOM-2026`
- carrier: exact `XNGUSD.DWX`, D1, single slot
- state: strict sign change between two adjacent completed broker-week returns
- action: follow the newest completed-week sign for one broker week
- lifecycle: one persisted attempt per broker week, next-week exit

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, which records the
   complete-paper review, retrieval receipt and SHA-256 for Moskowitz, Ooi,
   and Pedersen (2012), *Time Series Momentum*, *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.
2. `strategy-seeds/sources/MOP-XNG-WFLIP-MOM-2026/source.md`, which bounds the
   adjacent-week transition test and its claim, duplicate, risk, and safety
   limits.

The paper documents positive continuation over monthly lags, mechanically
maps past own-return sign to trade direction, and includes natural gas in its
commodity universe. It does not test a natural-gas-only weekly horizon or a
fresh adjacent-week sign change. The weekly horizon and transition gate are
predeclared QM timing hypotheses. No parent or WTI-sibling result, density,
cost, CFD equivalence, or portfolio-correlation claim transfers.

## Locked Mechanic

1. Require exact `XNGUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new broker week, within 180 minutes of
   its executable open, reconstruct exactly three consecutive completed
   broker-week-end closes.
3. Compute the older and newest adjacent non-overlapping weekly log returns.
   BUY only on negative-to-positive and SELL only on positive-to-negative.
   Same signs, exact zero, or invalid arithmetic stay flat.
4. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
5. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
6. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, or add
   an external runtime dependency.

## Non-Duplicate Decision

The canonical checker scanned 4,554 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- incumbent two-day multi-commodity cumulative-RSI2 pullback in `QM5_12567`;
- thresholded low-realized-volatility five-D1 continuation in `QM5_13101`;
- bottom-quartile tick-volume weekly continuation in `QM5_21520`;
- unconditional monthly XNG continuation and contrarian siblings in
  `QM5_20204` and `QM5_20054`;
- seven-complete-week NR7 range expansion in `QM5_41063`; and
- the exact WTI carrier sibling in `QM5_41065`, whose result does not transfer.

The new identity uses XNG, two separate full close-to-close broker-week
returns, requires their signs to disagree, follows the newest sign, and owns
the next full broker week. Verdict:
`CLEAN_XNG_ADJACENT_WEEK_SIGN_HANDOFF_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_HORIZON_AND_TRANSITION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit natural-gas membership, and the untested weekly horizon
  and sign-transition condition disclosed.
- R2 `PASS`: exact week anchors, endpoints, strict transition, side, attempt,
  risk, stop, spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1
  and MT5-native state provide every runtime input; Q02 owns history, label,
  density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamp and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Kill And Safety Boundary

Expected cadence is approximately eighteen to thirty completed positions per
full post-warm-up year. Q02 must retire below five trades per year, at zero
trades or nonpositive governed economics, or on any week-anchor, endpoint,
sign, direction, attempt, risk, lifecycle, or determinism defect.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
