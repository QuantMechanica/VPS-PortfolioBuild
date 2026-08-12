---
source_id: SCHWEIKERT-CME-XAUXAG-QTAIL-2026
title: Gold-silver empirical-quantile two-tail reversion extraction
publisher: QuantMechanica governed extraction of peer-reviewed and exchange sources
source_type: peer_reviewed_plus_exchange_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-09_qm5_20268_xauxag_qtail_rv_g0.md
parent_source_ids:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
created: 2026-08-09
created_by: Research+Development
cards_extracted:
  - xauxag-qtail-rv
---

# XAU/XAG Empirical-Quantile Tail Source Packet

## Approved Source Of Record

This bounded extraction uses only two already approved, completely reviewed
repository packets:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, covering
   Karsten Schweikert (2018), "Are gold and silver cointegrated? New
   evidence from quantile cointegrating regressions," *Journal of Banking &
   Finance* 88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo,
   Olayinka (2021), *Resources Policy* 72, 102045, DOI
   `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, covering CME Group,
   "Gold & Silver Ratio Spread" and its governed related material.

The durable OWNER approval is
`decisions/2026-08-09_qm5_20268_xauxag_qtail_rv_g0.md`. No new online page,
blocked content, or inferred table value is used.

## Source Findings Used

The peer-reviewed lineage supports testing a state-dependent, potentially
nonlinear long-run gold/silver relationship rather than assuming one constant
equilibrium. The CME lineage supports treating the gold/silver ratio as one
intermarket relative-value carrier. These facts justify a falsifiable
relative-price hypothesis; they do not establish that an empirical tail
persists or subsequently converges on Darwinex spot CFDs.

## Bounded QM Mechanization

On a new `XAUUSD.DWX` D1 host bar, align 129 completed XAU/XAG closes and form
`r=ln(XAU)-ln(XAG)`. Sort the 126 ratios at shifts 4 through 129. Define the
nearest-rank tenth and ninetieth percentiles from zero-based indexes 12 and
113 and define the even-sample median as the average of indexes 62 and 63.

The newest three completed ratios are a separate ordered event. Require shift
3 inside or on the frozen decile band and shifts 2 and 1 both strictly beyond
the same tail. Fade an upper event by selling XAU and buying XAG; fade a lower
event with the opposite sides. Exit through the median of the newest twenty-
one synchronized ratios, after thirty-five days, or on invalid state/package.

The empirical window, exact order-statistic indexes, two-close confirmation,
directions, CFD carrier, fixed-risk split, ATR stops, spread caps, attempt
ledger, and lifecycle are transparent QM choices. They are not attributed to
the sources. No source return, alpha, drawdown, density, CFD equivalence,
neutrality, or portfolio-correlation statistic is imported.

## Exact Statistical Contract

For positive finite synchronized completed ratios, sort only `r[4..129]`:

```text
q10 = sorted[12]
q50 = (sorted[62] + sorted[63]) / 2
q90 = sorted[113]
require q10 < q50 < q90

upper event = q10 <= r[3] <= q90 and r[2] > q90 and r[1] > q90
lower event = q10 <= r[3] <= q90 and r[2] < q10 and r[1] < q10
```

There is no fallback to a mean, standard deviation, MAD score, OLS residual,
conditional-quantile regression, channel extreme, oscillator, external
series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker returned `CLEAN` across 4,325
registry rows and 441 cards. Existing XAU/XAG level-convergence systems use
mean/standard-deviation scores, OLS residuals, conditional quantile
regressions, median/MAD scores, channel continuation, or outside-to-inside
failed breaks. None uses a frozen empirical ratio distribution excluding a
central observation plus two consecutive tail closes.

The order-statistic estimator and ordered two-hit tail event are both
load-bearing. Replacing them with a standardized extreme, current channel
break, or return-inside event collapses the candidate into an existing family.

## Reputable-Source Criteria

- R1: PASS. Two named-author peer-reviewed DOI records plus a governed CME
  exchange packet support the carrier; no performance claim transfers.
- R2: PASS. Exact sample shifts, sort indexes, event ordering, sides, risk,
  stops, median exit, attempt, and stale exit are fixed and mechanical.
- R3: PASS with disclosed basis risk. Registered `XAUUSD.DWX` and
  `XAGUSD.DWX` D1 histories plus native MT5 execution state supply every
  runtime input. Q02 is bounded to synchronized history.
- R4: PASS. Runtime uses timestamps, prices, logarithms, sorting, arithmetic,
  ATR, spread, quote, and native trade state only; no trained model, external
  feed, grid, martingale, scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing a structural relative-value carrier, not this
tail rule's efficacy. Q02 must retire the card below five completed packages
per full post-warm-up year or on nonpositive governed economics. Downstream
gates alone own robustness and correlation. No failure may be rescued by
changing the lookback, order-statistic index, event length, side, exit median,
stop, hold, retry contract, or carrier.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or neutrality claim.
