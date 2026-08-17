---
source_id: EIA-MOP-WTI-WEDTRENDPB-2026
title: Standard-Wednesday WTI counter-move and completed twelve-month trend re-entry
publisher: U.S. Energy Information Administration / Journal of Financial Economics
source_type: official_government_and_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-17_wti_wednesday_trend_pullback_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-17
created: 2026-08-17
created_by: Research+Development
strategy_ids: [EIA-MOP-WTI-WEDTRENDPB-2026_S01]
parent_sources:
  - EIA-WTI-WPSR-AFTERSHOCK-2026
  - MOP-TSMOM-2012
---

# WTI Standard-Wednesday Counter-Move / Slow-Trend Re-entry Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed source lineages that were read completely
before card extraction:

1. The U.S. Energy Information Administration publishes the Weekly Petroleum
   Status Report and its official release schedule. The governed packet at
   `strategy-seeds/sources/EIA-WTI-WPSR-AFTERSHOCK-2026/source.md` establishes
   the recurring ordinary-Wednesday petroleum information clock and the
   holiday-shift caveat. EIA supplies event identity only; the EA never reads
   an inventory value, consensus, surprise, schedule file, API, or external
   feed.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page paper, author-hosted
   retrieval SHA-256, exact own-return sign rule, and inclusion of NYMEX WTI
   are documented at `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

Moskowitz, Ooi, and Pedersen report broad continuation in each instrument's
own completed return at horizons through twelve months. Their commodity
portfolio includes WTI, but they do not establish a WTI-specific result for
this event clock. EIA does not test a trading strategy. Neither source tests
the exact counter-move conjunction below.

## Bounded Mechanization

`EIA-MOP-WTI-WEDTRENDPB-2026_S01` is one predeclared WTI interaction:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- decision: first executable broker-Thursday tick after exact completed
  Monday, Tuesday, and standard Wednesday sessions;
- event return: `ln(WednesdayClose / TuesdayClose)`;
- slow state: `ln(TuesdayClose / Close252SessionsBeforeTuesday)`, so the
  Wednesday event bar never enters the 252-session trend state;
- require both returns finite, nonzero, and strictly opposite in sign;
- enter Thursday in the slow-trend direction, thereby treating the completed
  Wednesday move as a one-session counter-move, and close at the first later
  D1 boundary, ordinarily Friday open;
- consume the Thursday attempt before history, signal, news, quote, spread,
  ATR, sizing, or order gates, with no retry or holiday substitution;
- freeze a `3.0 * ATR(20,D1)` hard stop, use no target, cap entry spread at
  1,500 points, and keep framework Friday close enabled as a fail-safe; and
- backtest only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The exact standard-Wednesday proxy, separate pre-event trend endpoint,
strict-opposition conjunction, slow-trend direction, Thursday grace,
fixed-dollar risk, hard stop, spread cap, attempt state, and next-D1 lifecycle
are disclosed QM choices. Magnitude never changes size.

## Claim And Translation Boundary

The official release may shift on holiday weeks. Version 1 deliberately
requires an uninterrupted Monday-Tuesday-Wednesday sequence and skips shifted
or missing sessions rather than inferring an external calendar. The source
futures use exchange returns; the EA uses a continuous spot-style Darwinex CFD
whose D1 label may be the same session date or one uniform `+1` energy offset.

No source performance, coefficient, significance, density, cost, drawdown,
WTI-only efficacy, futures/CFD equivalence, decorrelation, or portfolio result
transfers. Q02 tests the entire executable package; Q09 alone may establish
realized book correlation.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,533 registry rows and 625 root
card files. It found no exact identity and surfaced three lexical/source-family
fuzzy matches: `wti-dom-trend`, `wti-lr-trend`, and `xng-lr-trend`. None uses
the completed standard-Wednesday counter-move conjunction.

Manual family review separates the candidate from:

- `QM5_41045_wti-wed-trend-agree`, which requires the completed Wednesday
  return and pre-event trend to agree and follows that common sign. This
  candidate requires opposition and always trades the slow-trend sign;
- `QM5_41041_wti-wed-flow-fade`, which compares Wednesday close-to-open and
  open-to-close components and requires session dominance. This candidate
  ignores intraday components and compares the whole event-day return with a
  separate 252-session state;
- `QM5_20239_wti-pulltrend`, which uses a completed one-month counter-move,
  decides monthly, and holds to the next month. This candidate uses one exact
  Wednesday session, decides Thursday, and exits next D1;
- `QM5_20154_wti-wed-trend`, which enters before Wednesday, is long-only, and
  therefore owns the information event;
- `QM5_12590_eia-wti-aftershock`, which uses event-day range expansion rather
  than a separate pre-event trend sign; and
- `QM5_12567_cum-rsi2-commodity`, a long-only two-day oscillator pullback.

The standard-Wednesday identity, completed close-to-close counter-move,
pre-event 252-session return, strict sign opposition, slow-trend direction,
Thursday entry, and next-D1 exit are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXACT_AND_MANUAL_FAMILY_REVIEW_WITH_THREE_NONIDENTICAL_FUZZY_MATCHES`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage plus a
  named-author, peer-reviewed JFE paper read in full with DOI and retrieval
  hash; the exact conjunction and CFD translation are untested.
- R2 `PASS`: weekdays, normalized labels, completed endpoints, strict
  opposition, slow-trend direction, attempt state, timing, risk, stop, spread,
  and exit are fixed.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XTIUSD.DWX` D1 history
  supplies every runtime input; the energy-label normalization is explicit.
- R4 `PASS`: deterministic calendar, OHLC, logarithm, ATR risk-stop, position,
  deal-history, and terminal-global state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Safety And Kill Boundary

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than eight per
year, nonpositive governed economics, wrong weekday identity, shifted-session
substitution, current-bar leakage, inclusion of Wednesday in the slow state,
non-opposed signs, wrong side, late or repeated entry, wrong next-D1 exit,
nondeterminism, or invalid risk mode.

This packet authorizes one branch-only Strategy Card, deterministic EA and
magic allocation, non-live V5 build, strict Q01 validation, one fixed-risk
backtest setfile, and one paced target-only Q02 enqueue below the governed
tester ceiling. It authorizes no manual tester dispatch or control, live,
demo, shadow, stress, or optimization setfile, AutoTrading, `T_Live`, deploy or
T_Live manifest, portfolio admission, portfolio-gate change, decorrelation
claim, or correlation waiver.
