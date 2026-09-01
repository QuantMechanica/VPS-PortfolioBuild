---
source_id: AI-CODEX-WTI-MQNDISP-TREND-20260901
title: WTI completed-month Qn-core dispersion-normalized trend continuation
publisher: QuantMechanica governed synthesis from complete-read peer-reviewed WTI and robust-scale research
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_qn_dispersion_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - ROUSSEEUW-CROUX-QN-1993
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  ROUSSEEUW-CROUX-QN-1993: F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41275_wti-mqndisp-tr
---

# WTI Completed-Month Qn-Core Dispersion-Normalized Trend

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_qn_dispersion_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one
reputable-source, structural low-frequency sleeve and explicitly identifies a
direct WTI trend or seasonality edge as eligible. This packet is bounded to
one card, one branch build, strict Q01, and one paced non-live Q02 enqueue.

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
88(424), 1273-1283, DOI `10.1080/01621459.1993.10476408`. All eleven pages of
the author-hosted published PDF were read. PDF SHA-256:
`F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969`.
The bounded retrieval receipt is
`retrieval_route_rousseeuw_croux_qn_20260901.json`.

No snippet, external runtime source, inferred result, trained output, or
unpublished performance number enters the hypothesis.

## Source-Defined Findings

Moskowitz, Ooi, and Pedersen document monthly own-return continuation across
liquid futures, include NYMEX WTI in the commodity universe, and explicitly
report a pooled commodity `k=1`, `h=1` rule. Their result is not a WTI-only
continuous-CFD result and does not define the QM daily-return dispersion gate.

Rousseeuw and Croux define Qn from pairwise absolute distances. For sample
size `n`, `h=floor(n/2)+1` and `k=C(h,2)` select the kth order statistic among
all `C(n,2)` distances. A multiplier can make the statistic consistent for a
chosen model scale. The paper studies robustness and efficiency; it does not
define a trading signal or say that return displacement divided by Qn predicts
future returns.

## Bounded Trading Hypothesis

At each broker-month transition:

```text
M = every chronological completed D1 close in the immediately prior month
require 17 <= len(M) <= 23
C[0..16] = final seventeen chronological closes in M
require every C finite and positive

r[i] = ln(C[i+1] / C[i]), i=0..15
net  = sum(r)
require abs(net - ln(C[16]/C[0])) <= 1e-10

D = sorted(abs(r[j]-r[i]) for 0<=i<j<=15)
require len(D) == 120
q_core = D[35]                   # 36th one-based order statistic
require q_core > 1e-12

BUY  iff net >=  4*q_core
SELL iff net <= -4*q_core
FLAT otherwise
```

The `n=16`, `h=9`, `k=36` order-statistic index comes from the Qn method.
This rule deliberately omits the paper's distribution-specific consistency
factor and makes no scale-consistency, p-value, independence, or significance
claim. The fixed factor four and the trading conjunction are transparent QM
choices.

Consume the month before history, signal, news, spread, quote, ATR, sizing,
margin, or order gates. Use a frozen `3.5*ATR(20,D1)` hard stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a 1,500-point
spread ceiling, next-month close, and forty-day stale repair.

## Exact Support And Claim Boundary

Sixteen returns generate exactly `C(16,2)=120` distances. For `n=16`, the Qn
source construction gives `h=floor(16/2)+1=9` and `k=C(9,2)=36`; therefore
`D[35]` is the exact zero-based implementation index. Sorting is deterministic
and no consistency factor can silently enter the EA.

The market-free activity ceiling is twelve states per year. An ordering prior
of seven to nine completed positions per full year is not a WTI probability
or performance forecast. Q02 must retire fewer than five positions in any
full post-warm-up year.

## Reputable-Source Criteria

- R1: `PASS_WITH_QN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK`.
  The carrier and broad monthly continuation premise have a complete-read
  peer-reviewed paper with DOI and durable hash. The Qn order statistic has a
  separate complete-read peer-reviewed paper with DOI and durable PDF hash.
  Every trading translation and the absence of a WTI-only result are
  disclosed.
- R2: `PASS`. Month clock, sessions, final-seventeen selection, returns,
  endpoint identity, all 120 distances, 36th order statistic, no multiplier,
  inclusive four-core direction, attempt, risk, stop, spread, and lifecycle
  are deterministic and frozen before testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and MT5-native state provide every runtime input. Continuous-CFD
  roll, basis, financing, gaps, and broker-month labels remain risks.
- R4: `PASS`. Only timestamps, completed prices, logarithms, sorting,
  comparisons, ATR risk controls, quotes, positions, deals, and persistent
  state are used. There is no trained signal, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_mqndisp_tr_preallocation_dedup_20260901.json`, SHA-256
`831C20BF85E9B38C85F29D71F15D22422BD24BD10F3A9C40223DDBCA6AEC066D`,
checked 4,774 registry rows, 1,410 cards, and 45 Strategy Wiki nodes. It found
no exact or fuzzy identity.

Manual review separates the substantive neighbors:

- `QM5_41126` divides net by the L1 path; `QM5_41124` divides a daily mean by
  an RMS path. This packet selects the 36th of 120 pairwise return distances.
  The two fixed vectors and exact disagreement metrics are recorded in the
  approval decision.
- `QM5_41250` compares two six-month MAD states through 924 permutations.
  This packet uses one completed month's daily returns and no permutations.
- `QM5_41261`, `41266`, `41267`, and `41271` compare monthly-return scale
  states. This packet normalizes a within-month net displacement by one raw
  Qn core.
- `QM5_20187` has only an endpoint sign and can enter when this packet is
  flat.
- `QM5_12567` is a short-horizon XNG long-only pullback.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL17_RETURN_QN_CORE_DISPERSION_NORMALIZED_CONTINUATION`.

## Failure And Extraction Boundaries

- Retire on zero positions or fewer than five completed positions in any full
  post-warm-up calendar year.
- Retire on nonpositive governed economics, deterministic-reference mismatch,
  malformed lifecycle behavior, or any downstream gate failure.
- No result-driven change to sample, order statistic, core threshold, side,
  stop, spread, or hold is authorized after Q02.
- Q09 alone can establish realized decorrelation. WTI carrier identity is not
  a correlation result.
- No source claims this conjunction, its activity, WTI-only profitability,
  continuous-CFD equivalence, fixed-risk economics, or portfolio admission.

Exactly one card may be extracted from this source. After extraction, update
`cards_extracted` with that card ID. The approved scope ends after branch
build, deterministic reference tests, strict Q01, and one CPU-admitted
non-live Q02 enqueue. It excludes optimization, live/demo/shadow/stress
presets, portfolio-gate changes, deploy/live manifests, `T_Live`, and
AutoTrading.
