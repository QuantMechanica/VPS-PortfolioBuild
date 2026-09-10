---
source_id: KWON-WTI-WALT3-CONT-20260910
title: WTI three-week strict sign-alternation continuation
publisher: QuantMechanica governed extraction from peer-reviewed research
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_weekly_alternation_continuation_source_approval.md
parent_source_ids: [KWON-KANG-YUN-WTI-WMOM1-2026]
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-walt3-cont]
---

# WTI Three-Week Strict Sign-Alternation Continuation

## Complete-Read Record

The bounded parent record
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md` was read end to
end before this extraction. It preserves the complete 20-page accepted
manuscript, DOI, institutional retrieval URL and PDF hash for Kwon, Kang, and
Yun (2020), *Weekly Momentum in the Commodity Futures Market*, Finance
Research Letters 35, 101306, DOI `10.1016/j.frl.2019.101306`.

The paper defines a week `t-1` formation and week `t` holding interval,
explicitly includes light sweet crude oil, and reports cross-sectional
winner-minus-loser evidence. It does not test a standalone WTI time-series
rule, a three-week sign-alternation condition, continuous-CFD labels, fixed
risk, or ATR stops. Those are transparent QM translations. No reported return,
significance, cause, neutrality, or book-decorrelation claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each new normalized broker week:

1. Reconstruct exactly the three immediately completed adjacent normalized
   broker weeks, each with three through five unique valid D1 sessions.
2. For each week compute `r = ln(final_close / first_open)` from that week's
   chronological first and final sessions.
3. Require all returns finite, nonzero, and strictly alternating in oldest to
   newest order: `+,-,+` or `-,+,-`.
4. Follow the newest sign: buy on `+,-,+`; sell on `-,+,-`.
5. Persist one weekly attempt before history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The pre-allocation checker found no exact identity. Its expected fuzzy family
members are manually separated as follows:

- `QM5_41375_wti-wmom1` follows one completed week's sign unconditionally;
  this card requires three complete weekly packages in exact alternation.
- `QM5_41065_wti-wflip-mom` uses two adjacent close-to-close weekly returns
  from three week-ending closes and one fresh sign change. This card uses three
  separate within-week first-open/final-close returns and two consecutive sign
  changes.
- `QM5_41074_wti-wstreak3-mom` requires a fresh three-week same-sign streak
  after an opposite predecessor; exact alternation is disjoint.
- `QM5_41404` and `QM5_41406` require two same-sign weeks inside seasonal
  windows; this card is year-round and requires all adjacent signs to differ.
- `QM5_41080` and `QM5_41091` use close-location or inside-body weekly OHLC
  geometry. This card uses no high, low, range, or containment condition.
- `QM5_41373` and `QM5_41410` apply strict alternation to two-leg relative
  returns and fade the newest relative winner; this card is outright WTI and
  follows its newest own-return sign.

The carrier, three complete within-week return objects, exact sign state,
direction, and lifecycle are jointly load-bearing. Verdict:
`DISTINCT_WTI_THREE_COMPLETED_WEEK_OPEN_CLOSE_STRICT_ALTERNATION_NEWEST_SIGN_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_TIME_SERIES_AND_ALTERNATION_TRANSLATION_RISK`: complete
  peer-reviewed source record, exact weekly horizon, WTI membership, and
  adverse cross-sectional-to-time-series boundary preserved.
- R2 `PASS`: packages, endpoints, signs, side, attempt, risk, stop, spread,
  and lifecycle are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  WTI D1 history supplies every runtime input.
- R4 `PASS`: timestamp/OHLC/logarithm/ATR arithmetic only; no ML, banned
  signal, external feed, grid, martingale, pyramid, or adaptive PnL fit.

## Runtime And Falsification Boundary

Runtime uses only configured-symbol D1 OHLC, broker time, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state. Retire
rather than tune on zero trades, fewer than five completed trades in any full
post-warm-up year, malformed weekly packages, wrong sign or side, same-week
retry, missing stop, wrong next-week exit, nonpositive governed economics, or
nondeterminism. Q09 alone may establish realized portfolio decorrelation.

