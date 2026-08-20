# WTI Fresh Three-Week Sign-Streak Momentum - Source Approval

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

- proposed slug: `wti-wstreak3-mom`
- proposed strategy ID: `MOP-WTI-WSTREAK3-MOM-2026_S01`
- proposed source ID: `MOP-WTI-WSTREAK3-MOM-2026`
- carrier: exact `XTIUSD.DWX`, D1, single slot
- state: four adjacent, non-overlapping completed broker-week returns; the
  newest three have one strict common sign and the preceding return has the
  strict opposite sign
- action: follow the fresh three-week streak direction for one broker week
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
`strategy-seeds/sources/MOP-WTI-WSTREAK3-MOM-2026/source.md`.

Moskowitz, Ooi, and Pedersen document positive own-return continuation,
mechanically map past-return sign to future position direction, and include
WTI crude oil in their commodity universe. Their tested formation and holding
horizons are monthly. They do not test a WTI-only weekly horizon, a fresh
three-week same-sign run, or the requirement that the immediately preceding
week have the opposite sign. Those are predeclared QM timing and path-state
hypotheses. No source return, density, cost, continuous-CFD equivalence, or
portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact `XTIUSD.DWX`, D1, slot zero, fixed-risk backtest inputs, both
   news axes OFF, and Friday close OFF.
2. On the first tradable D1 bar of a new Monday-anchored broker week, within
   180 elapsed minutes of its executable open, reconstruct the five most
   recent consecutive completed broker-week ending closes. Every contributing
   week must contain three to five strictly ordered sessions.
3. Apply one uniform energy-label convention to the current bar and every
   historical bar: raw labels when the current D1 date equals broker date, or
   a `+1`-calendar-day normalization only when the raw label is exactly one day
   behind. Reject every other or mixed convention.
4. From newest to oldest endpoints `C0..C4`, compute four adjacent,
   non-overlapping returns `r0=ln(C0/C1)`, `r1=ln(C1/C2)`,
   `r2=ln(C2/C3)`, and `r3=ln(C3/C4)`. Buy only when `r0`, `r1`, and `r2`
   are strictly positive and `r3` is strictly negative. Sell only when the
   newest three are strictly negative and `r3` is strictly positive. Zero,
   invalid endpoints, missing weeks, or every other sign path consumes the
   week flat.
5. Persist the exact Monday week-anchor attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker week.
6. Size one position to `RISK_FIXED=1000`, `RISK_PERCENT=0`, against a frozen
   `3.5 * ATR(20,D1)` hard stop. Use no target and cap spread at 1,500 points.
7. Close on the first tick of a later broker week or after ten calendar days.
   Never trail, partially close, scale in, grid, martingale, pyramid, or add an
   external runtime dependency.

The strict opposite predecessor makes this the first appearance of a
three-week streak. A fourth same-sign week cannot trigger a rolling re-entry.
The exact four-return state, fresh transition, direction, and one-week hold are
jointly load-bearing.

## Non-Duplicate Decision

The canonical checker scanned 4,561 registry rows and 625 root cards and
returned `CLEAN`, with no exact or fuzzy match. Manual review separates:

- `QM5_41065_wti-wflip-mom`, which follows the newest of two opposed weeks
  immediately; this candidate waits for two additional same-sign completed
  weeks and trades only the first completed three-week streak;
- `QM5_41068_wti-waccel-mom` and `QM5_41070_wti-wdecel-mom`, which require
  two same-sign weeks plus a strict return-magnitude ordering; this candidate
  uses three same-sign weeks, a strict opposite predecessor, and no magnitude
  comparison;
- `QM5_41069_wti-wpull-trend`, `QM5_41071_wti-wresume-dom`, and
  `QM5_41072_wti-wcounter-dom`, which require opposed internal weeks and
  magnitude dominance; this candidate's newest three returns cannot contain
  an opposed week and magnitude is irrelevant;
- `QM5_41022_wti-wdual-mom`, which requires sign agreement between disjoint
  Tuesday-Wednesday and Wednesday-Friday segments inside one completed week,
  not agreement across three complete weeks;
- `QM5_20273_wti-signrun-tr`, which scores a twelve-month D1 sign-run path and
  rebalances monthly, not a fresh exact three-week transition; and
- `QM5_12567_cum-rsi2-commodity`, which is a long-only two-day oscillator
  pullback rather than symmetric weekly WTI continuation.

The exact WTI carrier, five consecutive completed week-ending closes, four
adjacent weekly returns, strict `-+++` / `+---` state, consumed weekly attempt,
and full-week ownership are jointly load-bearing. Verdict:
`CLEAN_WTI_FRESH_THREE_WEEK_SIGN_STREAK_CONTINUATION_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_PATH_TRANSLATION_RISK`: named authors, peer-reviewed
  JFE paper, DOI, complete-read evidence, durable retrieval identity, explicit
  WTI membership, and the untested weekly path condition disclosed.
- R2 `PASS`: exact week anchors, session counts, endpoint selection, return
  formulas, strict sign transition, side, attempt, risk, stop, spread, and
  lifecycle are locked before testing.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 and MT5-native state provide every runtime input; Q02 owns
  history, label, density, and CFD-basis falsification.
- R4 `PASS`: deterministic timestamps and completed-price arithmetic with no
  trained logic, banned signal, external feed, grid, martingale, scale-in, or
  pyramid.

## Portfolio Claim Boundary

The candidate carries direct WTI physical-energy price risk outside the
certified XAU/SP500/NDX/XNG book and differs mechanically from certified
`QM5_12567`'s long-only two-day cumulative-RSI2 pullback. Carrier and mechanic
difference do not prove low correlation. Q09 alone may establish realized
portfolio overlap; this approval makes no decorrelation or admission claim.

## Kill And Safety Boundary

The predeclared cadence prior is approximately four to ten completed positions
per full post-warm-up year. Q02 must retire below three trades per year, at
zero trades or nonpositive governed economics, or on any label, week-anchor,
session-count, endpoint, sign, transition, side, attempt, risk, lifecycle, or
determinism defect. No weak result may be rescued by accepting zero, removing
the opposite predecessor, changing the streak length, adding a magnitude
threshold, reversing the side, changing the hold, or adding volatility,
volume, calendar, moving-average, or external state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and host-CPU checks are below their ceilings. At
the ceiling, stop before queue mutation and record a non-live handoff.

