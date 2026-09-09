---
source_id: EIA-MOP-XNG-WINTER-W2AGREE-20260909
title: XNG winter-demand two-week agreement momentum
publisher: QuantMechanica governed synthesis of EIA and Moskowitz-Ooi-Pedersen
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_xng_winter_two_week_agreement_source_approval.md
parent_source_ids: [EIA-XNG-SHOULDER-2026, MOP-TSMOM-2012]
created: 2026-09-09
created_by: Research+Development
cards_extracted: [xng-winter-w2agree]
---

# XNG Winter-Demand Two-Week Agreement Momentum

## Complete-Read Record

The bounded parents are
`strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; both were read end to end
for this extraction. The EIA packet records recurring winter natural-gas
consumption peaks tied to heating demand. The MOP packet records a complete
read of Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*,
DOI `10.1016/j.jfineco.2011.11.003`, including own-return time-series momentum
in commodity futures and natural gas in the source universe.

## Source Finding And Translation Boundary

EIA supplies only the November-through-March winter-demand regime context.
MOP supplies directional own-return continuation at monthly horizons. Neither
source tests two adjacent completed weeks, same-sign agreement, a one-week
hold, or a continuous natural-gas CFD. Those rules, fixed-risk execution, ATR
stop, spread limit, and lifecycle are transparent QM translations. No source
performance, standalone XNG result, CFD equivalence, or diversification claim
transfers.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of each new normalized broker week:

1. Require the Monday anchor month to be November, December, January,
   February, or March.
2. Reconstruct exactly the two immediately completed adjacent normalized
   broker weeks, each containing three through five valid D1 sessions.
3. Compute each week's open-to-close log return.
4. Buy only when both returns are strictly positive and sell only when both
   are strictly negative. Mixed signs, exact zero, or invalid state are flat.
5. Persist one attempt before calendar, history, signal, news, spread, quote,
   ATR, sizing, or order gates; never retry that week.
6. Close at the next normalized week; ten elapsed days is stale repair.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

`QM5_12567` is a long-only two-day cumulative-RSI pullback above a slow trend.
`QM5_41395` uses only one completed week in the same winter calendar.
`QM5_41396` requires two-week agreement but only during June, July, and August.
`QM5_20162` is a long-only 21/84-D1 moving-average stack with slope gates.
Other XNG weekly families use volatility, close-location, flow, range
migration, acceleration, or state-transition gates. This identity requires
two adjacent completed weeks, strict same-sign agreement, the five-month
winter anchor regime, symmetric continuation, and a one-week lifecycle
together. Realized correlation remains exclusively a later governed gate.

## Runtime And Falsification

Runtime uses only configured-symbol D1 OHLC, broker calendar, quotes, spread,
ATR, symbol metadata, positions, deals, and terminal-global attempt state. It
does not read EIA data, weather, storage, futures curves, volume, files, APIs,
portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, wrong weekly packages,
mixed-sign entry, same-week retry, missing stop, wrong exit, nonpositive
governed economics, or nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: one governed child
  source preserves official U.S. government seasonality context and a
  completely read peer-reviewed JFE momentum paper; the exact conjunction is
  untested.
- R2 `PASS`: calendar, aggregation, strict agreement, direction, attempt,
  risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1 history
  supplies all runtime market inputs.
- R4 `PASS`: native timestamps, OHLC, logarithm, ATR, quotes, positions, deals,
  and persistent state only; no ML, banned indicator, grid, or martingale.

