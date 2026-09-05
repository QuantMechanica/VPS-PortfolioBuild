---
source_id: AI-CODEX-XAUXAG-MTRIM2-RV-20260905
title: XAU/XAG monthly fixed-trim ratio-return reversion
publisher: QuantMechanica governed synthesis of peer-reviewed and exchange sources
source_type: governed_composite_source
status: approved_source_complete
approval_basis: decisions/2026-09-05_xauxag_monthly_trim2_reversion_source_approval.md
created: 2026-09-05
created_by: Research+Development
parent_sources:
  - SCHWEIKERT-XAUXAG-RATIO-2026
  - CME-GSR-SPREAD-2025
  - MOP-WTI-TRIMMEAN-2026
cards_extracted:
  - xauxag-mtrim2-rv
---

# XAU/XAG Monthly Fixed-Trim Reversion Source Packet

## Approved evidence

This packet binds three complete, already governed repository sources:

1. Karsten Schweikert (2018), “Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions,” *Journal of Banking & Finance*
   88, 44–51, DOI `10.1016/j.jbankfin.2017.11.010`. The complete-read packet
   is `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
2. CME Group, “Gold & Silver Ratio Spread.” The governed exchange packet is
   `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
3. Moskowitz, Ooi, and Pedersen (2012), “Time Series Momentum,” *Journal of
   Financial Economics* 104(2), 228–250, DOI
   `10.1016/j.jfineco.2011.11.003`, and its governed fixed-trim arithmetic
   packet `strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md`, SHA-256
   `63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8`.

Schweikert supplies evidence for a state-dependent gold/silver relationship,
not a universal constant equilibrium. CME defines the price ratio and
opposed-leg spread. The third packet fixes transparent sorting and trimmed
location arithmetic. None tests the conjunction below.

Fresh attempts to retrieve the publisher, exchange, and NIST pages through
the approved public-source router returned `DEFERRED:SOURCE_POLICY`. The
reproducible classifications are retained in `retrieval_route_20260905.json`;
no proxy or alternate scraper was used.

## Bounded QM hypothesis

On the first synchronized D1 bar of each broker month, reconstruct thirteen
consecutive synchronized completed XAU/XAG month-end ratios and form twelve
chronological adjacent log-ratio returns. Sort those returns, discard exactly
two observations from each tail, and average the middle eight. Fade the sign
of that robust location with equal-target-notional opposed legs until the next
month.

For positive synchronized closes `G[0..12]` and `S[0..12]`, oldest first:

```text
q[i] = ln(G[i] / S[i])
r[i] = q[i+1] - q[i], i=0..11
s = sort_ascending(r)
trimmed_mean = sum(s[2..9]) / 8

LONG RATIO  when trimmed_mean < -1e-12: buy XAU, sell XAG
SHORT RATIO when trimmed_mean > +1e-12: sell XAU, buy XAG
FLAT otherwise or on invalid arithmetic
```

The twelve intervals, ascending sort, deleted indexes `0,1,10,11`, retained
indexes `2..9`, divisor eight, epsilon, and contrarian direction are locked.
The estimator magnitude never changes risk. The direction is an explicit QM
reversion hypothesis; no parent source supplies performance for it.

## Identity boundary

The corrected-root deterministic receipt
`artifacts/qm5_xauxag_mtrim2_rv_preallocation_dedup_20260905.json` scanned
4,835 registry rows, 1,448 cards, and 45 Wiki nodes. It found no exact identity
and returned eight expected fuzzy family matches.

Manual review separates this candidate from absolute ratio z-score reversion,
rolling OLS/CADF residuals, old-versus-recent distribution tests, one-shot MAD
tails, and the nearest robust-location baskets `QM5_41341` and `QM5_41348`.
The new functional deletes four observations and gives the retained eight
equal weights; bisquare uses smooth residual weights, while Hampel uses
piecewise `2/4/8` weights and iterative recentering.

On the fixed return vector
`[-.044,.041,-.039,.061,.052,-.067,-.021,.018,.051,-.038,.041,-.074]`,
the proposed middle-eight mean is `+0.001125` and sells the ratio; Hampel is
`-0.001583333333` and bisquare is `-0.001289357091`, so both nearest neighbors
buy. This decision disagreement is load-bearing.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_DISTINCT_XAUXAG_MONTHLY_RATIO_RETURN_FIXED_TWO_PER_TAIL_TRIMMED_MEAN_CONTRARIAN_BASKET`.
This is an identity verdict, not a performance or correlation claim.

## Reputable-source criteria

- R1 `PASS_WITH_SYNTHESIS_RISK`: peer-reviewed gold/silver relationship,
  exchange-defined spread, complete governed statistical lineage, immutable
  hashes, adverse evidence, and no transferred performance claim.
- R2 `PASS`: symbols, synchronization, endpoints, sorting, exact trim, side,
  attempt, aggregate fixed risk, stops, and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XAUUSD.DWX and
  XAGUSD.DWX D1 histories supply all runtime market inputs.
- R4 `PASS`: deterministic timestamp, logarithm, sorting, arithmetic, ATR,
  quote, position, and deal state only; no trained signal, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Kill and safety boundary

Q02 retires the edge below five completed logical packages in any full
post-warm-up year or on nonpositive governed economics. Downstream gates alone
own robustness and realized book correlation. No failure may be rescued by
changing horizon, trim, direction, carrier, risk, stops, or retry behavior.

Authorized scope is one card, deterministic allocation, one branch-only
non-live V5 build, reference tests, strict Q01, and one paced Q02 enqueue below
the CPU ceiling. No manual backtest, optimization, portfolio-gate edit,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, or live use
is authorized.
