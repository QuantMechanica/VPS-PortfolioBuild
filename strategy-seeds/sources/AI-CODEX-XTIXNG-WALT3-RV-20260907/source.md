---
source_id: AI-CODEX-XTIXNG-WALT3-RV-20260907
title: XTI/XNG three-week relative-sign alternation reversion
publisher: QuantMechanica governed extraction from U.S. EIA and peer-reviewed research
source_type: governed_composite_source
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission directive 2026-09-07
created: 2026-09-07
created_by: Research+Development
uri: https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf
cards_extracted:
  - xtixng-walt3-rv
---

# XTI/XNG Three-Week Relative-Sign Alternation Reversion

## Approval And Complete-Read Scope

The current OWNER mission authorizes one reputable-source, structural,
low-frequency commodity/energy card, branch-only build, and paced Q02 enqueue.
Before this extraction, the complete governed packets
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md` and
`strategy-seeds/sources/FMR-MOMTS-2010/source.md` were read. Those packets
preserve complete-read evidence for the underlying U.S. EIA report and two
peer-reviewed papers, including adverse evidence about the weak and unstable
oil/gas relationship.

This extraction is bounded to one transparent price-native state: three
adjacent completed-week XTI-minus-XNG relative log returns whose signs strictly
alternate. It does not transfer a source result or claim that alternation is a
documented anomaly.

## Primary Citations

1. Villar, Jose A., and Frederick L. Joutz (2006), "The Relationship Between
   Crude Oil and Natural Gas Prices," U.S. Energy Information Administration,
   43 pages. Complete report:
   https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf
2. Ramberg, David J., and John E. Parsons (2012), "The Weak Tie Between Natural
   Gas and Oil Prices," *The Energy Journal* 33(2), 13-35, DOI
   https://doi.org/10.5547/01956574.33.2.2.
3. Fuertes, Ana-Maria, Joelle Miffre, and Georgios Rallis (2010), "Tactical
   Allocation in Commodity Futures Markets: Combining Momentum and Term
   Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
   https://doi.org/10.1016/j.jbankfin.2010.04.009.

## Source Boundary And Adverse Evidence

Villar and Joutz describe physical and economic links between oil and gas but
also temporary decoupling and model-instability risk. Ramberg and Parsons find
that the oil/gas relationship is weak, time varying, and leaves most gas-price
variation unexplained. Fuertes, Miffre, and Rallis provide reputable commodity
relative-return lineage, not this two-CFD weekly reversal rule.

The sources do not specify three weekly relative returns, strict sign
alternation, contrarian direction, a one-week hold, ATR stops, or equal-notional
CFD legs. Those are an explicitly unproven QM translation. Equal notional is a
construction intent, not proof of beta, volatility, dollar, factor, or
portfolio neutrality.

## Bounded Mechanization

At the first tradable D1 bar of a new broker week, reconstruct exactly four
consecutive synchronized completed-week endpoints from XTIUSD.DWX and
XNGUSD.DWX. Each completed week must contain three to five synchronized
sessions. In oldest-to-newest order compute:

`d[i] = log(XTI[i+1]/XTI[i]) - log(XNG[i+1]/XNG[i])`, for `i=0..2`.

All three differences must be finite and have absolute magnitude above
`1e-10`. Open only for strict alternation:

- `d0 > 0, d1 < 0, d2 > 0`: sell XTI and buy XNG;
- `d0 < 0, d1 > 0, d2 < 0`: buy XTI and sell XNG.

Thus the package fades the newest relative winner. Split one aggregate fixed
risk budget across equal-absolute-notional opposed legs, use independent
`3.5 * ATR(20,D1)` hard stops, and close both legs at the next broker-week
boundary. A durable attempt is consumed before fallible gates; malformed or
orphaned exposure is flattened atomically.

## Non-Duplicate Boundary

The deterministic checker covered 4,853 EA-registry rows and 1,466 repository
cards, found no exact identity, and returned expected fuzzy oil/gas siblings.
Manual review separates the closest cases:

- `QM5_41358` uses two opposite-sign weeks and requires the newest magnitude
  to be larger; this rule requires three alternating signs and ignores
  magnitude after the epsilon test.
- `QM5_41359` and `QM5_41360` use two returns plus acceleration/retracement
  magnitude inequalities; this rule has no magnitude comparison.
- `QM5_41361` uses one common-direction week and individual outright-return
  signs; this rule uses three XTI-minus-XNG relative-return signs.
- `QM5_41368` uses two weeks of same-sign individual leg returns and a relative
  leader switch; this rule does not require common outright direction.
- `QM5_41372` compares overlapping three-week majority votes across four
  relative returns and follows the new majority; this rule requires exactly
  three alternating returns and fades the newest sign.
- `QM5_41078` is a three-week same-sign XAU/XAG streak fade; both carrier and
  state differ because this rule requires strict alternation on energy legs.

The unavailable external Strategy Wiki root is retained as an explicit dedup
coverage limitation. Verdict:
`DISTINCT_XTIXNG_THREE_WEEK_STRICT_RELATIVE_SIGN_ALTERNATION_NEWEST_WINNER_FADE`.

## R1-R4

- R1: `PASS_WITH_ALTERNATION_TRANSLATION_RISK`. Government and peer-reviewed
  sources are reputable and their adverse evidence is preserved.
- R2: `PASS`. Clock, endpoints, synchronization, strict signs, side, attempt,
  risk, stops, atomic repair, and one-week lifecycle are fixed.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`. Registered
  native XTI/XNG D1 history and broker metadata supply all runtime inputs.
- R4: `PASS`. Deterministic arithmetic only; no ML, external runtime feed,
  banned indicator, grid, martingale, pyramid, or adaptive PnL fit.

## Safety And Falsification Boundary

Q02 must retire the card on zero packages, fewer than five completed paired
packages in any full post-warm-up year, or nonpositive governed economics. No
carrier, sign pattern, direction, risk, stop, or lifecycle change is authorized
after results. This source approval excludes manual testing, optimization,
portfolio admission, correlation waivers, deployment, live manifests,
`T_Live`, AutoTrading, and live use.
