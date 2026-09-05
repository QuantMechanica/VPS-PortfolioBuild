---
source_id: AI-CODEX-XAUXAG-MWINSOR2-RV-20260905
title: XAU/XAG monthly fixed-tail Winsorized ratio-return reversion
publisher: QuantMechanica governed synthesis of peer-reviewed and exchange sources
source_type: governed_composite_source
status: approved_source_complete
approval_basis: decisions/2026-09-05_xauxag_monthly_winsor2_reversion_source_approval.md
created: 2026-09-05
created_by: Research+Development
parent_sources:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WTI-WINSOR-2026
cards_extracted:
  - xauxag-mwinsor2-rv
---

# XAU/XAG Monthly Fixed-Tail Winsorized Reversion Source Packet

## Approved Evidence

This bounded packet binds three complete governed repository sources:

1. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`. Complete-read packet:
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`.
2. CME Group, "Gold & Silver Ratio Spread." Governed exchange packet:
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`.
3. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, plus the approved exact Winsor arithmetic
   packet `strategy-seeds/sources/MOP-WTI-WINSOR-2026/source.md`.

Schweikert supports a state-dependent gold/silver relationship, not a stable
constant equilibrium. CME defines the ratio and opposed-leg spread. The
third packet fixes sorting and two-per-tail replacement arithmetic. None
tests this XAU/XAG conjunction, its contrarian direction, CFD carrier, costs,
or portfolio correlation.

## Bounded QM Hypothesis

At the first synchronized D1 bar of each broker month, reconstruct thirteen
consecutive synchronized completed XAU/XAG month-end ratios and form twelve
chronological adjacent log-ratio returns. Sort the returns, replace the two
lowest values by the third order statistic and the two highest values by the
tenth order statistic, average all twelve capped values, and fade the sign
with an equal-target-notional opposed-leg package until the next month.

For positive synchronized closes `G[0..12]`, `S[0..12]`, oldest first:

```text
q[i] = ln(G[i] / S[i])
r[i] = q[i+1] - q[i], i=0..11
s = sort_ascending(r)
winsor_mean = (3*s[2] + sum(s[3..8]) + 3*s[9]) / 12

LONG RATIO  when winsor_mean < -1e-12: buy XAU, sell XAG
SHORT RATIO when winsor_mean > +1e-12: sell XAU, buy XAG
FLAT otherwise or on invalid arithmetic
```

The twelve intervals, ascending sort, boundary indexes `2` and `9`, threefold
boundary weights, middle indexes `3..8`, divisor twelve, epsilon, and
contrarian direction are locked. Magnitude never scales risk.

## Non-Duplicate Boundary

The corrected-root receipt
`artifacts/qm5_xauxag_mwinsor2_rv_preallocation_dedup_20260905.json` scanned
4,836 registry rows, 1,449 cards, and 45 Wiki nodes. It found no exact identity
and returned eight expected fuzzy family matches.

Manual review separates this estimator from absolute-ratio z-scores,
regression residuals, distribution-shift tests, the fixed-trim sibling
`QM5_41355`, and the iterative Hampel/bisquare siblings `QM5_41348` and
`QM5_41341`. Winsorization retains twelve observations after capping four;
trimming deletes four and gives the remaining eight equal weight. Hampel and
bisquare iteratively recompute residual weights.

For the fixed vector
`[.063,-.073,.043,.006,-.080,.085,.014,.004,-.033,-.068,.030,.029]`,
the middle-eight trimmed mean is `+0.003125` and sells the ratio, while the
two-per-tail Winsorized mean is `-0.002083333333` and buys it. This two-way
signal disagreement is load-bearing.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XAUXAG_MONTHLY_RATIO_RETURN_FIXED_TWO_PER_TAIL_WINSORIZED_MEAN_CONTRARIAN_BASKET`.
This is an identity verdict, not a performance or correlation claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_RISK`: peer-reviewed relationship evidence,
  exchange-defined spread construction, and a complete governed arithmetic
  lineage; no efficacy claim transfers.
- R2 `PASS`: symbols, synchronization, endpoints, sort, replacement, side,
  monthly attempt, aggregate fixed risk, stops, and lifecycle are exact.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XAUUSD.DWX and
  XAGUSD.DWX D1 histories supply every runtime market input.
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
