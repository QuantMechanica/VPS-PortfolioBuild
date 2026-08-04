---
source_id: BOROWSKI-MOP-WTI-DOMTREND-2026
title: WTI exact day-of-month entries conditioned on completed 12-month trend
publisher: Journal of Management and Financial Sciences / Journal of Financial Economics
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-04
created_by: Research+Development
last_updated: 2026-08-04
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-04
strategy_ids:
  - BOROWSKI-MOP-WTI-DOMTREND-2026_S01
parent_sources:
  - BOROWSKI-WTI-DOM26-2016
  - MOP-TSMOM-2012
---

# WTI Day-of-Month / Slow-Trend Agreement Source Packet

## Source identity and complete-read evidence

This governed packet joins two peer-reviewed source lineages already read in
full and preserved in the repository:

1. Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
   Markets of Future Contracts with the Following Underlying Instruments:
   Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle,
   Live Cattle, Lean Hogs and Lumber," Journal of Management and Financial
   Sciences, issue 26, pages 27-44. The complete paper, WTI numbered-day
   table, method, limitations, and day-26 result are documented in
   strategy-seeds/sources/BOROWSKI-WTI-DOM26-2016/source.md. The governed
   day-1 extraction is preserved in
   strategy-seeds/cards/approved/QM5_20028_wti-dom1-long_card.md.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," Journal of Financial Economics 104(2), 228-250. The
   complete 23-page paper, its own-instrument trailing-return sign rule, and
   the WTI commodity lineage are documented in
   strategy-seeds/sources/MOP-TSMOM-2012/source.md.

Borowski reports a positive WTI mean on numbered day 1 of 0.0338 percent,
but that result is not statistically significant. The same table reports a
negative WTI numbered-day-26 anomaly with p = 0.0424. The paper tests many
calendar cells, so multiple-testing and sample decay are first-order risks.
Moskowitz, Ooi, and Pedersen report broad time-series momentum across futures
using the sign of each instrument's own trailing return, including a
canonical 12-month horizon and commodities including crude oil.

Neither paper tests the exact conjunction below. No source performance,
significance, trade count, cost, CFD basis, drawdown, correlation, or
portfolio statistic transfers to the QM candidate.

## Bounded mechanization

BOROWSKI-MOP-WTI-DOMTREND-2026_S01 is one predeclared interaction:

- carrier: XTIUSD.DWX, D1, magic slot 0;
- on a broker D1 bar dated exactly the 1st, BUY only when the completed
  252-D1 log return is strictly positive;
- on a broker D1 bar dated exactly the 26th, SELL only when the completed
  252-D1 log return is strictly negative;
- use Close[1] and Close[253], so no current bar enters the state;
- do not shift an absent 1st or 26th to a neighboring session;
- enter only on the first observed tick within five minutes of the exact D1
  bar open and consume that exact-date attempt before fallible gates;
- close on the first following D1 bar, with a one-calendar-day stale guard;
- freeze a 2.75 times ATR(20,D1) broker hard stop, no take-profit, and a
  2,500-point entry spread ceiling; and
- backtest only with RISK_FIXED=1000, RISK_PERCENT=0, and
  PORTFOLIO_WEIGHT=1.

The trend gate makes the two calendar arms mutually exclusive when the slow
state is unchanged. Exact-date holidays and weekends imply an expected six
to ten completed packages per full post-warm-up year. Q02 must retire the
candidate below five per year on average.

## Non-duplicate boundary

The deterministic pre-allocation check scanned 4,272 EA-registry rows and
389 research cards. It found no exact duplicate and no fuzzy match above its
threshold for slug wti-dom-trend, strategy ID
BOROWSKI-MOP-WTI-DOMTREND-2026_S01, and the exact-date/trend mechanic.
Manual semantic review resolved the closest builds:

- QM5_20028_wti-dom1-long buys every tradable exact day 1 without a trend
  state and has no day-26 short arm.
- QM5_20027_wti-dom26-short sells every tradable exact day 26 without a
  trend state and has no day-1 long arm.
- QM5_12603_wti-tsmom12m is a year-round monthly trend package without an
  exact numbered-day carrier or one-session hold.
- QM5_20136_wti-caltrend uses a prior-year same-calendar-month return plus a
  63-D1 trend and holds for a month; it does not trade exact days 1 and 26.
- QM5_20172_wti-fri-bear is a Friday pattern with different information,
  clock, direction, and lifecycle.
- QM5_12567_cum-rsi2-commodity is a two-day oscillator pullback and uses a
  banned-for-this-mission indicator family that this card never reads.

The two exact dates, their opposite directional maps, the completed 252-D1
sign agreement, and one-session exit are jointly load-bearing. Removing the
trend gate recreates the existing calendar parents; removing the calendar
gate recreates a generic trend parent.

## Reputable-source criteria

- R1 PASS: two named-author peer-reviewed journal papers with durable,
  complete repository reviews; the weak day-1 evidence is disclosed.
- R2 PASS: fixed dates, return endpoints, sign map, attempt state, entry
  clock, stop, spread cap, and exit are deterministic.
- R3 PASS: registered XTIUSD.DWX D1 history supplies every runtime input.
- R4 PASS: native calendar, OHLC, logarithm, and ATR arithmetic only; no ML,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest
setfile, and one paced Q02 enqueue under the 2026-08-04 OWNER mission. It
does not authorize a manual backtest, live/demo/shadow setfile, AutoTrading,
T_Live, a deploy or T_Live manifest, portfolio admission, portfolio-gate
changes, or a correlation waiver.
