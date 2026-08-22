# WTI Completed-Month Inside-Body Momentum - Source Approval

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

- proposed slug: `wti-minside-body-mom`
- proposed strategy ID: `MOP-WTI-MINSIDE-BODY-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MINSIDE-BODY-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the immediately completed broker month is strictly contained inside
  its consecutive parent month and has a nonzero open-to-close body
- action: follow the contained completed month's own body direction for one
  broker month
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
`strategy-seeds/sources/MOP-WTI-MINSIDE-BODY-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only completed inside-month condition or a contained-month candle body.
Those are predeclared QM price-structure choices. No source return, density,
cost, continuous-CFD equivalence, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable normalized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw open, reconstruct the immediately
   completed month and its consecutive parent from completed D1 history. Each
   month must contain 17 through 23 unique, strictly ordered sessions.
3. Apply one uniform energy-label convention to the current bar and every
   historical bar: raw labels when the current D1 date equals broker date, or
   a `+1`-calendar-day normalization only when the raw label is exactly one
   day behind. Reject every other or mixed convention.
4. For newest completed month zero and parent month one, let `O`, `H`, `L`,
   and `C` be chronologically first open, aggregate high, aggregate low, and
   chronologically final close. Require positive finite OHLC, `H>L`, valid
   component geometry, and exact consecutive month membership.
5. Require strict containment `H0<H1 && L0>L1`. Buy only when containment
   holds and `C0>O0`. Sell only when containment holds and `C0<O0`. Equal
   highs, equal lows, equal open/close, non-inside geometry, zero range, or
   invalid arithmetic consumes the month flat. Containment width and body
   magnitude never change eligibility or risk.
6. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, stop, or restart cannot retry
   that month.
7. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap entry spread at 1,500
   points.
8. Close on the first tick of a later broker month or after forty calendar
   days. Never trail, partially close, scale in, grid, martingale, pyramid,
   hedge, reverse, or add an external runtime dependency.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_INSIDE_BODY_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested completed inside-month
  state disclosed.
- R2 `PASS`: exact month anchors, adjacency, session counts, OHLC aggregation,
  strict containment, body side, attempt, risk, stop, spread, and lifecycle
  are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed OHLC arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields and the explicit
Company Reference Wiki root, scanned 4,596 registry identities, 1,275
repository cards, and 45 Strategy-Wiki nodes. It found no exact identity and
returned only expected family fuzzy hits. The receipt is
`artifacts/qm5_wti_minside_body_mom_preallocation_dedup_20260822.json`.

Manual semantic review separates:

- `QM5_41091_wti-winside-body-mom`, which aggregates two consecutive
  three-to-five-session broker weeks and owns one subsequent week. This
  candidate aggregates two 17-to-23-session calendar months, decides at most
  twelve times per year, and owns the next full month. Formation sample,
  auction horizon, turnover, financing exposure, and lifecycle differ; no
  weekly result transfers.
- `QM5_41102_wti-mrange-migrate-mom`, which requires both newest monthly
  range endpoints to migrate beyond the parent's endpoints in the same
  direction and deliberately excludes opens and closes. This candidate
  requires the opposite range relation, strict containment, and derives side
  solely from the contained month's own open and close.
- `QM5_41106_wti-mbody-dominance-mom`, which uses one completed month, has no
  parent geometry, and requires a strict majority body share. This candidate
  uses two consecutive months, requires strict containment, and imposes no
  body-to-range threshold.
- `QM5_20187_wti-tsmom1m`, which follows every nonzero return between two
  month-end closes. This candidate uses the newest month's first open and
  final close only after its full range is strictly inside its parent.
- `QM5_13075_xti-inweek-brk`, which freezes a weekly inside range and waits
  for a current-week D1 close beyond an extreme with additional channel and
  exit logic. This candidate consumes no current-month signal OHLC and enters
  only at a calendar-month boundary from completed monthly geometry.
- `QM5_12810_wti-month-orb`, which trades a breakout of the new month's first
  five D1 bars, rather than a completed inside-month body at the boundary.
- certified `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day XNG
  oscillator pullback rather than symmetric monthly WTI continuation.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23-session contract, strict full containment, contained-month own-body
sign, equality-flat rules, consumed monthly attempt, fixed risk, and full-
next-month hold are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_INSIDE_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Kill And Safety Boundary

Expected cadence is approximately two to six completed positions per full
post-warm-up year. Q02 must retire below two trades per year, at zero trades
or nonpositive governed economics, or on any label, month-anchor, adjacency,
aggregation, containment, body-side, attempt, risk, lifecycle, or determinism
defect. No weak result may be rescued by accepting equality, dropping either
containment bound, changing the body side or hold, or adding volatility,
volume, season, weekday, moving-average, inventory, event, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or `T_Live` manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
