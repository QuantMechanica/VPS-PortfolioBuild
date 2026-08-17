# G0 Decision - QM5_41051 WTI Exact-Week Pullback / Friday Bounce

Date: 2026-08-17

Decision: `APPROVED`

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch, bounded by
`decisions/2026-08-17_wti_friday_week_pullback_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41051_wti-fri-weekfade_card.md`.

## Identity

- EA ID: `QM5_41051`, deterministically allocated in commit `5ec8bb097`
- slug: `wti-fri-weekfade`
- strategy ID: `GORSKA-YANG-WTI-FRIWEEKFADE-2026_S01`
- source approval commit: `286fd512d`
- carrier: exact `XTIUSD.DWX`, D1, slot 0
- registered magic: `410510000`, resolver-sealed in commit `b52124e1b`
- mechanic: on a genuine Friday after an exact completed Monday-through-
  Thursday week, buy WTI only when `ln(ThursdayClose / MondayOpen) < 0`, then
  flatten through the framework Friday cutoff

## Gate Findings

- R1 `PASS_WITH_COMPOSITE_AND_WORKING_PAPER_RISK`: a named academic WTI
  calendar paper supplies the positive Friday direction and a named commodity
  reversal working paper supplies only broad structural lineage. The exact
  short-horizon conjunction is an untested QM translation.
- R2 `PASS`: exact weekday sequence, uniform energy-label convention,
  completed endpoints, strict negative-only state, long direction, durable
  attempt, entry grace, fixed risk, hard stop, spread cap, and Friday
  lifecycle are mechanical.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 OHLC,
  quotes, calendar, positions, deal history, and terminal state provide every
  runtime input; the broker-label convention remains falsifiable.
- R4 `PASS`: closed-form calendar and log-return arithmetic only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, hedge, or pyramid.

## Duplicate Review

The canonical pre-allocation checker scanned 4,538 registry rows and 625 card
files and returned `CLEAN` with no exact or fuzzy identity. Manual review
confirms:

- `QM5_12753` reads only a thresholded Thursday close-to-close decline;
- `QM5_20117` shorts a large Thursday surge;
- `QM5_12597` is unconditional Friday long;
- `QM5_20145` and `QM5_20172` use completed 252-D1 regimes;
- `QM5_41026` uses the first Friday and prior calendar-month endpoints;
- `QM5_41019` through `QM5_41022` form earlier or prior-week momentum and
  enter before Friday; and
- `QM5_12567` is a short-horizon XNG oscillator pullback.

Verdict:
`CLEAN_WTI_EXACT_MONDAY_THURSDAY_LOSS_FRIDAY_BOUNCE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 and magic `410510000`;
- native same-day or one uniform `+1` energy-label normalization only;
- current Friday plus exact completed Thursday, Wednesday, Tuesday, and
  Monday at calendar offsets one through four, with no substitution;
- first-Friday observation within 180 minutes and one durable `yyyymmdd`
  attempt persisted before every fallible entry gate;
- `ln(ThursdayClose / MondayOpen)` from completed bars only;
- BUY only for a finite strictly negative value; zero, positive, invalid,
  late, or broken-calendar states consume Friday flat;
- one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` D1 backtest
  setfile;
- one frozen `3.0 * ATR(20,D1)` hard stop, no target, and a 1,500-point
  spread ceiling;
- both news axes OFF, framework Friday close ON at broker hour 21, first-
  later-D1 repair, and a three-day stale guard; and
- deterministic reference tests, strict compile, set/registry checks, and
  static Q01 validation before Q02 handoff.

No magnitude threshold, Thursday-only return, prior-week or prior-month
return, slow trend, moving mean, oscillator, inventory data, volatility
signal, external runtime input, retry, scale-in, grid, martingale, hedge,
pyramid, optimization surface, or after-result rescue is approved.

## Pipeline And Safety Boundary

Approval authorizes the branch-only non-live build, one `RISK_FIXED` backtest
setfile, strict Q01, and one paced target-only Q02 enqueue only below the
governed tester and CPU ceilings. It does not authorize a manual tester
dispatch or tester control.

Expected cadence is approximately twenty to twenty-five completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than
five/year, nonpositive governed economics, wrong weekday/endpoints, current-
Friday signal leakage, late/repeated entry, wrong side, missing stop, wrong
lifecycle, invalid risk mode, nondeterminism, or an unusable label convention.
Q09 alone may establish realized book correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.

