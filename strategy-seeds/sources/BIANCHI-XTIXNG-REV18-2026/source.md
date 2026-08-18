---
source_id: BIANCHI-XTIXNG-REV18-2026
title: XTI/XNG pure 18-month cross-sectional reversal basket
publisher: Journal of Banking and Finance
source_type: peer_reviewed_paper_bounded_carrier_translation
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-18_xtixng_18m_reversal_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-18
created: 2026-08-18
created_by: Research+Development
parent_source_id: BIANCHI-MOMREV-2015
strategy_ids:
  - BIANCHI-MOMREV-2015_XTI_XNG_S04
cards_extracted: []
---

# XTI/XNG Pure 18-Month Reversal Source Packet

## Source Identity And Complete-Read Boundary

The canonical lineage is Bianchi, Robert J.; Drew, Michael E.; and Fan, John
Hua (2015), "Combining Momentum with Reversal in Commodity Futures,"
*Journal of Banking & Finance* 59, 423-444, DOI
`10.1016/j.jbankfin.2015.07.006`.

The governed packet `strategy-seeds/sources/BIANCHI-MOMREV-2015/source.md` was
read completely before this bounded extraction. It records the complete
59-page accepted-manuscript review, the broad GSCI and DJ-UBS commodity
universes, the post-formation reversal over months 12 through 30, the
preferred overlapping 18-month reversal rank, the source's double-sort
construction, robustness evidence, and limitations. WTI crude oil and
natural gas are explicit source constituents.

The source does not prescribe the pure two-energy-leg rule below. The carrier
and isolation of the 18-month information object are transparent QM
translations. No paper statistic is attributed to this implementation.

## Bounded Mechanization

`BIANCHI-MOMREV-2015_XTI_XNG_S04` is one predeclared logical-basket
falsification package:

- exact D1 host `XTIUSD.DWX` on slot 0 and companion `XNGUSD.DWX` on slot 1;
- decide only on the first tradable XTI D1 bar of a genuine broker month;
- reconstruct synchronized, completed, strictly pre-decision month-end closes
  at the latest completed-month boundary and exactly 18 completed months
  earlier;
- require every endpoint to be positive, ordered, and no more than ten
  calendar days before its boundary;
- compute one completed 18-month log return per leg;
- buy the lower-return leg and short the higher-return leg when the return
  difference exceeds `1e-12`, and consume the month flat on a tie;
- close and renew at the next broker-month boundary;
- persist the `yyyymm` attempt before every fallible entry gate and never
  retry the month;
- split `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` equally
  across frozen `3.5 * ATR(20,D1)` leg stops, with no targets;
- cap XTI spread at 1,500 points and XNG spread at 3,000 points, compensate a
  one-leg fill immediately, and repair any orphan; and
- disable Friday flatten for the monthly hold, with a 35-calendar-day stale
  repair.

Runtime uses native MT5 D1 OHLC/timestamps, broker calendar, quotes, symbol
properties, ATR risk plumbing, positions, deal history, and terminal-global
attempt state. It uses no futures curve, roll series, inventory, weather,
volume, open interest, COT, external API, CSV, trained output, optimizer
artifact, ratio z-score, or manual signal.

## Exact Reversal Contract

For synchronized completed endpoints `end` and `start18`:

```text
r_xti = ln(XTI_end / XTI_start18)
r_xng = ln(XNG_end / XNG_start18)

r_xti < r_xng - 1e-12 => BUY XTI, SELL XNG
r_xti > r_xng + 1e-12 => SELL XTI, BUY XNG
otherwise              => consume month flat
```

All four prices precede the decision-month opening boundary. Current-month
open, high, low, close, and volume are forbidden from the signal. The EA must
not compute, consult, or emulate the sibling 12-month momentum rank. Signal
magnitude never changes size.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_RISK`: named authors, peer-reviewed JBF lineage,
  DOI, open accepted manuscript, and durable complete-read evidence. The pure
  two-energy carrier is an explicit untested narrowing.
- R2 `PASS`: endpoints, synchronization, fixed horizon, reversal direction,
  tie, attempt, risk, stops, compensation, and exits are locked.
- R3 `PASS_WITH_HISTORY_AND_BASKET_RISK`: registered XTI/XNG D1 data supplies
  all runtime inputs. Uniform session-label normalization and logical-basket
  evaluation are binding Q01/Q02 requirements.
- R4 `PASS`: deterministic calendar, logarithm, comparison, and execution
  arithmetic only; no ML, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Non-Duplicate Boundary

The canonical checker scanned 4,543 registry rows and 625 root cards and
found no exact identity. Manual review separates the candidate from every
source or carrier neighbor:

- `QM5_13120_energy-momrev` requires disagreement between a 12-month momentum
  rank and the 18-month reversal rank; S04 ignores 12-month information and
  trades every valid non-tied 18-month rank.
- `QM5_20202_xauxag-rev18` uses the same isolated source state on metals; S04
  uses the distinct crude-oil/natural-gas carrier.
- `QM5_12733_xti-xng-xmom` follows a shorter relative winner rather than
  fading the 18-month loser/winner ordering.
- XTI/XNG spread, carry, same-calendar, weekday, maximum-return, and ECM cards
  use different state variables, clocks, or direction maps.
- `QM5_12567` is a standalone XNG cumulative-RSI pullback.

The exact energy carrier, synchronized completed 18-month returns, pure
reversal direction, inclusive tie band, monthly attempt, equal fixed stop-
risk package, and paired monthly lifecycle are jointly load-bearing.

Manual verdict:
`CLEAN_XTI_XNG_PURE_SYNCHRONIZED_18_MONTH_REVERSAL_MONTHLY_BASKET_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Claim, Kill, And Safety Boundary

The source supports an 18-month reversal information object inside broad
cross-sectional commodity portfolios. It does not establish pure two-energy
profitability, CFD/futures equivalence, market neutrality, trade density,
costs, drawdown, or correlation with the certified book.

Expected cadence is approximately eleven to twelve completed packages per
full post-warm-up year. Q02 must retire on zero trades, fewer than five per
year, nonpositive governed economics, wrong endpoints, current-month leakage,
wrong reversal direction, hidden 12-month logic, retry, orphan persistence,
wrong lifecycle, nondeterminism, invalid fixed-risk mode, or insufficient
synchronized history.

The OWNER mission and
`decisions/2026-08-18_xtixng_18m_reversal_source_approval.md` authorize exactly
one card, deterministic ID and magic allocation, one branch-only non-live
build, strict Q01 validation, one `RISK_FIXED` logical-basket backtest setfile,
and one paced target-only Q02 enqueue only below tester and host-CPU ceilings.
They exclude manual tester dispatch; live, demo, shadow, stress, and
optimization artifacts; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; decorrelation or neutrality claims;
and correlation waivers.

## Pipeline History

| version | date | event | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-08-18 | bounded peer-reviewed 18-month reversal carrier extraction | G0 | APPROVED_SOURCE |
