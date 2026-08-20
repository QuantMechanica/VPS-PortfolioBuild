---
source_id: MOP-XNG-WFLIP-MOM-2026
title: Natural Gas Fresh Weekly Return-Sign Handoff Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-20_xng_week_flip_momentum_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-20
created: 2026-08-20
created_by: Research+Development
strategy_ids: [MOP-XNG-WFLIP-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
---

# Natural Gas Fresh Weekly Return-Sign Handoff Momentum

## Source Identity And Complete-Read Evidence

The governed parent is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The complete 23-page published paper was retrieved from author Lasse Heje
Pedersen's NYU faculty site and read end to end. The durable review record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; it records retrieval receipt
`retrieval_route_20260731.json` and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
Sections 3.1-3.2 document positive own-return continuation and mechanically
map the sign of an instrument's past return to the next holding period. The
paper's commodity universe includes natural gas.

The paper's reported formation and holding horizons are monthly. It does not
report a natural-gas-only weekly rule and does not condition entry on a change
between two adjacent weekly return signs. It also does not test a Darwinex
continuous CFD, fixed-dollar ATR risk, spread ceiling, persistent restart
state, or the QM portfolio. No source or WTI-sibling return, trade count, cost,
drawdown, correlation, or capacity result transfers.

## Bounded Mechanization

`MOP-XNG-WFLIP-MOM-2026_S01` is one predeclared price-native natural-gas
package:

- exact carrier `XNGUSD.DWX`, D1, magic slot zero;
- evaluate only on the first tradable D1 bar whose normalized Monday anchor
  is later than the preceding completed bar's anchor and within a fixed 180-
  minute entry grace;
- reconstruct exactly three consecutive completed broker-week-end closes;
- calculate two adjacent, non-overlapping log returns: the newest completed
  week and the week immediately before it;
- BUY only when the older return is strictly negative and the newest return
  is strictly positive; SELL only when the older return is strictly positive
  and the newest return is strictly negative;
- equal signs, exact zero, invalid endpoints, or nonconsecutive week anchors
  consume the broker week flat;
- persist the exact current Monday anchor before any fallible history, signal,
  spread, quote, risk, or order gate, so restart and rejection cannot retry;
- allocate one `RISK_FIXED=1000` budget with `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- hold the new sign until the first tick of a later broker-week anchor, with a
  ten-calendar-day stale guard; and
- do not Friday-close, trail, partially close, scale in, grid, martingale,
  pyramid, optimize, or consume any external runtime feed.

The sign-change gate defines a fresh handoff from one completed weekly state
to the other. Direction follows the newest completed week. Both the weekly
horizon and freshness gate are transparent QM timing hypotheses, not results
claimed by the paper. The three endpoints, strict gate, and lifecycle are
locked before Q02.

## Reputable-Source Criteria

- R1 `PASS_WITH_WEEKLY_HORIZON_AND_TRANSITION_RISK`: one governed named-
  author, peer-reviewed JFE source with DOI, complete-paper evidence, durable
  retrieval hash, explicit natural-gas membership, and explicit disclosure
  that the weekly horizon and adjacent-week sign-change condition are
  untested.
- R2 `PASS`: exact week clock, endpoint chronology, strict sign transition,
  continuation side, attempt persistence, fixed risk, stop, spread, and exit
  are deterministic and locked.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 execution state supply every runtime input;
  Q02 owns CFD-basis, label, history, and density sufficiency.
- R4 `PASS`: completed prices, timestamps, logarithms, ATR risk plumbing,
  quotes, positions, deal history, and framework state only; no trained
  output, banned signal indicator, external feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,554 EA-registry rows and 625 root
cards and returned `CLEAN` with no exact or fuzzy match. Manual family review
returned `CLEAN_XNG_ADJACENT_WEEK_SIGN_HANDOFF_CONTINUATION`:

- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI2
  pullback under a slow trend filter and a five-bar maximum hold; this package
  is symmetric, oscillator-free, and owns one full broker week;
- `QM5_13101_xng-1w-mom-vol` thresholds a five-D1 return under a realized-
  volatility-rank cap and permits signal exit; this package has neither
  magnitude nor volatility gates and requires two separate full-week signs to
  disagree;
- `QM5_21520_xng-flow-mom` conditions a five-bar return on a bottom-quartile
  native tick-volume rank; this package consumes no volume field or rank;
- `QM5_20204_xng-tsmom1m` follows one completed calendar-month return
  unconditionally for a month, while `QM5_20054_xng-1m-contr` fades that
  monthly sign; this package is weekly, transition-gated, and follows the
  newest sign;
- `QM5_41063_xng-week-nr7-brk` ranks seven complete weekly high-low ranges and
  enters only after a next-week completed-close breakout; this package uses
  only three week-end closes and no range or breakout; and
- `QM5_41065_wti-wflip-mom` is the exact predeclared WTI carrier sibling. This
  candidate is the distinct natural-gas carrier falsification and inherits no
  WTI pipeline result.

The exact XNG carrier, three week-end closes, two non-overlapping return
intervals, strict old-to-new sign transition, newest-sign direction, consumed
weekly attempt, and full-week ownership are jointly load-bearing. A failed
result may not be rescued by accepting same-sign weeks, reversing the side,
moving an endpoint, changing the hold or stop, or adding a calendar,
volatility, magnitude, or volume filter.

## Safety And Extraction Boundary

The approval record authorizes exactly one V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01, one
canonical `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue
only when fresh tester and host-CPU ceilings permit. It excludes manual tester
dispatch; live, demo, shadow, stress, or optimization presets; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; correlation waivers; and claims of realized orthogonality. Q09 alone
may establish realized book correlation.

The predeclared cadence is approximately eighteen to thirty completed
positions per full post-warm-up year. Q02 must retire the card on zero trades,
below five trades per year, nonpositive governed economics, wrong week-end
chronology, same-sign entry, wrong direction, current-week leakage, repeated
or late entry, wrong risk mode, nondeterminism, or lifecycle failure.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial adjacent-week XNG sign-handoff extraction | source | APPROVED_SOURCE |

