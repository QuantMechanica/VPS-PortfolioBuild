# XNG Completed-Week Close-Location Momentum - Source Approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on the `agents/board-advisor` branch on 2026-08-21. The mission
requires one new, non-duplicate, structural low-frequency commodity edge under
the reputable-source criteria and `RISK_FIXED` backtests; explicitly permits a
second `XNGUSD` edge only when its logic differs from `QM5_12567`; and forbids
live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xng-wclose-location-mom`
- proposed strategy ID: `MOP-XNG-WCLOSE-LOCATION-MOM-2026_S01`
- proposed source ID: `MOP-XNG-WCLOSE-LOCATION-MOM-2026`
- carrier: exact `XNGUSD.DWX`, D1, single slot
- state: the immediately completed broker week's strict close-to-close return
  sign agrees with a strict close location above `0.80` or below `0.20` inside
  that completed week's own high-low range
- action: follow the confirmed completed-week direction for one broker week
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
`strategy-seeds/sources/MOP-XNG-WCLOSE-LOCATION-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, and include
natural gas in their commodity universe. Their tested formation and holding
horizons are monthly. They do not test an XNG-only weekly horizon, a completed
week's close location, or the `0.80` / `0.20` confirmation thresholds. Those
are predeclared QM timing and price-structure hypotheses. No source return,
density, cost, continuous-CFD equivalence, or portfolio-correlation result
transfers.

## Locked Mechanic

1. Require exact `XNGUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its executable open, reconstruct the immediately
   completed broker week and its consecutive parent week from completed D1
   history. Each week must contain three to five strictly ordered sessions.
3. Apply one uniform energy-label convention to the current bar and every
   historical bar: raw labels when the current D1 date equals broker date, or
   a `+1`-calendar-day normalization only when the raw label is exactly one
   day behind. Reject every other or mixed convention.
4. Let `C0` be the final close, `H0` the high, and `L0` the low of the newest
   completed week, and let `C1` be the parent week's final close. Require
   positive finite endpoints and `H0>L0`. Compute
   `r=ln(C0/C1)` and `clv=(C0-L0)/(H0-L0)`.
5. Buy only when `r>0` and `clv>0.80`. Sell only when `r<0` and `clv<0.20`.
   Equality, zero return, zero range, an interior close, or any disagreement
   consumes the week flat. Return or close-location magnitude never scales
   risk.
6. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, stop, or restart cannot retry
   that broker week.
7. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
8. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, hedge,
   or add an external runtime dependency.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit natural-gas membership, and the untested weekly
  close-location confirmation disclosed.
- R2 `PASS`: exact week anchors, session counts, OHLC aggregation, completed
  endpoints, return sign, strict close-location thresholds, side, attempt,
  risk, stop, spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XNGUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed OHLC arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields, scanned 4,568
registry rows and 625 root cards and returned `CLEAN`, with no exact or fuzzy
match. Manual family review separates:

- `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day cumulative-
  RSI2 pullback under a slow mean with a five-bar maximum hold; this candidate
  is symmetric, oscillator-free, evaluates completed weeks, and owns one full
  broker week;
- `QM5_20204_xng-tsmom1m`, which follows one completed calendar-month return
  for a month without a weekly range-position condition;
- `QM5_41067_xng-wflip-mom`, which requires two adjacent non-overlapping
  weekly return signs to oppose and never aggregates a completed weekly
  high-low range;
- `QM5_13101_xng-1w-mom-vol` and `QM5_21520_xng-flow-mom`, which gate a
  rolling five-D1 return with a realized-volatility rank or native tick-volume
  rank; this candidate consumes neither rank nor volume;
- `QM5_41063_xng-week-nr7-brk`, which ranks seven completed weekly ranges and
  waits for a current-week breakout rather than entering from completed-week
  settlement; and
- `QM5_41080_wti-wclose-location-mom`, the exact WTI carrier sibling. This
  approval is a separately predeclared natural-gas carrier falsification and
  inherits no WTI pipeline result.

The exact XNG carrier, two consecutive completed weekly packages, newest-week
high-low aggregation, parent-close-to-new-close sign, strict own-range `0.80`
/ `0.20` close location, consumed weekly attempt, and full-next-week hold are
jointly load-bearing. Verdict:
`CLEAN_XNG_COMPLETED_WEEK_RETURN_SIGN_WITH_OWN_RANGE_CLOSE_LOCATION_CONFIRMATION_AFTER_FAMILY_REVIEW`.

## Portfolio Claim Boundary

The candidate differs mechanically and temporally from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback, but the shared XNG
carrier does not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation, waiver, or admission
claim.

## Kill And Safety Boundary

Expected cadence is approximately ten to twenty-five completed positions per
full post-warm-up year. Q02 must retire below five trades per year, at zero
trades or nonpositive governed economics, or on any label, week-anchor,
aggregation, endpoint, close-location, side, attempt, risk, lifecycle, or
determinism defect. No weak result may be rescued by accepting equality,
moving either close-location boundary, dropping return-sign agreement,
reversing the side, changing the hold, or adding volatility, volume, calendar,
moving-average, inventory, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.

