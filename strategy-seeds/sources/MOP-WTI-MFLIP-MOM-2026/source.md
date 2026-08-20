---
source_id: MOP-WTI-MFLIP-MOM-2026
title: WTI Fresh Monthly Return-Sign Handoff Momentum
source_type: governed_peer_reviewed_translation_packet
status: approved_for_cards
approved_for_cards: true
approval_record: decisions/2026-08-20_wti_month_flip_momentum_source_approval.md
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-20
created: 2026-08-20
created_by: Research+Development
strategy_ids: [MOP-WTI-MFLIP-MOM-2026_S01]
parent_sources:
  - MOP-TSMOM-2012
---

# WTI Fresh Monthly Return-Sign Handoff Momentum

## Source Identity And Complete-Read Evidence

The governed parent is Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), "Time Series Momentum," *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`.

The complete 23-page published paper was retrieved from author Lasse Heje
Pedersen's NYU faculty site and read end to end. The durable review record is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; it records retrieval
receipt `retrieval_route_20260731.json` and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
Section 3.1 reports positive own-return continuation over the first twelve
monthly lags. Section 3.2 maps the sign of an instrument's completed own
return to the next holding period. Table 2 reports the commodity-futures
portfolio for `k=1`, `h=1`, and Appendix A includes NYMEX WTI.

The paper uses rolled futures excess returns, ex-ante volatility scaling, and
diversified portfolios. It does not report a WTI-only `k=1`, `h=1` result and
does not condition entry on a change between two adjacent monthly return
signs. It also does not test a Darwinex continuous CFD, fixed-dollar ATR risk,
a spread ceiling, persistent restart state, or the QM portfolio. No source
return, trade count, cost, drawdown, correlation, or capacity result transfers.

## Bounded Mechanization

`MOP-WTI-MFLIP-MOM-2026_S01` is one predeclared price-native WTI package:

- exact carrier `XTIUSD.DWX`, D1, magic slot zero;
- evaluate only on the first tradable D1 bar of a new broker month and within
  a fixed five-minute entry grace;
- reconstruct exactly three consecutive completed broker-month-end closes;
- calculate two adjacent, non-overlapping log returns: the newest completed
  month and the month immediately before it;
- BUY only when the older return is strictly negative and the newest return
  is strictly positive; SELL only when the older return is strictly positive
  and the newest return is strictly negative;
- equal signs, exact zero, invalid endpoints, or invalid logarithms consume
  the month flat;
- persist one exact `yyyymm` attempt before any fallible history, signal,
  spread, quote, risk, or order gate, so restart and rejection cannot retry;
- allocate one `RISK_FIXED=1000` budget with `RISK_PERCENT=0`, a frozen
  `3.5 * ATR(20,D1)` hard stop, a 1,500-point spread ceiling, and no target;
- hold the new sign until the first tick of the next broker month, with a
  forty-calendar-day stale guard; and
- do not Friday-close, trail, partially close, scale in, grid, martingale,
  pyramid, optimize, or consume any external runtime feed.

The sign-change gate defines a fresh handoff from one completed monthly state
to the other. Direction remains the source's one-month continuation side: the
EA follows the newest completed month rather than fading it. The freshness
gate is a transparent QM timing hypothesis, not a result claimed by the
paper. Both endpoints, the sign gate, and the monthly lifecycle are locked
before Q02.

## Reputable-Source Criteria

- R1 `PASS_WITH_CONDITIONAL_STATE_RISK`: one governed named-author,
  peer-reviewed JFE source with DOI, complete-paper evidence, durable
  retrieval hash, explicit WTI membership, and explicit disclosure that the
  adjacent-month sign-change condition is untested.
- R2 `PASS`: exact month clock, endpoint chronology, strict sign transition,
  continuation side, attempt persistence, fixed risk, stop, spread, and exit
  are deterministic and locked.
- R3 `PASS`: registered native `XTIUSD.DWX` D1 history and MT5 execution state
  supply every runtime input; Q02 owns CFD-basis and history sufficiency.
- R4 `PASS`: completed prices, timestamps, logarithms, ATR risk plumbing,
  quotes, positions, deal history, and framework state only; no trained
  output, banned signal indicator, external feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Boundary

The canonical pre-card checker scanned 4,551 EA-registry rows and 625 root
cards and returned `CLEAN` with no exact or fuzzy match. Manual family review
returned `CLEAN_WTI_ADJACENT_MONTH_SIGN_HANDOFF_CONTINUATION`:

- `QM5_20187_wti-tsmom1m` enters after every nonzero completed monthly return;
  this package requires a strict sign change versus the separate preceding
  month and is flat after persistence;
- `QM5_20239_wti-pulltrend` follows an older twelve-month trend when the
  newest month opposes it, so it deliberately trades opposite the newest
  month; this package follows the newest month and has no twelve-month state;
- `QM5_41021_wti-mdual-mom` requires agreement between the completed-month
  return and its nested final-five-session return and holds five sessions;
  this package requires disagreement between two full non-overlapping months
  and holds one broker month;
- `QM5_41027_wti-mopen-rev1` forms after current-month opening sessions and
  fades that current-month move; this package decides before any current-
  month close and follows the newest completed month; and
- `QM5_12567_cum-rsi2-commodity` is a two-day cumulative-RSI2 pullback across
  commodity carriers, not monthly WTI return-sign continuation.

The exact three month-end closes, two non-overlapping return intervals,
strict old-to-new sign transition, newest-sign direction, consumed monthly
attempt, and full-month ownership are jointly load-bearing. A failed result
may not be rescued by accepting same-sign months, reversing the side, moving
an endpoint, shortening or extending the hold, changing the stop, or adding a
calendar, volatility, or magnitude filter.

## Safety And Extraction Boundary

The approval record authorizes exactly one V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01, one
canonical `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue
only when fresh tester and host-CPU ceilings permit. It excludes manual tester
dispatch; live, demo, shadow, stress, or optimization presets; AutoTrading;
`T_Live`; deploy or T_Live manifests; portfolio admission; portfolio-gate
edits; correlation waivers; and claims of realized orthogonality. Q09 alone
may establish realized book correlation.

The predeclared cadence is approximately five to eight completed positions
per full post-warm-up year. Q02 must retire the card on zero trades, below five
trades per year, nonpositive governed economics, wrong month-end chronology,
same-sign entry, wrong direction, current-month leakage, repeated or late
entry, wrong risk mode, nondeterminism, or lifecycle failure.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-20 | initial adjacent-month sign-handoff extraction | source | APPROVED_SOURCE |
