---
source_id: AI-CODEX-XTIXNG-MWINSOR2-RV-20260906
title: XTI/XNG monthly fixed-tail Winsorized ratio-return reversion
publisher: QuantMechanica governed synthesis of government and peer-reviewed sources
source_type: governed_composite_source
status: approved_source_complete
approval_basis: decisions/2026-09-06_xtixng_monthly_winsor2_reversion_source_approval.md
created: 2026-09-06
created_by: Research+Development
parent_sources:
  - VILLAR-RAMBERG-OILGAS-2026
  - MOP-WTI-WINSOR-2026
cards_extracted:
  - xtixng-mwinsor2-rv
---

# XTI/XNG Monthly Fixed-Tail Winsorized Reversion Source Packet

## Approved Evidence

This bounded packet binds two complete governed repository sources:

1. Villar and Joutz (2006), *The Relationship Between Crude Oil and Natural
   Gas Prices*, U.S. Energy Information Administration, and Ramberg and
   Parsons (2012), "The Weak Tie Between Natural Gas and Oil Prices," *The
   Energy Journal* 33(2), 13-35, DOI `10.5547/01956574.33.2.2`. Complete-read
   packet: `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`.
2. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, plus the approved exact Winsor arithmetic
   packet `strategy-seeds/sources/MOP-WTI-WINSOR-2026/source.md`.

Villar/Joutz and Ramberg/Parsons document physical and economic oil/gas links
through substitution, co-production, drilling, finance, transport, and LNG,
while making instability and gas-specific variation binding adverse evidence.
They do not justify a permanently fixed oil/gas ratio. The second packet fixes
sorting and two-per-tail replacement arithmetic only. None tests this XTI/XNG
conjunction, its contrarian direction, continuous-CFD carrier, costs, equal-
notional construction, or portfolio correlation.

## Bounded QM Hypothesis

At the first synchronized D1 bar of each broker month, reconstruct thirteen
consecutive synchronized completed XTI/XNG month-end ratios and form twelve
chronological adjacent log-ratio returns. Sort the returns, replace the two
lowest values by the third order statistic and the two highest values by the
tenth order statistic, average all twelve capped values, and fade the sign
with an equal-target-notional opposed-leg package until the next month.

For positive synchronized closes `O[0..12]`, `G[0..12]`, oldest first:

```text
q[i] = ln(O[i] / G[i])
r[i] = q[i+1] - q[i], i=0..11
s = sort_ascending(r)
winsor_mean = (3*s[2] + sum(s[3..8]) + 3*s[9]) / 12

LONG RATIO  when winsor_mean < -1e-12: buy XTI, sell XNG
SHORT RATIO when winsor_mean > +1e-12: sell XTI, buy XNG
FLAT otherwise or on invalid arithmetic
```

The twelve intervals, ascending sort, boundary indexes `2` and `9`, threefold
boundary weights, middle indexes `3..8`, divisor twelve, epsilon, and
contrarian direction are locked. Magnitude never scales risk.

## Non-Duplicate Boundary

The corrected-root receipt
`artifacts/qm5_xtixng_mwinsor2_rv_preallocation_dedup_20260906.json` scanned
4,837 registry rows, 1,450 cards, and 45 Wiki nodes. It found no exact identity
and surfaced nine expected fuzzy family signals (the JSON retains the top
five).

Manual review separates the complete economic identity from its closest
families:

- `QM5_41356_xauxag-mwinsor2-rv` shares exact estimator arithmetic but owns a
  precious-metals carrier. This card owns an oil/gas path, its weak and
  state-dependent energy linkage, XTI/XNG contract metadata, and energy spread
  costs. It is the new energy exposure requested by the OWNER, not an added
  outright-metal sleeve.
- `QM5_41192_xtixng-mdaily-hl-rv` uses 17-23 daily relative returns from one
  completed month and all inclusive pairwise averages. This card uses twelve
  disjoint completed-month relative returns spanning a year and fixed order-
  statistic capping.
- `QM5_41340_wti-xng-divtrend` orders one WTI leg in its own annual trend only
  when read-only XNG has the opposite annual sign. This card always expresses
  the robust oil/gas relative state through two opposed legs and fades rather
  than follows it.
- XTI/XNG slope, rank, change-point, regression, weekday, and calendar baskets
  consume different state objects and estimators. The XAU/XAG trim, Hampel,
  and bisquare siblings are different carriers and also delete tails or
  iteratively recompute residual weights.

Winsorization retains twelve observations after capping four; the nearest
trim deletes four and gives the remaining eight equal weight.

For the fixed vector
`[.063,-.073,.043,.006,-.080,.085,.014,.004,-.033,-.068,.030,.029]`,
the middle-eight trimmed mean is `+0.003125` and sells the ratio, while the
two-per-tail Winsorized mean is `-0.002083333333` and buys it. This two-way
signal disagreement is load-bearing.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XTIXNG_MONTHLY_RATIO_RETURN_FIXED_TWO_PER_TAIL_WINSORIZED_MEAN_CONTRARIAN_BASKET`.
This is an identity verdict, not a performance or correlation claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_RISK`: complete U.S. government and peer-reviewed
  oil/gas relationship evidence, including adverse instability, plus a
  complete governed arithmetic lineage; no efficacy claim transfers.
- R2 `PASS`: symbols, synchronization, endpoints, sort, replacement, side,
  monthly attempt, aggregate fixed risk, stops, and lifecycle are exact.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX and
  XNGUSD.DWX D1 histories supply every runtime market input.
- R4 `PASS`: timestamps, logarithms, sorting, arithmetic, ATR, quotes,
  positions, deals, and persistent state only; no trained or external input.

## Kill And Safety Boundary

Q02 retires the edge below five completed logical packages in any full
post-warm-up year or on nonpositive governed economics. Downstream gates alone
own robustness and realized book correlation. No failure may be rescued by
changing horizon, boundary count, direction, carrier, risk, stops, or retry.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced Q02 enqueue below
the CPU ceiling. No optimization, manual tester launch, portfolio-gate edit,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live use
is authorized.
