---
source_id: BURAKOV-BIANCHI-WTI-SEAS52W-2026
title: WTI physical-season and 52-week anchor concordance
publisher: International Journal of Energy Economics and Policy / Journal of Banking and Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-06
strategy_ids:
  - BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - BIANCHI-COMM-52W-2016
---

# WTI Physical-Season / 52-Week Anchor Concordance Source Packet

## Source Identity And Complete-Read Evidence

This packet combines two governed, peer-reviewed lineages whose complete
source reviews, limitations, and extraction boundaries are preserved in the
repository and were read completely for this extraction:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The official open
   six-page paper was reviewed end to end. Its methods-section alternative
   two defines WTI winter from the last October close through the last May
   close and summer from the last May close through the last October close.
   The durable complete-read record is
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Bianchi, Robert J.; Drew, Michael E.; and Fan, Jian Hua (2016),
   "Commodities momentum: A behavioural perspective," *Journal of Banking &
   Finance*, DOI `10.1016/j.jbankfin.2016.06.010`. The governed source record
   is `strategy-seeds/sources/BIANCHI-COMM-52W-2016/source.md`; it preserves
   the peer-reviewed DOI, public preprint pointer, commodity 52-week-anchor
   interpretation, and deterministic WTI implementation boundary.

Burakov et al. supply a positive November-May WTI physical-season direction
and a negative June-October direction. Bianchi, Drew, and Fan supply the
commodity 52-week high/low anchor lineage. The already-approved WTI parent
mechanization expresses that anchor as a completed D1 close near its trailing
252-D1 closing extreme, confirmed by a same-direction 63-D1 return.

Neither source tests the agreement filter below. Neither tests a Darwinex
continuous CFD, exact broker-month execution, fixed cash risk, an ATR stop,
transaction costs, financing, or the QM portfolio. No source return,
significance, Sharpe, drawdown, trade count, correlation, or diversification
statistic transfers to this candidate.

## Bounded Mechanization

`BURAKOV-BIANCHI-WTI-SEAS52W-2026_S01` is one predeclared monthly
concordance rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision: the first processed D1 bar of every broker-calendar month;
- seasonal direction: BUY in November-May and SELL in June-October;
- anchor window: the newest completed D1 close and the prior 252 completed D1
  closes, with the newest close included in the trailing closing high/low;
- confirmation: the completed 63-D1 log return ending at that newest close;
- anchor-long state: `close / high_252 >= 0.94` and 63-D1 return at least
  `+2.0%`;
- anchor-short state: `close / low_252 <= 1.08` and 63-D1 return at most
  `-2.0%`;
- entry: BUY only when the November-May direction and anchor-long state
  agree; SELL only when the June-October direction and anchor-short state
  agree; every other state consumes the month and remains flat;
- lifecycle: close the prior package before the next monthly decision, with
  a forty-calendar-day stale guard;
- risk: one frozen `3.5 * ATR(20,D1)` server-side hard stop, no target, a
  1,500-point spread ceiling, and one restart-safe consumed attempt per
  month; and
- backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close OFF.

The maximum cadence is twelve decisions per full post-warm-up year. The
predeclared expectation is five to seven concordant packages per year. Q02
must retire the candidate if it averages below five completed packages per
full post-warm-up year. No threshold, horizon, season, direction, hold,
carrier, or retry sweep is authorized.

Runtime reads native D1 rates, the framework ATR reader, broker calendar,
executable quotes, positions, deal history, and framework state only. It does
not read a futures chain, inventory, volume, open interest, external files,
APIs, analyst inputs, or forecasts.

## Non-Duplicate Boundary

Before allocation, `research_dedup_check.py` scanned 4,298 EA-registry rows
and 415 canonical cards. It found no exact identity and no fuzzy match above
its threshold. Manual mechanic review fixes the nearest-neighbor boundary:

- `QM5_12780_wti-52w-anchor` trades the price anchor in every month. It has
  no physical-season direction and does not force disagreement flat.
- `QM5_20046_wti-halloween-ls` maps the calendar directly to position
  direction. It has no price location or return-confirmation state.
- `QM5_20135_wti-winter-trend` is active only November-May and follows the
  sign of a raw 252-D1 return, including winter shorts. This candidate never
  shorts winter, also carries a June-October short state, and requires both
  52-week closing-extreme proximity and a 63-D1 confirmation threshold.
- `QM5_20141_wti-sumtrend` is a weekly July-November short-only package keyed
  to a negative 252-D1 return and Friday exit. This candidate is monthly,
  uses June-October, and requires low-anchor proximity plus a separate
  63-D1 threshold.
- `QM5_20231_wti-seas-mom12` uses the sign of one cumulative twelve-calendar-
  month endpoint return. It does not inspect annual closing-extreme proximity
  or a quarterly confirmation return.
- `QM5_20222_wti-seas-sign` counts twelve individual monthly return signs.
  It has neither an annual price anchor nor the 63-D1 magnitude threshold.
- `QM5_12567_cum-rsi2-commodity` is an XNG two-day oscillator pullback above
  a long filter, not a monthly WTI calendar/anchor interaction.

The two-season direction map, trailing closing-extreme location, separate
63-D1 return threshold, agreement-only entry, disagreement-flat state, and
monthly lifecycle are jointly load-bearing. Substituting a raw 252-D1 return,
removing the season, or relaxing the agreement rule creates a different card.

## Reputable-Source Criteria

- R1: PASS. Two named-author, peer-reviewed papers with DOI or official
  journal access and durable complete-read repository records.
- R2: PASS. Fixed season map, 252-D1 closing-extreme calculation, 63-D1
  confirmation, thresholds, agreement rule, renewal, stop, stale guard,
  spread cap, and retry state are deterministic and frozen before testing.
- R3: PASS. Registered `XTIUSD.DWX` D1 history supplies every runtime input;
  no external data dependency exists.
- R4: PASS. Native price, logarithm, extreme, ATR, and calendar arithmetic
  only; no trained output, banned indicator, grid, martingale, scale-in, or
  pyramiding.

## Safety And Claim Boundary

The 2026-08-06 OWNER commodity/energy sleeve mission authorizes this bounded
source lineage for one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest
setfile, and one paced Q02 enqueue. It does not authorize a manual backtest;
live, demo, or shadow execution; AutoTrading; `T_Live`; deploy or T_Live
manifests; portfolio admission; portfolio-gate changes; correlation waivers;
or any performance or decorrelation claim.
