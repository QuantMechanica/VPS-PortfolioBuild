---
source_id: EIA-YANG-XNG-SUMMER-W2FADE-20260910
title: XNG summer-demand two-week exhaustion fade
publisher: QuantMechanica governed synthesis of EIA and Yang-Goncu-Pantelous
source_type: official_government_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_xng_summer_two_week_fade_source_approval.md
parent_source_ids: [EIA-XNG-SHOULDER-2026, YANG-COMM-REVERSAL-2017]
created: 2026-09-10
created_by: Research+Development
cards_extracted: [xng-summer-w2fade]
---

# XNG Summer-Demand Two-Week Exhaustion Fade

## Complete-Read Record

The bounded parent records are
`strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md` and
`strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`; both were read end
to end for this extraction. The official U.S. Energy Information
Administration record establishes recurring summer natural-gas demand from
electric generation. Yang, Goncu, and Pantelous (2017) supply academic
commodity fixed-horizon reversal lineage.

Neither source tests this exact XNG-only summer-conditioned two-week state.
The weekly horizon, same-sign gate, contrarian direction, fixed-risk execution,
ATR stop, spread ceiling, and one-week lifecycle are transparent QM
translations. No source performance, significance, CFD equivalence, or
diversification claim transfers.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of each normalized broker week:

1. Require the Monday anchor month to be June, July, or August.
2. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five unique D1 sessions.
3. Compute each completed week's `ln(final_close / first_open)`.
4. Sell only when both returns are strictly positive and buy only when both
   are strictly negative. Mixed signs, exact zero, or invalid state are flat.
5. Persist one attempt before calendar, history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical screen found no exact slug or strategy-ID collision and returned
the expected fuzzy family matches. `QM5_41396` follows the same XNG summer
two-week state; this card trades its strict inverse. `QM5_41407` uses the
inverse map on WTI and a broader June-October regime. `QM5_41401` and
`QM5_41408` use XNG only in disjoint shoulder and winter months.
`QM5_13102` adds a volatility gate to a one-week, year-round reversal, and
`QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI pullback
above a slow trend. This identity jointly fixes the XNG carrier, June-August
anchor, two adjacent complete weeks, strict agreement, inverse direction, and
next-week lifecycle. Realized correlation remains a later governed gate.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK`: official U.S.
  government seasonality context and a named-author academic commodity-
  reversal source are preserved in completely read governed records.
- R2 `PASS`: calendar, aggregation, strict agreement, inverse direction,
  attempt, risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native timestamps, OHLC, logarithm, ATR, quote, position, deal,
  and persistent-state arithmetic only; no ML, banned signal indicator, grid,
  martingale, scale-in, or external runtime feed.

## Runtime And Falsification Boundary

Runtime uses only configured-symbol D1 OHLC, broker time, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state. It does
not read EIA data, weather, storage, futures curves, volume, files, APIs,
portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, same-week retry, non-contrarian entry, missing stop, wrong exit,
nonpositive governed economics, or nondeterminism. Q09 alone may establish
realized portfolio decorrelation.
