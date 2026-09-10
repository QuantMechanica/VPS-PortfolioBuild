---
source_id: BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910
title: WTI June-October two-week exhaustion fade
publisher: QuantMechanica governed synthesis of Burakov-Freidin-Solovyev and Yang-Goncu-Pantelous
source_type: peer_reviewed_and_academic_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-10_wti_summer_two_week_fade_source_approval.md
parent_source_ids: [BURAKOV-WTI-HALLOWEEN-2018, YANG-COMM-REVERSAL-2017]
created: 2026-09-10
created_by: Research+Development
cards_extracted: [wti-summer-w2fade]
---

# WTI Summer Two-Week Exhaustion Fade

## Complete-Read Record

The bounded parent records are
`strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md` and
`strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`; both were read end
to end for this extraction. Burakov, Freidin, and Solovyev (2018) provide the
peer-reviewed WTI June-through-October regime. Yang, Goncu, and Pantelous
(2017) provide the academic commodity-reversal lineage and its fixed-horizon
mechanization boundary.

Burakov et al. study monthly WTI prices and do not condition their winter
result on recent weekly returns. Yang et al. do not test this exact WTI-only,
summer-conditioned, two-week state. The weekly horizon, agreement gate,
contrarian direction, fixed-risk execution, ATR stop, spread ceiling, and
one-week lifecycle below are transparent QM translations. No source return,
significance, standalone CFD result, or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each new normalized broker week:

1. Require the Monday anchor month to be June, July, August, September, or
   October.
2. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each containing three through five valid D1 sessions.
3. Compute each completed week's `ln(final_close / first_open)`.
4. Sell only when both returns are strictly positive and buy only when both
   are strictly negative. Mixed signs, exact zero, or invalid state are flat.
5. Persist one attempt before calendar, history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation check found no exact identity and three expected
fuzzy relatives while the configured Strategy Wiki root was unavailable:

- `QM5_41406_wti-summer-w2agree` uses the same WTI summer information object
  but follows its sign; this candidate trades the strict inverse.
- `QM5_41403_wti-winter-w2fade` uses the same inverse map only in the
  disjoint November-May WTI regime.
- `QM5_41402_xng-winter-w2agree` follows two same-sign weeks on XNG during
  November-March; this candidate fades them on WTI during June-October.
- `QM5_41401_xng-shoulder-w2fade` shares the inverse two-week sign map but
  trades XNG only in April, May, September, and October.
- `QM5_41395_xng-winter-wmom` follows one completed XNG week, rather than
  fading two completed WTI weeks.
- `QM5_20185_wti-win-bearfade` is long-only when a 252-D1 return is negative;
  it does not aggregate weekly packages or short positive exhaustion.
- `QM5_20218_wti-winter-rev1` fades exactly one completed broker month and
  renews monthly, not two adjacent completed weeks with a weekly lifecycle.
- `QM5_41022_wti-wdual-mom` follows agreement between two disjoint segments
  inside one completed week year-round; this candidate fades the signs of two
  complete adjacent weeks only in the fixed winter regime.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  above a slow trend, not a symmetric calendar-conditioned WTI exhaustion
  state.

The WTI carrier, June-October Monday anchors, two complete adjacent weeks,
strict same-sign requirement, inverse direction, and next-week exit are
jointly load-bearing. Verdict:
`DISTINCT_WTI_SUMMER_TWO_WEEK_EXHAUSTION_FADE_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK`: a named-author,
  peer-reviewed open WTI seasonality paper and a named-author academic
  commodity-reversal paper are preserved in complete governed source records;
  the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, strict agreement, inverse direction,
  attempt, risk, stop, spread, and rollover rules are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native timestamp/OHLC/logarithm/ATR arithmetic and framework
  state only; no ML, banned signal indicator, grid, martingale, scale-in, or
  external runtime feed.

## Runtime And Falsification Boundary

Runtime uses only configured-symbol D1 OHLC, broker time, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state. It does
not read futures curves, inventory, EIA data, volume, files, APIs, portfolio
state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, same-week retry, non-contrarian entry, missing stop, wrong exit,
nonpositive governed economics, or nondeterminism. Q09 alone may establish
realized portfolio decorrelation.
