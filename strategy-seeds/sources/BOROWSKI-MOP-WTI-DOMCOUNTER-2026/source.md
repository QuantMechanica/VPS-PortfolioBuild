---
source_id: BOROWSKI-MOP-WTI-DOMCOUNTER-2026
title: WTI exact day-of-month direction in the opposing completed 12-month regime
source_type: governed_composite_research_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-15_wti_dom_counterregime_source_approval.md
approval_commit: 22b4896d1
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-15
created: 2026-08-15
created_by: Research+Development
strategy_ids: [BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01]
parent_sources:
  - BOROWSKI-WTI-DOM26-2016
  - MOP-TSMOM-2012
---

# WTI Day-of-Month Counter-Regime Source Packet

## Source Identity And Complete-Read Evidence

This bounded packet combines two governed peer-reviewed lineages that were
read completely before card extraction:

1. Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
   Markets of Future Contracts with the Following Underlying Instruments:
   Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle,
   Live Cattle, Lean Hogs and Lumber," *Journal of Management and Financial
   Sciences*, issue 26, pages 27-44. The complete-paper review, WTI table,
   method, sample, and limitations are preserved at
   `strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md`. The positive
   day-8 direction and reported `p=0.0430` are preserved in the governed
   extraction `strategy-seeds/cards/approved/QM5_20036_wti-dom8-long_card.md`;
   the WTI day-26 mean is negative with reported `p=0.0424`.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete 23-page published-paper
   review and retrieval SHA-256 are preserved at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It supplies the sign of
   an instrument's completed own return as a slow state and identifies WTI in
   the commodity-futures universe.

Borowski tests many commodity/calendar cells without a reported family-wise
correction, and the WTI sample ends in 2016. Those facts make multiple testing
and decay load-bearing risks. Moskowitz, Ooi, and Pedersen do not test a
day-of-month interaction or a counter-trend calendar package.

## Bounded Mechanization

`BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01` is one predeclared interaction:

- carrier: exact `XTIUSD.DWX`, D1, magic slot 0;
- on an actual broker D1 bar dated exactly the 8th, BUY only when the
  completed 252-D1 log return is strictly negative;
- on an actual broker D1 bar dated exactly the 26th, SELL only when the
  completed 252-D1 log return is strictly positive;
- use `Close[1]` and `Close[253]`, so the current bar never enters the state;
- never shift an absent exact date to a neighboring session;
- enter only on the first observed tick within five minutes of the exact D1
  bar open and persist the exact-date attempt before every fallible gate;
- close on the first following D1 bar, with a one-calendar-day stale guard;
- freeze a `2.75 * ATR(20,D1)` broker hard stop, no take-profit, and a
  2,500-point entry spread ceiling; and
- backtest only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The calendar directions come from Borowski. The completed return sign comes
from the time-series-momentum lineage. Requiring the opposite state is a
transparent QM falsification hypothesis: a recurring physical-market calendar
flow may be most visible when it runs against the slow price regime. Neither
paper makes that claim.

## Claim And Translation Boundary

The source futures use exchange trading days; the EA uses exact Darwinex
broker-calendar dates on a continuous spot-style CFD. The rule cannot capture
the prior close-to-current open gap before its first executable tick. The
five-minute grace, exact broker calendar, continuous-CFD mapping, completed
252-D1 endpoints, hard stop, spread cap, fixed cash risk, attempt ledger, and
restart behavior are disclosed QM choices.

No paper return, alpha, coefficient, significance outside the cited WTI cells,
trade density, drawdown, cost, CFD equivalence, factor loading, decorrelation,
or portfolio result transfers.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,504 EA-registry rows and 600 root
cards and returned `CLEAN` for slug `wti-dom-ctrreg`, strategy ID
`BOROWSKI-MOP-WTI-DOMCOUNTER-2026_S01`, and the locked mechanic.

Manual semantic review separates the candidate from:

- `QM5_20036_wti-dom8-long`, the unconditional exact-day-8 long parent;
- `QM5_20027_wti-dom26-short`, the unconditional exact-day-26 short parent;
- `QM5_20215_wti-dom-trend`, whose day-1 long requires a positive slow state
  and whose day-26 short requires a negative slow state; this candidate uses
  day 8 and requires the opposing slow state on both arms;
- `QM5_12603_wti-tsmom12m`, a monthly symmetric WTI trend carrier without an
  exact numbered-day trigger or one-session hold; and
- `QM5_12567_cum-rsi2-commodity`, a two-day oscillator pullback.

The exact dates, source directions, opposing 252-D1 state, no-shift rule, and
one-session lifecycle are jointly load-bearing. Removing the state recreates
the calendar parents; changing opposition to agreement enters an existing
family boundary.

## Reputable-Source Criteria

- R1 `PASS_WITH_MULTIPLE_TESTING_RISK`: two named-author peer-reviewed journal
  lineages with complete repository reviews, exact WTI table locations, a DOI
  and retrieval hash for the JFE paper, and an explicit translation gap.
- R2 `PASS`: dates, completed endpoints, sign map, attempt state, entry clock,
  direction, stop, spread, risk, and exit are fixed before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` D1 history supplies every runtime input.
- R4 `PASS`: deterministic native calendar, OHLC, logarithm, ATR, position,
  deal-history, and framework state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Safety And Kill Boundary

Expected cadence is approximately six to ten completed positions per full
post-warm-up year. Q02 must retire below five/year, on zero trades, wrong or
shifted dates, a non-opposing state, current-bar leakage, repeated attempts,
or nonpositive governed economics. Q09 alone may establish realized book
correlation.

This packet authorizes one branch-only Strategy Card, deterministic allocation,
non-live V5 build, strict Q01 validation, one fixed-risk backtest setfile, and
one paced Q02 enqueue. It authorizes no manual backtest, live/demo/shadow
setfile, AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio admission,
portfolio-gate change, or correlation waiver.
