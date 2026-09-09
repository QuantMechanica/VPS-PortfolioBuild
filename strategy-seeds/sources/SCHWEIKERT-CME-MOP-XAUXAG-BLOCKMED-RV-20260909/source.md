---
source_id: SCHWEIKERT-CME-MOP-XAUXAG-BLOCKMED-RV-20260909
title: XAU/XAG monthly chronological block-median ratio reversion
publisher: QuantMechanica governed synthesis of peer-reviewed and exchange sources
source_type: governed_composite_source
status: approved_source_complete
approval_basis: decisions/2026-09-09_xauxag_monthly_block_median_reversion_source_approval.md
created: 2026-09-09
created_by: Research+Development
parent_sources:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-TSMOM-2012
  - MOP-WTI-BLOCKMED-2026
cards_extracted:
  - xauxag-blockmed-rv
---

# XAU/XAG Monthly Chronological Block-Median Reversion Source Packet

## Approved Evidence

This packet binds four completely read governed repository sources:

1. Karsten Schweikert (2018), "Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions," *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`; governed packet
   `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`.
2. CME Group, "Gold & Silver Ratio Spread"; governed exchange packet
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`.
3. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`; complete-paper packet
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` with published-PDF SHA-256
   `7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.
4. The approved transparent block arithmetic extraction
   `strategy-seeds/sources/MOP-WTI-BLOCKMED-2026/source.md`.

Schweikert supports testing a state-dependent gold/silver relationship but
warns against assuming one constant equilibrium. CME defines gold price
divided by silver price and its opposed-leg spread construction. The MOP
records provide only the monthly horizon and exact robust block arithmetic;
they do not supply a gold/silver reversion result. No source tests this exact
conjunction, Darwinex CFDs, costs, risk controls, or book correlation.

## Bounded QM Hypothesis

At the first synchronized D1 bar of each broker month, reconstruct thirteen
consecutive synchronized completed XAU/XAG month-end ratios and form twelve
chronological adjacent log-ratio changes. Partition them into four fixed
non-overlapping blocks of three, take each block's arithmetic mean, sort only
the four means, and average the two inner values. Fade the resulting sign with
an equal-target-notional opposed-leg package until the next month.

For positive synchronized closes `G[0..12]`, `S[0..12]`, oldest first:

```text
q[i] = ln(G[i] / S[i])
r[i] = q[i+1] - q[i], i=0..11
b[j] = (r[3j] + r[3j+1] + r[3j+2]) / 3, j=0..3
s = sort_ascending(b)
m = (s[1] + s[2]) / 2

LONG RATIO  when m < -1e-12: buy XAU, sell XAG
SHORT RATIO when m > +1e-12: sell XAU, buy XAG
FLAT otherwise or on invalid arithmetic
```

All endpoint, block, divisor, sort, median-index, epsilon, and side choices are
locked. Magnitude never scales risk. The contrarian sign is a falsifiable QM
translation of the relationship evidence, not a source efficacy claim.

## Non-Duplicate Boundary

Exact repository searches found no prior XAU/XAG chronological block-median
identity. `QM5_20287` follows this estimator on outright WTI; this candidate
instead computes synchronized gold-minus-silver ratio changes and fades them
through two opposed legs. Existing XAU/XAG systems use absolute-ratio scores,
OLS residuals, raw or robust centers, rank/distribution tests, sign votes,
tail trim, Winsorization, iterative M-estimation, or calendar states. None
sorts four fixed chronological three-change means and fades their even median.

The fixed vector
`[.09,.06,.03,-.03,-.03,-.03,.03,.03,.03,-.09,-.06,-.03]`
has block means `[+.06,-.03,+.03,-.06]`, so its even block median is zero and
the candidate stays flat, while the raw twelve-change mean is zero for a
different functional reason. A second vector
`[.12,.09,.06,-.03,-.03,-.03,.02,.02,.02,-.08,-.07,-.06]`
has raw mean `+0.0025` but inner block means `-0.03` and `+0.02`, producing
`m=-0.005`; the block candidate buys the ratio while raw-mean reversion sells.

Verdict:
`DISTINCT_XAUXAG_MONTHLY_FOUR_BY_THREE_CHRONOLOGICAL_BLOCK_MEDIAN_RATIO_REVERSION`.
This is an identity verdict, not performance or decorrelation evidence.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_RISK`: named peer-reviewed relationship and horizon
  sources, an exchange spread source, complete-read evidence, and transparent
  estimator provenance; no efficacy transfers.
- R2 `PASS`: exact synchronization, endpoints, block membership, arithmetic,
  side, attempt, aggregate risk, stops, atomicity, and lifecycle.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XAUUSD.DWX and
  XAGUSD.DWX D1 histories supply every market input.
- R4 `PASS`: timestamps, logarithms, sorting, arithmetic, ATR, quotes,
  positions, deals, and persistent terminal state only; no trained or external
  runtime input.

## Kill And Safety Boundary

Q02 retires below five completed logical packages in any full post-warm-up
year or on nonpositive governed economics. Downstream gates alone own
robustness and realized correlation. No result may be rescued by changing
horizon, blocks, direction, carrier, stop, hold, risk, or retry behavior.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, Q01, and one paced Q02 enqueue below the
CPU ceiling. No optimization, manual tester launch, portfolio-gate edit,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live use
is authorized.

