# WTI Completed-Month Daily-Sign Breadth Momentum - Source Approval

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

- proposed slug: `wti-mdaybreadth-mom`
- proposed strategy ID: `MOP-WTI-MDAYBREADTH-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MDAYBREADTH-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the immediately completed broker month's close-to-close net return
  has the same strict sign as a majority of that month's daily close-to-close
  returns
- action: follow the agreed completed-month direction for one broker month
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
`strategy-seeds/sources/MOP-WTI-MDAYBREADTH-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only within-month daily-sign breadth confirmation. That confirmation is a
predeclared QM price-path choice. No source return, density, cost,
continuous-CFD equivalence, or portfolio-correlation result transfers.

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
4. Let `P` be the parent month's chronological final close. Let
   `C[0]...C[n-1]` be the newest completed month's chronological closes. Form
   exactly `n` close-to-close returns: `C[0]/P-1`, followed by
   `C[i]/C[i-1]-1` for `i=1...n-1`. Require every endpoint to be positive and
   finite. A zero return has no direction but remains in the denominator.
5. Let `up`, `down`, and `flat` count positive, negative, and zero returns,
   and let `net=C[n-1]/P-1`. Buy only when `2*up>n` and `net>0`. Sell only
   when `2*down>n` and `net<0`. A tied/non-majority path, net equality,
   breadth/net disagreement, or invalid arithmetic consumes the month flat.
   Breadth margin and return magnitude never change risk.
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

- R1 `PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested daily-sign breadth
  confirmation disclosed.
- R2 `PASS`: exact month anchors, adjacency, session counts, return endpoints,
  strict majority, strict net agreement, zero treatment, attempt, risk, stop,
  spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields and the explicit
Company Reference Wiki root, scanned 4,605 registry identities, 1,279
repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
candidate match. The receipt is
`artifacts/qm5_wti_mdaybreadth_mom_preallocation_dedup_20260822.json`.

Manual semantic review separates:

- `QM5_41084_wti-wdaybreadth-mom`, which uses one completed five-session
  broker week and holds for one week. This candidate requires two complete
  17-to-23-session calendar-month packages, uses the parent final close as the
  first return anchor, and holds for the next month.
- `QM5_20244_wti-trend-sign`, which compares a twelve-month cumulative return
  with the breadth of twelve separate monthly return signs. This candidate
  counts daily returns only inside one immediately completed month.
- `QM5_20187_wti-tsmom1m`, which follows every nonzero completed-month return
  without inspecting its daily path. This candidate requires a strict daily
  majority in the same direction.
- `QM5_41105_wti-mclose-location-mom`, which confirms monthly return with the
  completed month's OHLC close quartile, not daily return signs.
- `QM5_41106_wti-mbody-dominance-mom`, which compares one monthly real body
  with that month's high-low range and does not read the daily sign path.
- `QM5_41107_wti-minside-body-mom` and
  `QM5_41108_wti-mrange-expansion-mom`, which condition on relations between
  completed monthly OHLC packages rather than within-month daily breadth.
- `QM5_20273_wti-signrun-tr`, which studies the longest ordered run among
  twelve monthly returns, not an unordered majority of daily returns in one
  month.
- certified `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day XNG
  oscillator pullback rather than symmetric monthly WTI continuation.

The exact WTI carrier, consecutive completed calendar months, 17-to-23-session
contract, parent-final-close anchor, all newest-month close-to-close signs,
strict majority, same-sign net return, consumed monthly attempt, fixed risk,
and full-next-month hold are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SIGN_MAJORITY_NET_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Frequency, Kill, And Safety Boundary

A strict same-sign majority should retain approximately two thirds to three
quarters of monthly decisions, so the predeclared expectation is seven to ten
completed positions per full post-warm-up year. Q02 must retire below the
unchanged five-trades-per-year floor, at zero trades or nonpositive governed
economics, or on any label, month-anchor, adjacency, endpoint, sign-count,
strict-majority, agreement, attempt, risk, lifecycle, or determinism defect.
No weak result may be rescued by changing majority equality, ignoring zero
returns, reversing the sign map, changing the hold, or adding volatility,
volume, season, weekday, moving-average, inventory, event, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or `T_Live` manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict compile/Q01 PASS and fresh exact-path tester and host-CPU checks
are below their ceilings. At the ceiling, stop before queue mutation and
record a non-live handoff.
