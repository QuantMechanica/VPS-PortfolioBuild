---
source_id: MOP-WTI-MOPEN-MOM-2026
title: WTI Fixed Month-Opening Segment Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_source_complete
approval_basis: OWNER commodity/energy portfolio mission 2026-08-15
created: 2026-08-15
created_by: Research+Development
primary_url: https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum
parent_source_id: MOP-TSMOM-2012
cards_extracted: []
---

# WTI Fixed Month-Opening Segment Momentum

## Approval And Review Scope

The OWNER mission delivered to Codex on 2026-08-15 authorizes one new,
structural, low-frequency commodity/energy Strategy Card, deterministic EA
allocation, branch-only build, strict Q01 validation, and one paced non-live
Q02 enqueue. The candidate must be genuinely distinct from the certified
XAU/SP500/NDX/XNG book and the existing repository inventory.

This packet does not authorize a live, demo, shadow, optimization, or stress
setfile; a manual backtest; AutoTrading; T_Live access; a deploy manifest; a
portfolio-gate change; portfolio admission; or a correlation waiver.

The bounded parent source
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read completely before
card extraction. That governed record preserves the complete 23-page
published-paper review and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

## Primary Source

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`.

The governed parent packet records that the paper forms a directional signal
from the sign of an instrument's own past return, goes long after a positive
return and short after a negative return, and renews positions monthly. WTI
crude is explicitly in the paper's commodity-futures universe.

The source evidence is broad futures-family evidence. It does not establish a
WTI-only result, a five-session horizon, or the fixed month-opening segment
defined below. Its primary implementations use completed monthly returns,
rolled futures excess returns, volatility scaling, and diversified portfolios.

## Bounded Price-Native Translation

On the first processed `XTIUSD.DWX` D1 bar after exactly five current-month D1
bars have completed, the proposed card will:

1. identify the immediately preceding broker-month-end close and the first
   five completed current-month D1 closes from a bounded, newest-first history
   scan;
2. take the sign of the exact log return from the prior-month-end close to the
   fifth current-month close;
3. buy WTI after a positive return and sell WTI after a negative return;
4. consume exactly one attempt per broker month before all fallible gates and
   refuse a late entry if more than five current-month bars already completed;
5. use fixed-dollar risk, a frozen ATR hard stop, and no target; and
6. close at the next broker-month boundary or a bounded stale guard.

This construction asks whether the first tradable week-like segment of a WTI
broker month contains information that persists through the residual month.
It is a transparent falsification hypothesis, not a replication of the paper.

The five-bar horizon, broker-month segmentation, prior-month anchor, fixed
decision clock, residual-month hold, continuous-CFD mapping, ATR stop, fixed-
dollar risk, spread ceiling, and persistent lifecycle are QM choices. No source
return, Sharpe ratio, coefficient, significance, density, cost, drawdown,
WTI-only efficacy, neutrality, decorrelation, or portfolio result transfers.

## Reputable-Source Criteria

- R1 `PASS`: exactly one source ID with peer-reviewed JFE lineage, DOI,
  complete-paper review evidence, and a durable retrieval hash. The source-to-
  implementation distance is disclosed rather than presented as fidelity.
- R2 `PASS`: exact completed-bar endpoints, sign mapping, fixed monthly clock,
  persistent attempt, no-late-entry rule, risk, stop, spread, and exit are
  locked mechanically.
- R3 `PASS`: registered `XTIUSD.DWX` D1 price history and MT5-native execution
  state supply every runtime input.
- R4 `PASS`: closed-form price/calendar arithmetic only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramiding.

## Non-Duplicate Boundary

The canonical pre-allocation checker returned `CLEAN` across 4,500 registry
rows and 596 root-card files for slug `wti-mopen-mom` and strategy ID
`MOP-WTI-MOPEN-MOM-2026_S01`.

Manual review fixes the important boundaries:

- `QM5_12810_wti-month-orb` measures a five-bar high/low range and waits for a
  later buffered breakout with SMA, range, and close-location filters. This
  proposal uses no range or indicator and always decides at the sixth bar.
- `QM5_13049_xti-1w-mom-vol` evaluates rolling five-day movements, requires a
  move threshold and low-volatility rank, and holds five days. This proposal
  evaluates once per broker month, uses sign only, and exits at month change.
- `QM5_20187_wti-tsmom1m` forms on the prior complete month and holds the next
  complete month. This proposal forms within the current month and holds only
  its remainder.
- `QM5_20008_wti-month-ch3` compares monthly closes with prior-month extrema;
  this proposal has no channel, breakout, or multi-month state.

Verdict:
`CLEAN_WTI_FIXED_MONTH_OPENING_SEGMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twelve completed WTI packages per full
post-warm-up year. Q02 must retire on zero trades, fewer than five completed
packages per full year, nondeterministic bar segmentation, or nonpositive
governed economics. Q09 alone may measure realized correlation with the
certified portfolio.

Failure may not be rescued by moving the decision clock, changing the five-bar
formation, replacing the prior-month anchor, adding magnitude or volatility
filters, changing direction, widening risk, changing the stop or hold, or
retrying a consumed month.
