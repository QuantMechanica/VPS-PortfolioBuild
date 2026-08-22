# WTI Completed-Month Body-Dominance Momentum - Source Approval

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

- proposed slug: `wti-mbody-dominance-mom`
- proposed strategy ID: `MOP-WTI-MBODY-DOMINANCE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MBODY-DOMINANCE-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the immediately completed broker month's strict open-to-close real
  body occupies more than one half of that month's aggregate high-low range
- action: follow the completed monthly body's direction for one broker month
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
`strategy-seeds/sources/MOP-WTI-MBODY-DOMINANCE-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only completed-month real-body condition or a strict one-half body-share
threshold. Those are predeclared QM price-structure choices. No source return,
density, cost, continuous-CFD equivalence, or portfolio-correlation result
transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable normalized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw open, reconstruct the immediately
   completed month from completed D1 history. It must contain 17 through 23
   unique, strictly ordered sessions.
3. Apply one uniform energy-label convention to the current bar and every
   historical bar: raw labels when the current D1 date equals broker date, or
   a `+1`-calendar-day normalization only when the raw label is exactly one
   day behind. Reject every other or mixed convention.
4. Let `O0` be the chronologically first open, `C0` the chronologically final
   close, `H0` the aggregate high, and `L0` the aggregate low of that completed
   month. Require positive finite OHLC, `H0>L0`, and all component bars valid.
5. Define `body=abs(C0-O0)` and `range=H0-L0`. Buy only when
   `2*body>range` and `C0>O0`. Sell only when `2*body>range` and `C0<O0`.
   Threshold equality, body equality, zero range, or invalid arithmetic
   consumes the month flat. Body magnitude beyond qualification never changes
   risk.
6. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, stop, or restart cannot retry
   that month.
7. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap entry spread at 1,500
   points.
8. Close on the first tick of a later broker month or after forty calendar
   days. Never trail, partially close, scale in, grid, martingale, pyramid,
   hedge, or add an external runtime dependency.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_BODY_TRANSLATION_RISK`: named authors, peer-reviewed
  JFE paper, DOI, complete-read evidence, durable retrieval identity, explicit
  WTI membership, and the untested completed-month body-share state disclosed.
- R2 `PASS`: exact month anchor, session count, OHLC aggregation, strict body-
  share inequality, side, attempt, risk, stop, spread, and lifecycle are locked
  before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed OHLC arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields, scanned 4,595
registry identities, 1,274 repository cards, and 45 Strategy-Wiki nodes. It
found no exact identity and returned only the expected body-family fuzzy hits.
The receipt is
`artifacts/qm5_wti_mbody_dominance_mom_preallocation_dedup_20260822.json`.

Manual semantic review separates:

- `QM5_41092_wti-wbody-dominance-mom`, which aggregates one three-to-five-
  session broker week, requires a strict two-thirds body share, and owns one
  subsequent week. This candidate aggregates one 17-to-23-session calendar
  month, predeclares a strict majority body share, decides at most twelve times
  per year, and owns the next full month. Formation horizon, state threshold,
  financing exposure, turnover, and lifecycle differ; no weekly result
  transfers.
- `QM5_41094_xng-wbody-dominance-mom`, which is both a weekly clock and a
  natural-gas carrier. This candidate is monthly direct WTI.
- `QM5_20187_wti-tsmom1m`, which follows every nonzero return between two
  completed month-end closes. This candidate uses one completed month's first
  open and final close, additionally requires its real body to occupy a strict
  majority of its own aggregate range, and remains flat after weak bodies.
  Month-boundary gaps can also make the two direction states disagree.
- `QM5_41105_wti-mclose-location-mom`, which compares consecutive month-end
  closes and requires the newest close in the matching outer quartile. This
  candidate needs no parent-month close and instead makes the newest month's
  first open and strict body-to-range share load-bearing.
- `QM5_41102_wti-mrange-migrate-mom`, which compares aggregate highs and lows
  across two months and deliberately excludes opens and closes. This candidate
  compares no endpoints across months.
- `QM5_41091_wti-winside-body-mom`, which requires weekly parent-range
  containment and follows any nonzero contained-week body. This candidate has
  no parent geometry and requires one completed calendar month's strict
  majority body; and
- certified `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day XNG
  oscillator pullback rather than symmetric monthly WTI continuation.

The exact WTI carrier, immediately completed calendar-month OHLC package,
17-to-23-session contract, first-open/final-close body, strict
`2*body>range` condition, own-body side, threshold-equality-flat rule,
consumed monthly attempt, fixed risk, and full-next-month hold are jointly
load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_MAJORITY_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Kill And Safety Boundary

Expected cadence is approximately five to nine completed positions per full
post-warm-up year. Q02 must retire below five trades per year, at zero trades
or nonpositive governed economics, or on any label, month-anchor,
aggregation, body-share, side, attempt, risk, lifecycle, or determinism defect.
No weak result may be rescued by accepting equality, lowering the one-half
threshold, reversing the side, changing the hold, or adding volatility,
volume, season, weekday, moving-average, inventory, event, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.
