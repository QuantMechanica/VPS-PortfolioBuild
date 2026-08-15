---
source_id: MOP-WTI-MCLOSE-MOM-2026
title: WTI Final-Five To First-Five Month-Boundary Momentum
source_type: governed_peer_reviewed_translation_packet
status: cards_ready
approval_basis: OWNER commodity/energy portfolio mission 2026-08-15
created: 2026-08-15
created_by: Research+Development
primary_url: https://www.aqr.com/Insights/Research/Journal-Article/Time-Series-Momentum
parent_source_id: MOP-TSMOM-2012
cards_extracted: []
---

# WTI Final-Five To First-Five Month-Boundary Momentum

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
from the sign of an instrument's own past return, goes long when positive and
short when negative, and renews positions monthly. WTI crude is explicitly in
the paper's commodity-futures universe. The paper reports commodity-futures
results for monthly formations and holds, including `k=1, h=1`.

The source evidence is broad futures-family evidence. It does not establish a
WTI-only result, a five-session formation or hold, an exact broker-month
boundary, or the segment-to-segment rule below. Its implementations use rolled
futures excess returns, volatility scaling, and diversified portfolios.

## Bounded Price-Native Translation

On the first executable `XTIUSD.DWX` D1 tick of a new broker month, the
proposed card will:

1. reconstruct the six immediately preceding completed D1 bars and require
   all six to belong to the immediately prior broker month;
2. take the sign of `log(Close[1] / Close[6])`, the return across the final
   five completed close-to-close intervals of that month;
3. buy WTI after a positive return and sell WTI after a negative return;
4. consume exactly one attempt per broker month before all fallible gates and
   refuse a late entry after the opening grace;
5. use fixed-dollar risk, a frozen ATR hard stop, and no target; and
6. close after exactly five D1 bars of the entry month have completed.

This construction asks whether information accumulated during the closing
five-session segment of a WTI broker month persists through the opening five-
session segment of the next month. It is a transparent falsification
hypothesis, not a replication of the paper.

The six-bar endpoint construction, final-five horizon, exact first-new-month
clock, five-session hold, continuous-CFD mapping, ATR stop, fixed-dollar risk,
spread ceiling, and persistent lifecycle are QM choices. No source return,
alpha, coefficient, significance, density, cost, drawdown, WTI-only efficacy,
neutrality, decorrelation, or portfolio result transfers.

## Reputable-Source Criteria

- R1 `PASS`: exactly one source ID with peer-reviewed JFE lineage, DOI,
  complete-paper review evidence, and a durable retrieval hash. The source-to-
  implementation distance is disclosed rather than presented as fidelity.
- R2 `PASS`: exact completed-bar endpoints, prior-month membership, sign
  mapping, fixed monthly clock, persistent attempt, opening grace, risk, stop,
  spread, and exit are locked mechanically.
- R3 `PASS`: registered `XTIUSD.DWX` D1 price history and MT5-native execution
  state supply every runtime input.
- R4 `PASS`: closed-form price/calendar arithmetic only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramiding.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity across 4,503
registry rows and 599 root cards. It returned one fuzzy source-family sibling,
`wti-mopen-mom`, which manual review separates:

- `QM5_41013_wti-mopen-mom` forms during the first five bars of the current
  month, enters at bar six, and holds the remainder of that month.
- This proposal forms during the final five return intervals of the prior
  month, enters at bar one, and exits at bar six. Its trade is already flat
  before the existing EA can enter.

The nearby turn-of-month and one-week WTI momentum builds use 63-D1 or rolling
five-D1 magnitude/volatility states, variable decision clocks, and different
exits. The complete proposed identity is therefore a new segment-to-segment
information object, not a renamed parameter variant.

Verdict:
`CLEAN_WTI_FINAL_FIVE_TO_FIRST_FIVE_SEGMENT_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately twelve completed positions per full year.
Q02 must retire on zero trades, fewer than five completed packages per full
year, nondeterministic endpoint or bar-count reconstruction, late/repeated
entries, wrong hold length, or nonpositive governed economics. Q09 alone may
measure realized correlation with the certified portfolio.

Failure may not be rescued by moving the entry clock, changing the five-
interval formation, adding magnitude or volatility filters, changing
direction, widening risk, changing the stop or hold, or retrying a consumed
month.
