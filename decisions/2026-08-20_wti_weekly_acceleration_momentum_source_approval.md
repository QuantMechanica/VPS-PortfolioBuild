# WTI Completed-Week Acceleration Momentum - Source Approval

Date: 2026-08-20

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch on 2026-08-20. The mission requires one new,
non-duplicate, structural low-frequency commodity edge with reputable-source
criteria and `RISK_FIXED` backtests; explicitly permits a structural
`XTIUSD` trend edge; and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-waccel-mom`
- proposed strategy ID: `MOP-WTI-WACCEL-MOM-2026_S01`
- proposed source ID: `MOP-WTI-WACCEL-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the two immediately preceding, non-overlapping completed broker-week
  log returns have the same strict sign and the newest absolute return is
  strictly larger than the older return
- action: follow the newest completed-week sign for one broker week
- lifecycle: one persisted attempt per broker week and first-later-week flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The governed record below was read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which records a complete-paper review and durable retrieval identity for
   Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`.

The bounded child extraction is
`strategy-seeds/sources/MOP-WTI-WACCEL-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past return sign to future position direction, and include
WTI crude oil in their commodity universe. Their tested formation and holding
horizons are monthly. They do not test a WTI-only weekly horizon, adjacent
same-sign weeks, or an absolute-return acceleration condition. Those are
predeclared QM timing hypotheses. No source return, density, cost, CFD
equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its executable open, reconstruct exactly three
   consecutive completed broker-week-end closes.
3. Compute the older and newest adjacent, non-overlapping weekly log returns.
   BUY only when both are strictly positive and
   `abs(newest)>abs(older)`. SELL only when both are strictly negative and
   `abs(newest)>abs(older)`. Opposed signs, exact zero, equality, or
   non-acceleration consume the week flat.
4. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
5. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
6. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, or add
   an external runtime dependency.

## Non-Duplicate Decision

The canonical checker scanned 4,555 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_41065_wti-wflip-mom`, which requires opposite signs across the two
  completed weeks and follows a fresh sign handoff; this candidate rejects
  every opposed-sign pair and requires same-sign magnitude acceleration;
- `QM5_13049_xti-1w-mom-vol`, which thresholds one five-D1 move and admits it
  only under a realized-volatility-rank cap; this candidate uses two complete
  broker weeks and no threshold, volatility estimate, or rank;
- `QM5_21503_xti-weekly-tsmom-lowvol`, which follows one completed week only
  when five-return realized volatility ranks in a lower tercile; this
  candidate uses no volatility field and requires two same-sign weeks with a
  strict magnitude relation;
- `QM5_41022_wti-wdual-mom`, which requires agreement between opening and
  closing subsegments of one completed week; this candidate uses only two
  full close-to-close week returns; and
- `QM5_41061_wti-week-nr7-brk`, which follows a next-week close breakout after
  a seven-week range contraction; this candidate uses no high, low, range,
  rank, or breakout.

The exact WTI carrier, three week-end closes, two non-overlapping return
intervals, strict same sign, strict absolute acceleration, newest-sign
direction, consumed weekly attempt, and full-week ownership are jointly
load-bearing. Verdict:
`CLEAN_WTI_TWO_WEEK_SAME_SIGN_ACCELERATION_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_ACCELERATION_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested weekly acceleration
  gate disclosed.
- R2 `PASS`: exact week anchors, endpoints, strict state, side, attempt, risk,
  stop, spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Kill And Safety Boundary

Expected cadence is approximately eight to eighteen completed positions per
full post-warm-up year. Q02 must retire below five trades per year, at zero
trades or nonpositive governed economics, or on any week-anchor, endpoint,
sign, magnitude, direction, attempt, risk, lifecycle, or determinism defect.
No weak result may be rescued by accepting sign opposition, equality, or
deceleration, changing direction or hold, adding a return threshold, or
adding calendar, volatility, volume, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.

