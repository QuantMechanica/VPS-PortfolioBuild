---
source_id: EIA-MOP-XNG-WINTER-WMOM-2026
title: XNG winter-demand completed-week momentum
publisher: QuantMechanica governed conjunction of EIA and Moskowitz-Ooi-Pedersen sources
source_type: official_government_and_peer_reviewed_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-09_xng_winter_weekly_momentum_source_approval.md
parent_source_ids: [EIA-XNG-SHOULDER-2026, MOP-TSMOM-2012]
created: 2026-09-09
created_by: Research+Development
cards_extracted: [xng-winter-wmom]
---

# XNG Winter-Demand Completed-Week Momentum

## Complete-Read Record

The bounded parents are
`strategy-seeds/sources/EIA-XNG-SHOULDER-2026/source.md` and
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. Both were read end to end
for this extraction. The EIA packet records recurring winter heating and
summer electric-generation demand peaks in natural gas. The MOP packet records
a complete read of Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics*, DOI `10.1016/j.jfineco.2011.11.003`, including own-return time-series
momentum in commodity futures and natural gas in the source universe.

## Source Finding And Translation Boundary

EIA supplies the winter-demand regime context. MOP supplies directional
own-return continuation at monthly horizons. Neither source tests the exact
November-through-March, one-completed-week formation and one-week hold on a
continuous natural-gas CFD. The weekly horizon, five fixed anchor months,
fixed-risk execution, ATR stop, spread limit, and lifecycle are transparent QM
translations. No source performance, standalone XNG result, CFD equivalence,
or diversification claim transfers.

## Bounded Mechanization

At the first tradable `XNGUSD.DWX` D1 bar of each new normalized broker week:

1. Require the Monday anchor month to be November, December, January,
   February, or March.
2. Aggregate exactly the immediately completed adjacent three-to-five-session
   week and compute `r = ln(final_close / first_open)`.
3. Buy when `r > 0`, sell when `r < 0`, and consume exact zero or invalid state
   flat.
4. Persist one attempt before history, signal, news, spread, quote, ATR,
   sizing, or order gates; never retry that week.
5. Close at the next normalized week; ten elapsed days is stale repair.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.

## Non-Duplicate Boundary

`QM5_12567` is a long-only two-day cumulative-RSI pullback above a slow trend.
`QM5_41392` trades only April, May, September, and October and fades the prior
week. Existing weekly XNG momentum systems use all-year volatility, flow,
close-location, body-dominance, or state-transition gates. This identity fixes
the five winter anchor months, unconditional strict prior-week sign
continuation, and next-week lifecycle together. Realized correlation remains
exclusively a later governed gate.

## Runtime And Falsification

Runtime uses only configured-symbol D1 OHLC, broker calendar, quotes, spread,
ATR, symbol metadata, positions, deals, and terminal-global attempt state. It
does not read EIA data, weather, storage, futures curves, volume, files, APIs,
portfolio state, optimizer output, or trained artifacts.

Retire rather than tune on zero trades, fewer than five completed positions in
any full post-warm-up year, wrong seasonal eligibility, wrong weekly package,
same-week retry, missing stop, wrong exit, nonpositive governed economics, or
nondeterminism.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: official U.S.
  government seasonality context plus a completely read peer-reviewed JFE
  momentum paper; the exact conjunction is untested.
- R2 `PASS`: calendar, aggregation, sign, direction, attempt, risk, stop,
  spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1 history
  supplies all runtime market inputs.
- R4 `PASS`: native timestamps, OHLC, logarithm, ATR, quotes, positions, deals,
  and persistent state only; no ML, banned indicator, grid, or martingale.

