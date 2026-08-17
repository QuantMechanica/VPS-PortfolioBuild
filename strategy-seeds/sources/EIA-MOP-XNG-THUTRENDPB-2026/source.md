---
source_id: EIA-MOP-XNG-THUTRENDPB-2026
title: Standard-Thursday XNG counter-move and completed twelve-month trend re-entry
publisher: U.S. Energy Information Administration / Journal of Financial Economics
source_type: official_government_and_peer_reviewed_composite_lineage
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-17_xng_thursday_trend_pullback_source_approval.md
approval_commit: 25f6f54fb5991ca77b6313b7133d3cdab0b3437c
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-17
created: 2026-08-17
created_by: Research+Development
strategy_ids: [EIA-MOP-XNG-THUTRENDPB-2026_S01]
parent_sources:
  - EIA-XNG-STORAGE-AFTERSHOCK-2026
  - MOP-TSMOM-2012
---

# XNG Standard-Thursday Counter-Move / Slow-Trend Re-entry Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet joins two governed source lineages that were read completely
before card extraction:

1. The U.S. Energy Information Administration publishes the Weekly Natural Gas
   Storage Report and its official release schedule. The governed packet at
   `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`
   establishes the recurring ordinary-Thursday natural-gas information clock,
   the regular 10:30 a.m. Eastern release, and the holiday-shift caveat. EIA
   supplies event identity only; the EA never reads a storage value, consensus,
   surprise, schedule file, API, or external feed.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page paper, author-hosted
   retrieval SHA-256, exact own-return sign family, and inclusion of natural
   gas are documented at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.

Moskowitz, Ooi, and Pedersen report broad continuation in each instrument's
own completed return at horizons through twelve months. Their commodity
portfolio includes natural gas, but they do not establish an XNG-specific
result for this event clock. EIA does not test a trading strategy. Neither
source tests the exact counter-move conjunction below.

## Bounded Mechanization

`EIA-MOP-XNG-THUTRENDPB-2026_S01` is one predeclared natural-gas interaction:

- carrier: exact `XNGUSD.DWX`, D1, magic slot 0;
- decision: first executable broker-Friday tick after exact completed Tuesday,
  Wednesday, and standard Thursday sessions;
- event return: `ln(ThursdayClose / WednesdayClose)`;
- slow state: `ln(WednesdayClose / Close252SessionsBeforeWednesday)`, so the
  Thursday event bar never enters the 252-session trend state;
- require both returns finite, nonzero, and strictly opposite in sign;
- enter Friday in the slow-trend direction, treating the completed Thursday
  move as a one-session counter-move, and close at the first later D1 boundary,
  ordinarily Monday open;
- consume the Friday attempt before history, signal, news, quote, spread, ATR,
  sizing, or order gates, with no retry or holiday substitution;
- freeze a `3.5 * ATR(20,D1)` hard stop, use no target, cap entry spread at
  3,000 points, and disable framework Friday close because the locked one-D1
  lifecycle spans the weekend; and
- backtest only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The exact standard-Thursday proxy, separate pre-event trend endpoint,
strict-opposition conjunction, slow-trend direction, Friday grace,
fixed-dollar risk, hard stop, spread cap, attempt state, and next-D1 lifecycle
are disclosed QM choices. Magnitude never changes size.

## Claim And Translation Boundary

The official release may shift on holiday weeks. Version 1 deliberately
requires an uninterrupted Tuesday-Wednesday-Thursday sequence and skips
shifted or missing sessions rather than inferring an external calendar. The
source futures use exchange returns; the EA uses a continuous spot-style
Darwinex CFD whose D1 label may be the same session date or one uniform `+1`
energy offset.

No source performance, coefficient, significance, density, cost, drawdown,
XNG-only efficacy, futures/CFD equivalence, decorrelation, or portfolio result
transfers. Q02 tests the entire executable package; Q09 alone may establish
realized book correlation.

## Non-Duplicate Boundary

The canonical pre-allocation checker scanned 4,534 registry rows and 625 root
card files. It found no exact identity and surfaced three lexical/source-family
fuzzy matches: `wti-dom-trend`, `wti-lr-trend`, and `xng-lr-trend`. None uses
the completed standard-Thursday counter-move conjunction.

Manual family review separates the candidate from:

- `QM5_41046_wti-wed-trend-pb`, which is the same falsification family on WTI
  around the petroleum Wednesday clock, enters Thursday, and normally exits
  Friday. This candidate is a distinct XNG carrier around the natural-gas
  Thursday clock and owns the Friday-to-Monday interval;
- `QM5_20163_xng-thu-trend`, which enters before Thursday using only a
  negative 252-D1 state. This candidate waits for completed Thursday and
  requires a separate event counter-move before entering Friday;
- `QM5_41043_xng-thu-flow-agree`, which compares Thursday close-to-open and
  open-to-close components and follows their agreement. This candidate ignores
  intraday components and compares the whole completed Thursday return with a
  non-overlapping 252-session state;
- `QM5_41044_xng-thu-flow-fade`, which requires opposed Thursday internal
  components and fades the dominant component. This candidate requires
  opposition across event and slow horizons and trades the slow-trend sign;
- `QM5_20239_wti-pulltrend`, which uses a one-month WTI counter-move, a monthly
  decision, and a monthly hold;
- `QM5_20124`, `QM5_20128`, and `QM5_20132`, which trade M30 release-window
  impulse, reclaim, or breakout objects; and
- `QM5_12567_cum-rsi2-commodity`, a long-only two-day oscillator pullback.

The XNG carrier, standard-Thursday identity, completed close-to-close
counter-move, pre-event 252-session return, strict sign opposition,
slow-trend direction, Friday entry, and next-D1 exit are jointly load-bearing.
Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_COUNTER_MOVE_PRE_EVENT_TREND_REENTRY_AFTER_EXACT_AND_MANUAL_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: official EIA event lineage plus a
  named-author, peer-reviewed JFE paper read in full with DOI and retrieval
  hash; the exact conjunction and CFD translation are untested.
- R2 `PASS`: weekdays, normalized labels, completed endpoints, strict
  opposition, slow-trend direction, attempt state, timing, risk, stop, spread,
  and exit are fixed.
- R3 `PASS_WITH_SESSION_LABEL_RISK`: registered native `XNGUSD.DWX` D1 history
  supplies every runtime input; energy-label normalization is explicit.
- R4 `PASS`: deterministic calendar, OHLC, logarithm, ATR risk-stop, position,
  deal-history, and terminal-global state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Safety And Kill Boundary

Expected cadence is approximately eighteen to thirty-two completed positions
per full post-warm-up year. Q02 must retire on zero trades, fewer than eight per
year, nonpositive governed economics, wrong weekday identity,
shifted-session substitution, current-bar leakage, inclusion of Thursday in
the slow state, non-opposed signs, wrong side, late or repeated entry, wrong
next-D1 exit, nondeterminism, or invalid risk mode.

This packet authorizes one branch-only Strategy Card, deterministic EA and
magic allocation, non-live V5 build, strict Q01 validation, one fixed-risk
backtest setfile, and one paced target-only Q02 enqueue below the governed
tester ceiling. It authorizes no manual tester dispatch or control, live,
demo, shadow, stress, or optimization setfile, AutoTrading, `T_Live`, deploy or
T_Live manifest, portfolio admission, portfolio-gate change, decorrelation
claim, or correlation waiver.
