---
source_id: BURAKOV-GORSKA-WTI-SEASDOW-2026
title: WTI physical-season and weekday-direction concordance
publisher: International Journal of Energy Economics and Policy / Problems of World Agriculture
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-05
created_by: Research+Development
last_updated: 2026-08-05
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-05
strategy_ids:
  - BURAKOV-GORSKA-WTI-SEASDOW-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - GORSKA-KRAWIEC-WTI-CAL-2015
---

# WTI Physical-Season / Weekday Concordance Source Packet

## Source Identity And Complete-Read Evidence

This packet joins two governed peer-reviewed WTI lineages whose complete
texts, method details, conflicting labels, source statistics, and limitations
are preserved locally:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The official open
   six-page paper was reviewed end to end. Its methods-section alternative
   two defines the WTI winter return from the last October close through the
   last May close and the summer return from the last May close through the
   last October close. The durable review is
   `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Gorska, Anna and Krawiec, Malgorzata (2015), "Calendar Effects in the
   Market of Crude Oil," *Problems of World Agriculture* 15(4), 62-70,
   DOI `10.22630/PRS.2015.15.4.54`. The university-hosted complete text was
   reviewed. Table 1 reports a negative WTI Monday mean and a positive WTI
   Friday mean; Table 2 rejects equality of those means at five percent. The
   durable review is
   `strategy-seeds/sources/GORSKA-KRAWIEC-WTI-CAL-2015/source.md`.

Burakov et al. supply a positive November-May WTI state and a negative
June-October WTI state. Gorska and Krawiec supply negative Monday and positive
Friday WTI weekday states. The bounded candidate trades only the two
directional agreements: Friday long during November-May, and Monday short
during June-October.

Neither paper tests this conjunction, a Darwinex continuous WTI CFD, a
broker-open market entry, a fixed-risk ATR stop, a restart ledger, or the QM
portfolio. The source daily-return measurement includes the close-to-open
component that a first-tick D1 entry cannot recover. No source return,
significance, profitability, drawdown, cost, or correlation statistic is
transferred to the candidate.

## Bounded Mechanization

`BURAKOV-GORSKA-WTI-SEASDOW-2026_S01` is one predeclared calendar-concordance
rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- winter state: November through May, positive WTI direction;
- summer state: June through October, negative WTI direction;
- winter entry: one BUY on a genuine broker Friday whose prior completed D1
  bar is Thursday, observed within five minutes of the Friday D1 open;
- summer entry: one SELL on a genuine broker Monday whose prior completed D1
  bar is Friday, observed within five minutes of the Monday D1 open;
- all other weekday/season combinations: flat;
- lifecycle: Friday BUY flattened by the framework at broker hour 21;
  otherwise close on the first following D1 boundary, with a three-calendar-
  day stale guard;
- fixed `3.0 * ATR(20,D1)` hard stop, 1,500-point spread ceiling, and one
  restart-safe consumed attempt per eligible broker day; and
- backtest-only `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The two seasonal windows cover the full year, but only one source-aligned
weekday is eligible inside each window. The predeclared expectation is 42-50
completed one-session packages/year after broker holidays and genuine-
weekday sequence checks. Q02 must retire the candidate below five completed
packages/year. Runtime reads native OHLC, ATR, broker calendar, executable
quotes, positions, deal history, and framework state only.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,283 EA registry rows and
399 canonical cards. It found no exact identity and no fuzzy match above its
threshold. Manual mechanic review fixes the closest boundaries:

- `QM5_20029_wti-monfri-daily` sells every genuine Monday and buys every
  genuine Friday without a WTI physical-season state. This candidate forbids
  winter Mondays and summer Fridays and takes only calendar agreement.
- `QM5_12596_wti-mon-fade` and `QM5_12597_wti-fri-prem` are unconditional
  one-sided weekday parents with no season gate.
- `QM5_20015_wti-halloween-winter`, `QM5_20046_wti-halloween-ls`, and
  `QM5_20093_wti-summer-short` hold or renew full-month seasonal exposure;
  they do not isolate one weekday session.
- `QM5_20145_wti-fri-trend`, `QM5_20149_wti-montrend`,
  `QM5_20172_wti-fri-bear`, and `QM5_20173_wti-mon-bullfade` condition a
  weekday on a completed 252-D1 return sign, not a fixed physical-season
  state.
- `QM5_20222_wti-seas-sign` renews monthly from twelve binary monthly return
  signs and does not trade weekday effects.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback above a
  long-horizon price filter.

The November-May/June-October map, opposite Friday/Monday event clocks, fixed
directions, genuine prior-weekday sequences, and one-session lifecycle are
jointly load-bearing. Removing the season map recreates a built weekday
carrier; removing the weekday map recreates a built seasonal carrier.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed papers with official DOI or
  journal access and durable complete-read repository records.
- R2: PASS. Fixed month windows, weekdays, directions, prior-day sequences,
  entry grace, consumed attempt, stop, spread cap, next-bar/Friday exits, and
  stale guard.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and native broker calendar
  supply every runtime input.
- R4: PASS. Deterministic native calendar and price arithmetic only; no
  trained model, banned indicator, external runtime feed, grid, martingale,
  scale-in, or pyramiding.

## Safety And Claim Boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue under the 2026-08-05 OWNER mission. It does not
authorize a manual backtest; live, demo, or shadow execution; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
changes; or correlation waivers.
