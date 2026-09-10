---
source_id: YANG-WTI-WALT3-FADE-20260910
title: WTI three-week strict sign-alternation fade
publisher: QuantMechanica governed extraction from academic commodity-reversal research
source_type: academic_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_weekly_alternation_fade_source_approval.md
parent_source_ids: [YANG-COMM-REVERSAL-2017, KWON-KANG-YUN-WTI-WMOM1-2026]
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-walt3-fade]
---

# WTI Three-Week Strict Sign-Alternation Fade

## Complete-Read Record

The bounded parent records
`strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md` and
`strategy-seeds/sources/KWON-KANG-YUN-WTI-WMOM1-2026/source.md` were read end
to end before this extraction. The first records Yang, Goncu, and Pantelous,
*Momentum and Reversal in Commodity Futures*, SSRN abstract 3069253, as
academic structural commodity-reversal lineage. The second preserves the
complete 20-page accepted manuscript, DOI, institutional retrieval URL and PDF
hash for Kwon, Kang, and Yun (2020), *Weekly Momentum in the Commodity Futures
Market*, Finance Research Letters 35, 101306.

Kwon, Kang, and Yun define a week `t-1` formation and week `t` holding interval
and explicitly include light sweet crude oil. Yang, Goncu, and Pantelous supply
commodity-futures reversal lineage. Neither source tests a standalone WTI
three-week sign-alternation fade, continuous-CFD labels, fixed risk, or ATR
stops. Those are transparent QM translations. No reported return,
significance, cause, neutrality, or book-decorrelation claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each new normalized broker week:

1. Reconstruct exactly the three immediately completed adjacent normalized
   broker weeks, each with three through five unique valid D1 sessions.
2. For each week compute `r = ln(final_close / first_open)` from that week's
   chronological first and final sessions.
3. Require all returns finite, nonzero, and strictly alternating in oldest to
   newest order: `+,-,+` or `-,+,-`.
4. Fade the newest sign: sell on `+,-,+`; buy on `-,+,-`.
5. Persist one weekly attempt before history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The pre-allocation checker found no exact identity and only the expected
momentum-direction sibling `QM5_41411_wti-walt3-cont`. That sibling buys
`+,-,+` and sells `-,+,-`; this card does the exact opposite under reversal
lineage. Direction is the economic hypothesis and a load-bearing identity
field. `QM5_41065` uses only two close-to-close returns and follows a fresh
sign handoff. Seasonal WTI fades require calendar windows and same-sign weeks.
One-week reversal variants do not require two consecutive sign changes.

Verdict:
`DISTINCT_WTI_THREE_COMPLETED_WEEK_OPEN_CLOSE_STRICT_ALTERNATION_NEWEST_SIGN_REVERSAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_STATE_TRANSLATION_RISK`: academic commodity-
  reversal lineage plus a complete peer-reviewed weekly-horizon and explicit
  WTI-membership record; exact alternating-state efficacy is untested.
- R2 `PASS`: packages, endpoints, signs, opposite side, attempt, risk, stop,
  spread, and lifecycle are deterministic.
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
