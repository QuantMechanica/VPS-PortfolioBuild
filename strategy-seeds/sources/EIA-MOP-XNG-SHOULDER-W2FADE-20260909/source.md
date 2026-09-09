---
source_id: EIA-MOP-XNG-SHOULDER-W2FADE-20260909
title: XNG shoulder-season two-week exhaustion fade
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_xng_shoulder_two_week_fade_source_approval.md
parent_source_ids: [EIA-XNG-SHOULDER-2026, MOP-TSMOM-2012]
created: 2026-09-09
created_by: Research+Development
cards_extracted: [xng-shoulder-w2fade]
---

# XNG Shoulder-Season Two-Week Exhaustion Fade

## Complete-Read Record

The bounded parents are `strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md`
and `strategy-seeds/sources/MOP-TSMOM-2012/source.md`; both were read end to end
for this extraction. The EIA packet records recurring spring and autumn
natural-gas shoulder periods between winter heating and summer power demand.
The MOP packet records a complete read of Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics*, DOI `10.1016/j.jfineco.2011.11.003`, including
own-return persistence in commodity futures and natural gas membership.

## Claim And Translation Boundary

EIA supplies only the April-May and September-October physical-demand regime.
MOP supplies evidence that commodity returns can persist, which makes two
same-sign weeks a transparent definition of an extended move. Neither source
tests fading that move, the exact weekly horizon, a one-week hold, or a
continuous natural-gas CFD. The contrarian side is an unproven exhaustion
hypothesis. No source performance or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of each normalized broker week:

1. Require the Monday anchor month to be April, May, September, or October.
2. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each with three through five valid D1 sessions.
3. Compute each week's `ln(final_close / first_open)`.
4. When both returns are strictly positive, sell; when both are strictly
   negative, buy. Disagreement, exact zero, or invalid history stays flat.
5. Persist one attempt before fallible gates and never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

`QM5_12567` is a long-only two-day cumulative-RSI pullback above a slow trend.
`QM5_41392` fades one immediately completed week without an exhaustion
confirmation. `QM5_41396` requires two same-sign weeks but follows them only
in June-August. This identity requires two adjacent same-sign weeks, the four
shoulder months, contrarian direction, and a one-week lifecycle together.
The unavailable Strategy Wiki root is recorded in the dedup receipt.

## Runtime And Falsification

Runtime uses configured-symbol D1 OHLC, broker calendar, quotes, spread, ATR,
symbol metadata, positions, deals, and terminal-global attempt state only. It
does not read EIA data, weather, storage, futures curves, volume, files, APIs,
portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, malformed weekly
packages, disagreement entry, momentum rather than fade direction, retry,
missing stop, wrong rollover, nonpositive governed economics, or
nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_TRANSLATION_RISK`: one governed child source
  preserves official-government seasonality context and a completely read
  peer-reviewed JFE commodity paper; the exact exhaustion fade is untested.
- R2 `PASS`: calendar, aggregation, strict agreement, inverse direction,
  attempt, risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1 history
  supplies all runtime market inputs.
- R4 `PASS`: native deterministic arithmetic only; no ML, banned indicator,
  grid, or martingale.

