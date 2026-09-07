---
source_id: AI-CODEX-XTIXNG-WEFFDIV-RV-20260907
title: XTI/XNG completed-week body-range efficiency divergence reversion
publisher: QuantMechanica governed extraction from U.S. EIA and peer-reviewed research
source_type: governed_composite_source
status: approved_source_complete
approval_basis: decisions/2026-09-07_xtixng_weekly_efficiency_divergence_reversion_source_approval.md
created: 2026-09-07
created_by: Research+Development
uri: https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf
cards_extracted:
  - xtixng-weffdiv-rv
---

# XTI/XNG Completed-Week Efficiency-Divergence Reversion

## Approval And Complete-Read Scope

The durable source approval was committed before this extraction. The complete
governed `VILLAR-RAMBERG-OILGAS-2026` and `FMR-MOMTS-2010` packets were read
before approval. They preserve complete-read evidence for the underlying U.S.
EIA report and peer-reviewed oil/gas and commodity papers, including adverse
evidence about weak and time-varying oil/gas linkage.

This extraction is bounded to one transparent price-native state. It does not
claim that body-to-range efficiency divergence is a published anomaly.

## Primary Citations

1. Villar, Jose A., and Frederick L. Joutz (2006), "The Relationship Between
   Crude Oil and Natural Gas Prices," U.S. Energy Information Administration,
   43 pages, https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf.
2. Ramberg, David J., and John E. Parsons (2012), "The Weak Tie Between
   Natural Gas and Oil Prices," *The Energy Journal* 33(2), 13-35, DOI
   https://doi.org/10.5547/01956574.33.2.2.
3. Fuertes, Ana-Maria, Joelle Miffre, and Georgios Rallis (2010), "Tactical
   Allocation in Commodity Futures Markets: Combining Momentum and Term
   Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
   https://doi.org/10.1016/j.jbankfin.2010.04.009.

## Source Boundary And Adverse Evidence

Villar and Joutz document economic oil/gas links and temporary decoupling.
Ramberg and Parsons find a weak, regime-dependent relationship that leaves
most gas-price variation unexplained. Fuertes, Miffre, and Rallis provide
reputable commodity relative-return lineage, not this two-CFD reversal rule.

None of the sources specifies weekly body/range efficiencies, opposite
terciles, a contrarian package, ATR stops, equal notionals, or a one-week hold.
Those are an explicitly unproven QM translation. Opposed equal-notional legs
do not prove beta, volatility, factor, dollar, or portfolio neutrality.

## Bounded Mechanization

At the first tradable D1 bar of a new broker week, reconstruct the exact
immediately preceding completed broker week from three to five synchronized
XTIUSD.DWX and XNGUSD.DWX sessions. Aggregate each leg's chronological open,
high, low, and chronological final close. Compute independently:

`e_j = abs(close_j-open_j)/(high_j-low_j)`.

Require finite positive OHLC, positive range, nonzero body, `0 < e_j <= 1`,
and exactly one of these strict states:

- `e_XTI > 2/3` and `e_XNG < 1/3`; or
- `e_XNG > 2/3` and `e_XTI < 1/3`.

Fade the high-efficiency leg's completed-week body sign. An up body is sold;
a down body is bought. Trade the low-efficiency companion in the opposite
direction regardless of its own body sign. Equality and all other states are
flat. Split one aggregate fixed-risk budget across equal-absolute-notional
opposed legs, use independent frozen `3.5*ATR(20,D1)` stops, and close both at
the next broker-week boundary. Consume one durable attempt before fallible
gates and repair malformed or orphaned exposure to flat.

## Non-Duplicate Boundary

The deterministic checker covered 4,854 EA-registry rows and 1,467 repository
cards, found no exact identity, and returned no fuzzy match above threshold.
The external Strategy Wiki root was unavailable and remains an explicit
coverage limitation authorized by the direct OWNER mission.

Nearest mechanics remain distinct:

- `QM5_41092` and `QM5_41094` are single-leg weekly body-dominance momentum;
  this rule compares two independent efficiencies and fades the directional
  leg in an opposed energy package.
- `QM5_41364` compares independent completed-week close locations, not
  absolute open-to-close travel divided by range, and its direction comes
  from which leg closed high versus low rather than a body sign.
- `QM5_41126` and `QM5_20274` use multi-session net-to-L1 path efficiency on
  outright WTI monthly windows; this rule uses one weekly aggregate body/range
  ratio on both legs and a cross-leg divergence state.
- XTI/XNG ratio, residual, return-sign, flow, lead-switch, and alternation
  systems do not own the exact independent efficiency-tercile conjunction.

The exact carrier, synchronized prior-week OHLC, absolute body/range formula,
strict high/low efficiency terciles, high-efficiency body-sign fade,
opposed companion, aggregate risk, and next-week exit are jointly
load-bearing. Verdict:
`DISTINCT_XTIXNG_COMPLETED_WEEK_BODY_RANGE_EFFICIENCY_DIVERGENCE_HIGH_EFFICIENCY_LEG_FADE`.

## R1-R4

- R1: `PASS_WITH_RULE_TRANSLATION_RISK`; reputable government and
  peer-reviewed sources, adverse evidence retained, no efficacy transferred.
- R2: `PASS`; endpoints, arithmetic, strict state, side, attempt, aggregate
  risk, stops, atomic repair, and lifecycle are fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`; registered
  native XTI/XNG D1 history and symbol metadata supply all runtime inputs.
- R4: `PASS`; deterministic native arithmetic only, without ML, banned
  signal, external runtime feed, grid, martingale, or pyramid.

## Safety And Falsification Boundary

Q02 must retire the card on zero packages, fewer than five completed packages
in any full post-warm-up year, or nonpositive governed economics. No carrier,
threshold, side, risk, or lifecycle rescue is authorized. The approval
excludes manual testing, optimization, portfolio admission, correlation
waivers, deployment, live manifests, `T_Live`, AutoTrading, and live use.

