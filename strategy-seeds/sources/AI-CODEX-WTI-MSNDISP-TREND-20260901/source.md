---
source_id: AI-CODEX-WTI-MSNDISP-TREND-20260901
title: WTI completed-month Sn-core dispersion-normalized trend continuation
publisher: QuantMechanica governed synthesis from complete-read peer-reviewed WTI and robust-scale research
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_sn_dispersion_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - ROUSSEEUW-CROUX-SN-1993
  - CRAN-ROBUSTBASE-SN-0.99-7
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  ROUSSEEUW-CROUX-SN-1993: F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969
  CRAN-ROBUSTBASE-SN-R: 4641E153ABC9033F7073C57D4E8AD254A1D4DF9C1C79CA864C8B51A0922737DD
  CRAN-ROBUSTBASE-SN-C: 795011650A3E0BA023C21CBAA7F35854ECA4A1918D277A7A344A772D317E1192
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41277_wti-msndisp-tr
---

# WTI Completed-Month Sn-Core Dispersion-Normalized Trend

## Approval And Complete Read

The durable approval predates this extraction:
`decisions/2026-09-01_wti_monthly_sn_dispersion_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one
reputable-source structural low-frequency sleeve and names direct WTI trend
or seasonality as eligible. Scope is one card, one branch build, strict Q01,
and one CPU-admitted non-live Q02 enqueue.

The complete trading-evidence read is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
It preserves a complete read of Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, including monthly own-return continuation,
the source-declared one-month formation/one-month hold commodity portfolio,
and explicit NYMEX WTI membership.

The complete method read is Rousseeuw and Croux (1993), *Alternatives to the
Median Absolute Deviation*, *Journal of the American Statistical Association*
88(424), 1273-1283, DOI `10.1080/01621459.1993.10476408`. The author-hosted
eleven-page published PDF has SHA-256
`F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969`.
The commit-pinned arithmetic cross-check is CRAN `robustbase` `0.99-7`,
commit `54c5cc98e27050a78bbd03be15f07a7ba88de62a`; both `R/qnsn.R` and
`src/qn_sn.c` were read completely. Retrieval receipts are beside this file.

No snippet, external runtime source, inferred result, trained output, or
unpublished performance number enters the hypothesis.

## Source-Defined Findings

Moskowitz, Ooi, and Pedersen document monthly own-return continuation across
liquid futures, include NYMEX WTI in the commodity universe, and explicitly
report a pooled commodity `k=1`, `h=1` rule. Their result is not a WTI-only
continuous-CFD result and does not define this daily-return dispersion gate.

Rousseeuw and Croux define Sn as a nested median of pairwise absolute
distances and separate the raw functional from the `1.1926` consistency
multiplier. The pinned primary software makes the even-sample convention
executable:

```text
S*_n = LOMED_i HIMED_j |x_i-x_j|
     = LOMED_i LOMED_{j!=i} |x_i-x_j|
```

For `n=16`, each leave-one-out sample has fifteen distances, so its lower
median is its eighth one-based order statistic. The outer lower median of
sixteen inner values is also its eighth one-based order statistic. The paper
and software study robust scale estimation; neither says that WTI displacement
divided by raw Sn predicts future returns.

## Bounded Trading Hypothesis

At each genuine broker-month transition:

```text
M = every chronological completed D1 close in the immediately prior month
require 17 <= len(M) <= 23
C[0..16] = final seventeen chronological closes in M

r[i] = ln(C[i+1] / C[i]), i=0..15
net  = sum(r)
require abs(net - ln(C[16]/C[0])) <= 1e-10

for i=0..15:
    D_i = sort(abs(r[i]-r[j]) for j=0..15, j!=i)
    require len(D_i) == 15
    inner[i] = D_i[7]          # eighth one-based, lower median

I = sort(inner)
sn_core = I[7]                 # eighth one-based outer lower median
require sn_core > 1e-12

BUY  iff net >=  3*sn_core
SELL iff net <= -3*sn_core
FLAT otherwise
```

The rule deliberately omits the `1.1926` consistency factor and every finite
sample multiplier. It makes no scale-consistency, p-value, independence, or
significance claim. The factor three and the trading conjunction are
transparent pre-result QM choices.

Consume the month before history, signal, news, spread, quote, ATR, sizing,
margin, or order gates. Use a frozen `3.5*ATR(20,D1)` hard stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a 1,500-point
spread ceiling, next-month close, and forty-day stale repair.

## Exact Support And Claim Boundary

Sixteen returns generate sixteen leave-one-out arrays of exactly fifteen
distances. `D_i[7]` and `I[7]` are the fixed zero-based implementation indices.
Sorting is deterministic and neither `1.1926` nor a finite-sample correction
may silently enter the EA.

The market-free activity ceiling is twelve states per year. An ordering prior
of six to eight completed positions per full year is not a WTI probability or
performance forecast. Q02 must retire fewer than five positions in any full
post-warm-up year.

## Reputable-Source Criteria

- R1: `PASS_WITH_SN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK`.
  The carrier and broad monthly continuation premise have a complete-read
  peer-reviewed paper with DOI and durable hash. The Sn functional has a
  separate complete-read peer-reviewed paper and commit-pinned primary
  software. Every trading translation is disclosed.
- R2: `PASS`. Month clock, sessions, final-seventeen selection, returns,
  endpoint identity, 16x15 distances, inner and outer lower medians, omitted
  multipliers, inclusive three-core direction, attempt, risk, stop, spread,
  and lifecycle are deterministic and frozen before testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and MT5-native state provide every runtime input. Continuous-CFD
  roll, basis, financing, gaps, and broker-month labels remain risks.
- R4: `PASS`. Only timestamps, completed prices, logarithms, sorting,
  comparisons, ATR risk controls, quotes, positions, deals, and persistent
  state are used. There is no trained signal, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_msndisp_tr_preallocation_dedup_20260901.json`, SHA-256
`74C0023E963CD3105658E09BBFE64168DABE211FC00B82934C37D17B42F40CE5`,
checked 4,776 registry rows, 1,412 cards, and 45 Strategy Wiki nodes. It found
no exact identity and one expected fuzzy neighbor, `QM5_41275`.

Manual fixed-vector review resolves the fuzzy result in both directions:

- vector A has `net=.017079`, `sn_core=.005549`, and `q_core=.004351`; it
  buys here while Qn, L1 path efficiency, and RMS coherence stay flat;
- vector B has `net=.018770`, `sn_core=.006399`, and `q_core=.004317`; it
  stays flat here while Qn, L1, and RMS buy.

The full vectors and ratios are locked in the source approval and reference
tests. Old/recent scale-state cards compare two monthly-return groups; this
rule uses one completed month's daily-return distribution. The endpoint-only
WTI rule has no dispersion gate. Certified `QM5_12567` is a short-horizon
long-only XNG pullback.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL17_RETURN_SN_NESTED_MEDIAN_DISPERSION_NORMALIZED_CONTINUATION`.

## Failure And Extraction Boundaries

- Retire on zero positions or fewer than five completed positions in any full
  post-warm-up calendar year.
- Retire on nonpositive governed economics, deterministic-reference mismatch,
  malformed lifecycle behavior, or any downstream gate failure.
- No result-driven change to sample, median convention, core threshold, side,
  stop, spread, or hold is authorized after Q02.
- Q09 alone can establish realized decorrelation. WTI carrier identity is not
  a correlation result.
- No source claims this conjunction, its activity, WTI-only profitability,
  continuous-CFD equivalence, fixed-risk economics, or portfolio admission.

Exactly one card may be extracted from this source. The approved scope ends
after branch build, deterministic reference tests, strict Q01, and one
CPU-admitted non-live Q02 enqueue. It excludes optimization,
live/demo/shadow/stress presets, portfolio-gate changes, deploy/live manifests,
`T_Live`, and AutoTrading.
