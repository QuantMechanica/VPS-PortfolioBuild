# WTI Completed-Month Close-Location Momentum - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and host-CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on the `agents/board-advisor` branch on 2026-08-22. The
mission explicitly permits a structural low-frequency `XTIUSD` trend edge,
requires one new non-duplicate reputable-source card with `RISK_FIXED`
backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mclose-location-mom`
- proposed strategy ID: `MOP-WTI-MCLOSE-LOCATION-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MCLOSE-LOCATION-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the immediately completed broker month's strict close-to-close
  return sign agrees with a strict close location above `0.75` or below
  `0.25` inside that completed month's aggregate high-low range
- action: follow the confirmed completed-month direction for one broker month
- lifecycle: one persisted attempt per broker month and first-later-month flat

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

The bounded child extraction will be
`strategy-seeds/sources/MOP-WTI-MCLOSE-LOCATION-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only completed-month close-location condition or the `0.75` / `0.25`
confirmation thresholds. Those are predeclared QM price-structure choices.
No source return, density, cost, continuous-CFD equivalence, or portfolio-
correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable normalized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw open, reconstruct the immediately
   completed month and its consecutive parent month from completed D1
   history. Each month must contain 17 through 23 unique, strictly ordered
   sessions.
3. Apply one uniform energy-label convention to the current bar and every
   historical bar: raw labels when the current D1 date equals broker date, or
   a `+1`-calendar-day normalization only when the raw label is exactly one
   day behind. Reject every other or mixed convention.
4. Let `C0` be the final close, `H0` the aggregate high, and `L0` the
   aggregate low of the newest completed month, and let `C1` be the final
   close of its parent month. Require positive finite endpoints and `H0>L0`.
   Compute `r=ln(C0/C1)` and `clv=(C0-L0)/(H0-L0)`.
5. Buy only when `r>0` and `clv>0.75`. Sell only when `r<0` and `clv<0.25`.
   Equality, zero return, zero range, an interior close, or disagreement
   consumes the month flat. Signal magnitude never changes risk.
6. Persist the exact `yyyymm` attempt before every fallible downstream gate.
   Rejection, order failure, stop, or restart cannot retry that month.
7. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap entry spread at 1,500
   points.
8. Close on the first tick of a later broker month or after forty calendar
   days. Never trail, partially close, scale in, grid, martingale, pyramid,
   hedge, or add an external runtime dependency.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_CLOSE_LOCATION_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested close-location
  confirmation disclosed.
- R2 `PASS`: exact month anchors, session counts, OHLC aggregation, completed
  endpoints, return sign, strict close-location thresholds, side, attempt,
  risk, stop, spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed OHLC arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields, scanned 4,594
registry rows, 1,273 repository cards, and 45 Strategy-Wiki nodes. It found
no exact identity and returned expected family-level fuzzy hits. The receipt
is
`artifacts/qm5_wti_mclose_location_mom_preallocation_dedup_20260822.json`.

Manual semantic review separates:

- `QM5_41080_wti-wclose-location-mom`, which aggregates two three-to-five-
  session broker weeks, uses strict outer-fifth thresholds, and owns one
  subsequent week. This candidate aggregates two 17-to-23-session calendar
  months, uses predeclared outer-quartile thresholds, decides at most twelve
  times per year, and owns the next full month. Formation sample, auction
  horizon, financing exposure, threshold, turnover, and lifecycle differ;
  no weekly result transfers.
- `QM5_41081_xng-wclose-location-mom`, which is both a weekly clock and a
  natural-gas carrier. This candidate is monthly direct WTI.
- `QM5_20187_wti-tsmom1m`, which follows every nonzero completed-month return
  sign using month-end closes only. This candidate additionally requires the
  final close to remain in the matching outer quartile of the completed
  month's aggregate range; an interior or contradictory settlement is flat.
- `QM5_41016_wti-mclose-mom` and `QM5_41021_wti-mdual-mom`, which trade a
  final-five-session segment into only the first five next-month sessions.
  This candidate uses a full completed calendar-month range and holds the
  full next month.
- `QM5_41102_wti-mrange-migrate-mom`, which compares aggregate highs and lows
  across two months and never reads a close. This candidate requires neither
  endpoint migration nor range comparison; it combines close-to-close sign
  with the newest month's own close location.
- `QM5_41087_wti-wr4-close-mom`, `QM5_41073_wti-woutside-settle`, and
  `QM5_41091_wti-winside-body-mom`, which require weekly compression,
  parent-range geometry, or own-week body states absent here; and
- certified `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day XNG
  oscillator pullback rather than symmetric monthly WTI continuation.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23-session contract, parent-close-to-new-close sign, newest-month own-
range `0.75` / `0.25` close location, consumed monthly attempt, and full-next-
month hold are jointly load-bearing. Manual verdict:
`CLEAN_AFTER_EXPECTED_WEEKLY_CLOSE_LOCATION_FAMILY_FUZZY_REVIEW`.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Kill And Safety Boundary

Expected cadence is approximately six to ten completed positions per full
post-warm-up year. Q02 must retire below five trades per year, at zero trades
or nonpositive governed economics, or on any label, month-anchor,
aggregation, endpoint, close-location, side, attempt, risk, lifecycle, or
determinism defect. No weak result may be rescued by accepting equality,
moving either close-location boundary, dropping return-sign agreement,
reversing the side, changing the hold, or adding volatility, volume, season,
weekday, moving-average, inventory, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
