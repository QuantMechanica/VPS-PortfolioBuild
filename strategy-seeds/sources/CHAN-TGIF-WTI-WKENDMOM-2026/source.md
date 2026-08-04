---
source_id: CHAN-TGIF-WTI-WKENDMOM-2026
title: WTI weekend opening-gap momentum composite
source_type: governed_composite
status: approved
created: 2026-08-05
created_by: Research+Development
approved_by: OWNER commodity/energy sleeve mission
approved_at: 2026-08-05
primary_source_ids: [SRC05, TGIF-WTI-WEEKEND-2017]
strategy_ids: [CHAN-TGIF-WTI-WKENDMOM-2026_S01]
cards_extracted: [wti-wkend-mom]
---

# WTI Weekend Opening-Gap Momentum Source Packet

## Source identity and approval

This governed packet joins two already approved, completely reviewed source
lineages for one bounded WTI falsification candidate:

1. Ernest P. Chan (2013), *Algorithmic Trading: Winning Strategies and Their
   Rationale*, Wiley Trading, Chapter 7, Example 7.1, printed pages 156-157.
   The OWNER-supplied Tier-A book was extracted end to end into the 9,443-line
   text archive `strategy-seeds/sources/SRC05/raw/full_text.txt`. The complete
   source survey and provenance are in `strategy-seeds/sources/SRC05/source.md`.
2. Seth A. Hoelscher, Cedric Mbanga, and Walt A. Nelson (2017), "TGIF? The
   Weekend Effect in Energy Commodities," *Journal of Finance Issues* 16(1),
   47-68, DOI `10.58886/jfi.v16i1.2264`. The complete official 22-page paper
   and all tables were reviewed in the approved packet
   `strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md`.

Chan is the primary mechanical source. Hoelscher, Mbanga, and Nelson provide
target-market evidence that WTI has a distinct weekend/Monday return clock;
they do not supply the momentum direction or threshold.

## Complete bounded extraction

Chan's bounded opening-gap section is preserved at raw-text lines 7012-7066.
It states that a momentum strategy can work on futures and currencies by
buying gap-ups and shorting gap-downs. Example 7.1 defines:

```text
entryZscore = 0.1
stdret90 = lag_one_session(sample_std(close_to_close_returns, 90))
long  when open > prior_high * (1 + entryZscore * stdret90)
short when open < prior_low  * (1 - entryZscore * stdret90)
exit at the same session close
```

The source case is FSTX, with a GBPUSD generalization. Chan attributes the
possible continuation to stop orders triggering together after a closed
market and cascading in the gap direction, or to overnight news. He reports
source-sample performance for FSTX and GBPUSD, but no WTI result.

The TGIF paper estimates close-to-close WTI and natural-gas weekday returns
from EIA spot series. Its WTI Monday coefficient is negative across its full-
sample estimators, with weaker subperiod stability. It does not distinguish
Friday-close-to-Monday-open from Monday-open-to-close return, does not test
Chan's prior-extreme threshold, and does not prescribe an executable CFD rule.

## Mechanization boundary

The new carrier is exact `XTIUSD.DWX` D1 and is deliberately weekend-only:

- evaluate on a broker-calendar Monday whose immediately prior completed D1
  bar is Friday;
- use the Monday D1 open, Friday high/low, and a sample standard deviation of
  exactly 90 completed arithmetic D1 close-to-close returns, all known at the
  Monday open;
- buy only above `FridayHigh * (1 + 0.1 * stdret90)` and sell only below
  `FridayLow * (1 - 0.1 * stdret90)`;
- attach within five minutes of the Monday D1 open and consume one attempt
  before fallible gates;
- close at the first following D1 boundary, the Darwinex D1 approximation of
  Chan's same-session close;
- add a frozen `3.0 * ATR(20,D1)` broker hard stop, one fixed-risk budget, a
  2,500-point spread ceiling, and a two-calendar-day stale repair.

The Monday-only restriction is a pre-result target-market translation. The
hard stop, spread cap, attachment grace, retry ledger, and stale repair are QM
safety choices rather than source claims. Friday close remains enabled.

## Reputable-source criteria

- R1 PASS: one Tier-A named-author Wiley book with exact executable code and a
  complete local extraction, plus one named-author peer-reviewed WTI weekend
  study with official full text and DOI.
- R2 PASS: weekday sequence, lagged 90-return sample, `0.1` multiplier,
  prior-high/low thresholds, direction, attachment window, consumed attempt,
  hard stop, next-D1 exit, and stale repair are fixed.
- R3 PASS: `XTIUSD.DWX` D1 is a registered native tester route; no external
  runtime data is required.
- R4 PASS: broker calendar, OHLC, arithmetic returns, sample variance, ATR,
  quotes, and position state only; no ML, banned indicator, grid, martingale,
  scale-in, pyramid, or external feed.

## Non-duplicate boundary

The deterministic pre-allocation check scanned 4,274 EA registry rows and 390
cards and returned `CLEAN` for slug `wti-wkend-mom`, strategy ID
`CHAN-TGIF-WTI-WKENDMOM-2026_S01`, and its full mechanic.

Manual semantic review records the expected neighbors:

- `QM5_9151_chan-at-fstx-gap-mom` implements Chan's source family on GDAXI,
  UK100, and GBPUSD H1 session wrappers. It does not trade WTI or require a
  genuine Friday-to-Monday D1 boundary.
- registry identity `1029,chan-at-fstx-gap-mom-src05` has no magic row or EA
  directory and is not a WTI build.
- `QM5_12750_wti-weekend-gap-fade` sells positive Monday gaps and targets the
  Friday close; `QM5_12779_wti-weekend-gap-bounce` buys negative gaps and
  targets the Friday close. This card follows, rather than fades, a gap and
  references Friday high/low plus lagged volatility instead of Friday close
  plus a fixed percentage.
- `QM5_12596_wti-mon-fade` shorts Mondays without a gap state.
- `QM5_20117_wti-fri-lagrev` trades a Thursday-return-conditioned Friday
  reversal, not a weekend opening gap.
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback across
  commodity carriers and contains no weekend/prior-extreme rule.

The WTI carrier, genuine weekend clock, prior-extreme volatility threshold,
same-direction entry, and next-D1 lifecycle are jointly load-bearing. Removing
the WTI/weekend scope recreates the source-family parent; flipping direction
recreates existing WTI gap-fill EAs.

## Guardrails and claim boundary

- No source performance, profit factor, drawdown, trade count, CFD basis, or
  portfolio correlation transfers to this carrier.
- The FSTX/GBPUSD-to-WTI substitution and D1-boundary exit are explicit
  falsification risks.
- Runtime reads no futures chain, inventory, WPSR, OPEC, COT, options, news
  text, CSV, API, analyst forecast, or trained output.
- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- No live/demo/shadow setfile, T_Live access, AutoTrading action, deploy
  manifest, portfolio gate change, correlation waiver, or portfolio admission
  is authorized.
