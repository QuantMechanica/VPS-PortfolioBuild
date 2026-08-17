---
source_id: EIA-MOP-WTI-WEDTRENDAGREE-2026
title: Standard-Wednesday WTI event return and completed twelve-month trend agreement
publisher: U.S. Energy Information Administration / Journal of Financial Economics
source_type: official_government_and_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-17_wti_wednesday_trend_agreement_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-17
created: 2026-08-17
created_by: Research+Development
strategy_ids: [EIA-MOP-WTI-WEDTRENDAGREE-2026_S01]
parent_sources:
  - EIA-WTI-WPSR-AFTERSHOCK-2026
  - MOP-TSMOM-2012
---

# WTI Standard-Wednesday Event / Slow-Trend Agreement Source Packet

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
the exact conjunction below.

## Bounded Mechanization

`EIA-MOP-WTI-WEDTRENDAGREE-2026_S01` is one predeclared WTI interaction:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- decision: first executable broker-Thursday tick after exact completed
  Monday, Tuesday, and standard Wednesday sessions;
- event return: `ln(WednesdayClose / TuesdayClose)`;
- slow state: `ln(TuesdayClose / Close252SessionsBeforeTuesday)`, so the
  Wednesday event bar never enters the 252-session trend state;
- require both returns finite, nonzero, and strictly equal in sign;
- follow the common sign on Thursday and close at the first later D1 boundary,
  ordinarily Friday open;
- consume the Thursday attempt before history, signal, news, quote, spread,
  ATR, sizing, or order gates, with no retry or holiday substitution;
- freeze a `3.0 * ATR(20,D1)` hard stop, use no target, cap entry spread at
  1,500 points, and keep framework Friday close enabled as a fail-safe; and
- backtest only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The exact standard-Wednesday proxy, separate pre-event trend endpoint,
strict-sign conjunction, Thursday grace, fixed-dollar risk, hard stop, spread
cap, attempt state, and next-D1 lifecycle are disclosed QM choices. Magnitude
never changes size.

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

The canonical pre-allocation checker scanned 4,532 registry rows and 625 root
card files. It returned `CLEAN` with no exact or fuzzy identity for slug
`wti-wed-trend-agree`, strategy ID
`EIA-MOP-WTI-WEDTRENDAGREE-2026_S01`, and the locked mechanic.

Manual family review separates the candidate from:

- `QM5_41042_wti-wed-flow-agree`, which compares Wednesday close-to-open and
  open-to-close components and requires their same-sign agreement; it has no
  slow trend state;
- `QM5_41041_wti-wed-flow-fade`, which requires opposed Wednesday components,
  session dominance, and a contrarian next-day side;
- `QM5_20154_wti-wed-trend`, which enters before the Wednesday session from a
  slow trend state and therefore owns the information event;
- `QM5_12590_eia-wti-aftershock`, which uses event-day range expansion rather
  than a separate pre-event twelve-month sign;
- `QM5_20133` and `QM5_20134`, which trade M30 release impulse/pullback or
  failure patterns inside the event session; and
- `QM5_12567_cum-rsi2-commodity`, a long-only two-day oscillator pullback with
  no event or slow-trend conjunction.

The standard-Wednesday identity, completed close-to-close event return,
pre-event 252-session return, strict sign agreement, Thursday entry, and
next-D1 exit are jointly load-bearing. Removing the event return recreates a
generic trend carrier; removing the slow state enters existing WPSR reaction
families.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage plus a
  named-author, peer-reviewed JFE paper read in full with DOI and retrieval
  hash; the exact conjunction and CFD translation are untested.
- R2 `PASS`: weekdays, normalized labels, completed endpoints, sign rule,
  attempt state, timing, direction, risk, stop, spread, and exit are fixed.
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
sign disagreement, wrong side, late or repeated entry, wrong next-D1 exit,
nondeterminism, or invalid risk mode.

This packet authorizes one branch-only Strategy Card, deterministic EA and
magic allocation, non-live V5 build, strict Q01 validation, one fixed-risk
backtest setfile, and one paced target-only Q02 enqueue below the governed
tester ceiling. It authorizes no manual tester dispatch or control, live,
demo, shadow, stress, or optimization setfile, AutoTrading, `T_Live`, deploy or
T_Live manifest, portfolio admission, portfolio-gate change, decorrelation
claim, or correlation waiver.
