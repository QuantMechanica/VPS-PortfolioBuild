---
source_id: BURAKOV-MOP-WTI-WINTER-W2AGREE-20260909
title: WTI winter-regime two-week agreement momentum
publisher: QuantMechanica governed synthesis of Burakov-Freidin-Solovyev and Moskowitz-Ooi-Pedersen
source_type: peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_wti_winter_two_week_agreement_source_approval.md
parent_source_ids: [BURAKOV-WTI-HALLOWEEN-2018, MOP-TSMOM-2012]
created: 2026-09-09
created_by: Research+Development
cards_extracted: [wti-winter-w2agree]
---

# WTI Winter-Regime Two-Week Agreement Momentum

## Complete-Read Record

The bounded parent records are
`strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; both were read end to end
for this extraction. Burakov, Freidin, and Solovyev (2018) provide the
peer-reviewed WTI November-through-May regime. Moskowitz, Ooi, and Pedersen
(2012) provide the peer-reviewed own-return continuation lineage and identify
NYMEX WTI in their commodity universe.

Burakov et al. study a continuous monthly winter exposure and do not
condition it on recent weekly returns. Moskowitz et al. study monthly horizons
and do not test this WTI-only winter interaction, two adjacent completed
weeks, or a one-week hold. The horizon, agreement gate, fixed-risk execution,
ATR stop, spread ceiling, and lifecycle below are transparent QM translations.
No source return, standalone WTI result, CFD equivalence, or diversification
claim transfers.

## Bounded Mechanization

At the first tradable `XTIUSD.DWX` D1 bar of each new normalized broker week:

1. Require the Monday anchor month to be November, December, January,
   February, March, April, or May.
2. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each containing three through five valid D1 sessions.
3. Compute each completed week's `ln(final_close / first_open)`.
4. Buy only when both returns are strictly positive and sell only when both
   are strictly negative. Mixed signs, exact zero, or invalid state are flat.
5. Persist one attempt before calendar, history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

The canonical pre-allocation checker found no exact identity and five
expected fuzzy family matches while the configured Strategy Wiki root was
unavailable:

- `QM5_41403_wti-winter-w2fade` uses the same WTI regime and information
  object but trades the exact opposite side. Fade versus continuation is the
  load-bearing alpha map.
- `QM5_41402_xng-winter-w2agree` applies two-week continuation to natural gas
  during November-March, not WTI during November-May.
- `QM5_41395_xng-winter-wmom` uses one completed natural-gas week.
- `QM5_41396_xng-summer-w2agree` uses natural gas only in June-August.
- `QM5_41401_xng-shoulder-w2fade` is a natural-gas contrarian shoulder-season
  rule.
- `QM5_41375_wti-wmom1` follows only one completed WTI week year-round.
- `QM5_41022_wti-wdual-mom` follows two disjoint segments inside one prior
  week year-round rather than two adjacent complete weeks in a fixed season.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback.

The WTI carrier, November-May Monday anchors, two complete adjacent weeks,
strict same-sign requirement, continuation direction, and next-week exit are
jointly load-bearing. Verdict:
`DISTINCT_WTI_WINTER_TWO_WEEK_AGREEMENT_AFTER_MANUAL_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK`: named-author,
  peer-reviewed WTI seasonality and time-series-momentum records were read
  completely; the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, strict agreement, direction, attempt,
  risk, stop, spread, and rollover rules are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 history
  supplies every runtime market input.
- R4 `PASS`: native timestamp/OHLC/logarithm/ATR arithmetic and framework
  state only; no ML, banned signal indicator, grid, martingale, scale-in, or
  external runtime feed.

## Runtime And Falsification Boundary

Runtime uses only configured-symbol D1 OHLC, broker time, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state. It does
not read futures curves, inventory, volume, open interest, files, APIs,
portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, mixed-sign entry, same-week retry, missing stop, wrong exit,
nonpositive governed economics, or nondeterminism. Q09 alone may establish
realized portfolio decorrelation.

