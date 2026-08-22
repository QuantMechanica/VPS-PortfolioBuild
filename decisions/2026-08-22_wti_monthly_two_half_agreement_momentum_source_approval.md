# WTI Completed-Month Two-Half Agreement Momentum - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on the `agents/board-advisor` branch on 2026-08-22. The
mission explicitly permits a structural low-frequency `XTIUSD` trend edge,
requires one new non-duplicate reputable-source card with `RISK_FIXED`
backtests, and forbids live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-mhalfagree-mom`
- proposed strategy ID: `MOP-WTI-MHALFAGREE-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MHALFAGREE-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the two exhaustive chronological cumulative-return halves of the
  immediately completed broker-calendar month have the same strict sign
- action: follow that persistent completed-month direction for the next
  broker-calendar month
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
`strategy-seeds/sources/MOP-WTI-MHALFAGREE-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only chronological two-half agreement condition. That condition is a
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
   `C[0]...C[n-1]` be all chronological closes in the newest completed month
   and set `k=floor(n/2)`. Define `half_1=log(C[k-1]/P)` and
   `half_2=log(C[n-1]/C[k-1])`. The shared midpoint is an endpoint and anchor,
   so the `n` adjacent returns from `P` through `C[n-1]` are partitioned
   exhaustively without duplication.
5. Buy only when both half returns are strictly positive. Sell only when both
   are strictly negative. Equality, sign disagreement, an invalid split,
   invalid arithmetic, malformed history, or current-month leakage consumes
   the month flat. Return magnitude never changes eligibility or sizing.
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

- R1 `PASS_WITH_MONTHLY_TWO_HALF_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested two-half confirmation
  disclosed.
- R2 `PASS`: exact month anchors, adjacency, session counts, split index,
  endpoint orientation, equality handling, strict agreement, attempt, risk,
  stop, spread, and lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields and the explicit
Company Reference Wiki root, scanned 4,610 registry identities, 1,282
repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
candidate match. The receipt is
`artifacts/qm5_wti_mhalfagree_mom_preallocation_dedup_20260822.json`.

Manual semantic review separates:

- `QM5_41021_wti-mdual-mom`, which compares the completed full-month return
  with its nested final-five-session return and holds only five new-month
  sessions. This candidate partitions the entire completed month into two
  exhaustive chronological halves and holds the full next month.
- `QM5_41023_wti-mends-mom`, which samples only fixed five-session opening and
  closing boundary segments and holds five sessions. This candidate consumes
  every adjacent return in the completed month through a deterministic
  `floor(n/2)` split and holds one month.
- `QM5_41111_wti-mdaybreadth-mom`, which counts every adjacent daily return
  sign and requires a strict majority plus endpoint agreement. This candidate
  counts no individual signs and estimates no majority; it requires two
  cumulative chronological legs to agree. A path can pass either rule and
  fail the other.
- `QM5_20187_wti-tsmom1m`, which follows every nonzero completed-month return
  without inspecting its internal path. This candidate requires both
  exhaustive half-month cumulative returns to share that direction.
- `QM5_41064_wti-mflip-mom`, which requires disagreement between two complete
  non-overlapping monthly returns. This candidate uses two within-month
  cumulative legs and requires agreement.
- `QM5_41105` through `QM5_41108`, which classify aggregate monthly OHLC
  location, body, inside-body, or range expansion rather than two cumulative
  close-path halves.
- certified `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day XNG
  oscillator pullback rather than symmetric monthly WTI continuation.

The exact WTI carrier, consecutive completed calendar months,
17-to-23-session contract, parent-final-close anchor, deterministic
`floor(n/2)` split, exhaustive non-overlapping adjacent-return halves,
strict same-sign half agreement, consumed monthly attempt, fixed risk, and
full-next-month hold are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_TWO_HALF_CUMULATIVE_RETURN_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Frequency, Kill, And Safety Boundary

Strict agreement between two completed-month halves is expected to retain
approximately five to eight decisions per full post-warm-up year. This is a
hypothesis, not imported evidence. Q02 must retire below the unchanged
five-trades-per-year floor, at zero trades or nonpositive governed economics,
or on any label, month-anchor, adjacency, split, endpoint, agreement, attempt,
risk, lifecycle, or determinism defect. No weak result may be rescued by
moving the split, accepting equality, reversing the sign map, changing the
hold, or adding volatility, volume, season, weekday, moving-average,
inventory, event, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or `T_Live` manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict compile/Q01 PASS and fresh exact-path tester and host-CPU checks
are below their ceilings. At the ceiling, stop before queue mutation and
record a non-live handoff.
