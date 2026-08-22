# Q00 Decision - QM5_41110 XAU/XAG Monthly Outside-Range Residence Reversion

Date: 2026-08-22

Decision: `APPROVED`

Authority: current explicit OWNER commodity/energy portfolio instruction on
branch `agents/board-advisor`, bounded by
`decisions/2026-08-22_xauxag_monthly_outside_range_residence_reversion_source_approval.md`
at commit `58523766b`.

Approved card:
`strategy-seeds/cards/approved/QM5_41110_xauxag-moutside-res-rv_card.md`.

## Identity

- EA ID: `QM5_41110`, allocated atomically by the governed registry allocator
  at commit `5c35ee622`;
- slug: `xauxag-moutside-res-rv`;
- strategy ID: `SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026_S01`;
- source ID: `SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026`;
- source authorization: `58523766b`;
- bounded source extraction: `7df05e3f7`;
- host: exact `XAUUSD.DWX`, D1, slot zero, planned magic `411100000`;
- companion: exact `XAGUSD.DWX`, D1, slot one, planned magic `411100001`; and
- mechanic: fade a completed gold/silver ratio month only after at least five
  synchronized closes beyond one parent-month range boundary, no opposite
  boundary breach, and a chronological final close still outside.

## Deterministic Approval Result

`framework/scripts/skill_card_schema_lint.py` returned `status=ok`, with no
missing sections and no prohibited-token hits.
`framework/scripts/skill_g0_card_lint.py` returned `status=ok`, with no missing
fields. The canonical `farmctl.py approve-card` command returned
`approved=true` for `QM5_41110` after its registered custom-history admission
check and stamped the declared frequency, PF prior, drawdown prior, and Q00
reasoning into the card.

The PF, drawdown, and frequency values are conservative ordering estimates
only. They are not gate evidence, expected-performance promises, or
substitutes for Q02.

## Gate Findings

- R1 `PASS_WITH_MONTHLY_OUTSIDE_RANGE_TRANSLATION_RISK`: the bounded source
  uses a named-author, peer-reviewed DOI lineage and official CME carrier
  research. The exact residence conjunction is untested and no source result
  transfers.
- R2 `PASS`: calendar adjacency, synchronized session membership, fixed unit
  log ratio, parent range, outside counts, one-sidedness, final-close state,
  attempt, aggregate fixed risk, stops, spreads, and lifecycle are mechanical.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state provide every
  runtime input. Q02 owns alignment, density, fill, cost, and continuous-CFD
  falsification.
- R4 `PASS`: deterministic timestamps, completed closes, comparisons, ATR,
  quotes, positions, deals, and terminal state only; no banned signal, trained
  output, external feed, adaptive fit, grid, martingale, scale-in, or pyramid.

## Duplicate Review

Before allocation, the canonical checker scanned 4,599 EA-registry rows and
1,278 repository cards and found no exact or fuzzy match. Its configured
default Strategy-Wiki root was unavailable, so that receipt correctly remained
`INPUT_ERROR_FAIL_CLOSED` rather than claiming a false clean verdict.

After allocation, the checker was rerun against the governed Company Reference
Wiki path. It scanned 4,600 registry rows, 1,278 cards, and 45 Wiki nodes. The
only matches were the expected exact slug and strategy-ID self-hits on
`QM5_41110`; no second identity owns either key. Repository-wide exact and
semantic search found no pre-existing EA with the complete signal and
lifecycle.

Manual family review separates the candidate from:

- `QM5_20157_xau-xag-ratio`, which fades a rolling 60-day standardized ratio;
  this candidate uses exact calendar packages and no fitted center or scale.
- `QM5_20161_xauxag-ols-rv`, which fits a rolling hedge residual; this
  candidate uses a fixed unit log ratio.
- `QM5_20254_xauxag-vr-fade`, which combines a rolling z-score and monthly
  variance-ratio gate; this candidate computes neither.
- `QM5_41079_xauxag-wclose-extreme-rv`, which locates one final weekly ratio
  close inside its own week's range; this candidate counts persistent closes
  beyond a separate parent month's range.
- `QM5_41085_xauxag-wdaybreadth-rv`, which counts adjacent within-week return
  signs; this candidate counts levels beyond fixed parent boundaries.
- `QM5_41103_xauxag-mrange-migrate-rv`, which compares both range endpoints;
  this candidate instead requires five actual outside observations, zero
  opposite breach, and a still-outside final close.
- `QM5_41104_xauxag-mmedian-shift-rv`, which compares two monthly medians;
  this candidate computes no median and uses a parent range.
- `QM5_41109_xauxag-mmean-median-rv`, which compares one month's mean and
  median; this candidate uses two months and neither statistic.
- `QM5_41093_wti-wclose-breakout-mom`, which follows one final direct-WTI
  weekly close outside a parent range; this candidate fades persistent monthly
  residence of a two-leg metals ratio.
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG
  oscillator pullback, not a symmetric monthly intermetal package.

The exact XAU/XAG carrier, immediately completed and parent calendar months,
17-23 synchronized sessions each, fixed unit daily-close log ratio, parent
range, at least five newest-month closes beyond exactly one boundary, zero
opposite breach, final ratio still outside, contrarian paired side, durable
monthly attempt, equal-notional aggregate risk, and next-month exit are jointly
load-bearing. Verdict:
`NO_EXACT_XAUXAG_MONTHLY_OUTSIDE_RANGE_RESIDENCE_REVERSION_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact XAU D1 slot zero and XAG D1 slot one under governed magics;
- first-new-month-bar entry within 180 elapsed raw-session minutes;
- the exact immediately completed and parent calendar months, each containing
  17 through 23 unique, strictly ordered timestamp-identical sessions;
- `log(XAU close)-log(XAG close)` from completed synchronized closes only;
- the parent month's strict observed ratio minimum and maximum;
- SELL XAU / BUY XAG only for at least five newest-month ratios above the
  parent maximum, zero ratios below the parent minimum, and a final ratio still
  above the parent maximum;
- BUY XAU / SELL XAG only for the exact lower-side mirror;
- equality inside, fewer than five observations, any opposite breach, an
  inside final close, malformed history, or invalid arithmetic flat;
- one persistent broker-month attempt recorded before fallible gates;
- one aggregate `RISK_FIXED=1000` budget, one-to-one absolute entry notional,
  frozen `3.5*ATR(20,D1)` per-leg hard stops, no targets, and 1,500/500-point
  XAU/XAG spread ceilings;
- both news axes and Friday close OFF; and
- first-tick next-month exit plus a forty-calendar-day stale repair.

There is no authorized rolling center, fitted hedge coefficient, distance or
count-based sizing, lower outside-count floor, opposite-side tolerance,
inside-final-close tolerance, trend, calendar, season, volatility, volume,
event, inventory, external-data filter, dynamic management, retry, or signal-
strength sizing. Changing any load-bearing item requires a new card identity
and full Q00/Q01 cycle. Q02 failure cannot authorize an in-place signal rescue.

## Pipeline And Safety Boundary

Approval permits Q01 build, instrumentation, compile, static/reference tests,
canonical `RISK_FIXED` backtest setfile, and one paced non-live logical-basket
Q02 handoff. It does not prove the edge, waive Q02 activity/economic gates,
establish decorrelation, admit the EA to the portfolio, or authorize live use.

No manual tester run, live/demo/shadow/stress/optimization preset, AutoTrading
action, terminal control, `T_Live` change, deploy or T_Live-manifest edit,
portfolio-gate edit, correlation waiver, or after-result parameter selection
is authorized.
