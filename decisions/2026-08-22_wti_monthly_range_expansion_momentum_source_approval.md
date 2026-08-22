# WTI Completed-Month Range-Expansion Momentum - Source Approval

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

- proposed slug: `wti-mrange-expansion-mom`
- proposed strategy ID: `MOP-WTI-MRANGE-EXPANSION-MOM-2026_S01`
- proposed source ID: `MOP-WTI-MRANGE-EXPANSION-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: the immediately completed broker month's aggregate high-low range is
  strictly wider than its consecutive parent month's range and its own
  open-to-close body is nonzero
- action: follow the expanded completed month's own body direction for one
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
`strategy-seeds/sources/MOP-WTI-MRANGE-EXPANSION-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, explicitly
test one-month formation and one-month holding rules inside their commodity
portfolio, and include WTI crude in their universe. They do not test a
WTI-only completed-month range-expansion condition or a monthly candle-body
direction. Those are predeclared QM price-structure choices. No source
return, density, cost, continuous-CFD equivalence, or portfolio-correlation
result transfers.

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
5. Let `R0=H0-L0` and `R1=H1-L1`. Buy only when `R0>R1` and `C0>O0`. Sell
   only when `R0>R1` and `C0<O0`. Equal ranges, a narrower newest range,
   equal open/close, zero range, or invalid arithmetic consumes the month
   flat. Expansion magnitude and body magnitude never change risk.
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

- R1 `PASS_WITH_MONTHLY_RANGE_EXPANSION_TRANSLATION_RISK`: named authors,
  peer-reviewed JFE paper, DOI, complete-read evidence, durable retrieval
  identity, explicit WTI membership, and the untested completed-month range
  comparison disclosed.
- R2 `PASS`: exact month anchors, adjacency, session counts, OHLC aggregation,
  strict range inequality, body side, attempt, risk, stop, spread, and
  lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed OHLC arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker, including author and mechanic fields and the explicit
Company Reference Wiki root, scanned 4,597 registry identities, 1,276
repository cards, and 45 Strategy-Wiki nodes. It found no exact identity and
returned only expected family fuzzy hits. The receipt is
`artifacts/qm5_wti_mrange_expansion_mom_preallocation_dedup_20260822.json`.

Manual semantic review separates:

- `QM5_41102_wti-mrange-migrate-mom`, which uses the absolute location of
  both monthly range endpoints (`HH+HL` or `LH+LL`) and deliberately ignores
  opens and closes. This candidate compares range widths only and derives
  direction from the newest month's own first open and final close. A range
  may expand while its endpoints migrate in opposite directions, and a range
  may migrate while narrowing.
- `QM5_41106_wti-mbody-dominance-mom`, which reads one month and requires its
  real body to exceed half of that same month's range. This candidate requires
  two consecutive months, compares their full range widths, and imposes no
  body-share threshold.
- `QM5_41107_wti-minside-body-mom`, which requires both newest endpoints to
  lie strictly inside the parent. That necessarily makes the newest range
  narrower, so its entry state and this strict expansion state are disjoint.
- `QM5_41068_wti-waccel-mom`, which compares consecutive completed weekly
  close returns and holds for one week rather than comparing monthly OHLC
  range widths.
- `QM5_41089_wti-wrange-migrate-mom` and
  `QM5_41073_wti-woutside-settle` use weekly packages, weekly turnover, and
  different endpoint/settlement conditions.
- `QM5_20187_wti-tsmom1m`, which follows every nonzero return between two
  month-end closes. This candidate uses the newest month's first open and
  final close only after its aggregate range strictly exceeds its parent's.
- `QM5_1385_demark-td-range-expansion-h4`, whose DeMark H4 sequential setup
  is neither a WTI monthly two-package width comparison nor this lifecycle.
- certified `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day XNG
  oscillator pullback rather than symmetric monthly WTI continuation.

The exact WTI carrier, two consecutive completed calendar-month OHLC
packages, 17-to-23-session contract, strict `R0>R1`, newest-month own-body
side, equality-flat rules, consumed monthly attempt, fixed risk, and full-
next-month hold are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_RANGE_EXPANSION_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Frequency, Kill, And Safety Boundary

A strict wider-than-parent range should retain approximately half of monthly
decision opportunities, so the predeclared expectation is five to eight
completed positions per full post-warm-up year. Q02 must retire below the
unchanged five-trades-per-year floor, at zero trades or nonpositive governed
economics, or on any label, month-anchor, adjacency, aggregation, range,
body-side, attempt, risk, lifecycle, or determinism defect. No weak result may
be rescued by accepting range equality, changing the direction or hold, or
adding volatility, volume, season, weekday, moving-average, inventory, event,
or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or `T_Live` manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict compile/Q01 PASS and fresh exact-path tester and host-CPU checks
are below their ceilings. At the ceiling, stop before queue mutation and
record a non-live handoff.
