---
source_id: AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909
title: WTI monthly fixed-recency sign-score trend
publisher: OpenAI Codex / Journal of Financial Economics
source_type: governed_mechanization_with_peer_reviewed_parent
status: approved_source_complete
approval_basis: decisions/2026-09-09_wti_monthly_recency_sign_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
created: 2026-09-09
created_by: Research+Development
strategy_ids:
  - AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909_S01
cards_extracted:
  - wti-mrecency-sign-tr
---

# WTI Monthly Fixed-Recency Sign-Score Trend

## Approval And Complete-Read Scope

The durable approval is
`decisions/2026-09-09_wti_monthly_recency_sign_trend_source_approval.md`.
Before mechanization, the complete governed record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` was read. It preserves a
complete-paper read, author-hosted retrieval hash, DOI, monthly return-lag
findings, and explicit WTI membership for Moskowitz, Ooi, and Pedersen (2012).

The parent supports only monthly own-return continuation, the twelve-lag
research horizon, and WTI as a carrier. The fixed age weights on signs, score
boundary, continuous-CFD translation, execution clock, fixed risk, hard stop,
spread ceiling, and retry/lifecycle contract below are untested QM choices.

## Bounded Mechanization

At the first executable D1 tick of broker month `M`, consume `M` before every
fallible entry gate. Reconstruct exactly thirteen immediately prior
consecutive completed broker-month-end `XTIUSD.DWX` closes, oldest first:

```text
r[i] = ln(C[i+1]/C[i]), i=0..11
require abs(r[i]) > 1e-12
w[i] = i+1
S = sum(w[i] * sign(r[i]))

BUY  iff S >= 18
SELL iff S <= -18
FLAT otherwise
```

Require weight total 78 and score parity/range invariants. Return magnitude
and magnitude rank never affect signal or sizing. Use one `RISK_FIXED=1000`
budget, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point entry spread ceiling.
Close at the next broker-month boundary; forty elapsed days is stale repair.

Complete sign enumeration admits 2,124 of 4,096 paths at `|S|>=18`, or
6.22265625 states per twelve attempts before history and execution gates.

## Non-Duplicate Boundary

The receipt
`artifacts/qm5_wti_mrecency_sign_tr_preallocation_dedup_20260909.json`
contains no exact collision and one fuzzy signed-rank neighbor. Manual review
separates this fixed chronology-weighted sign functional from:

- `QM5_41273`, whose weights are the ranks of absolute return magnitudes;
- `QM5_20278`, which retains and linearly weights return magnitudes; and
- `QM5_13150`, which counts positive signs equally against a 0.40 boundary.

The exact WTI carrier, thirteen completed endpoints, twelve adjacent sign-only
observations, fixed oldest-to-newest weights `1..12`, total 78, inclusive
absolute-18 boundary, monthly attempt, and monthly renewal are jointly
load-bearing. Verdict:
`DISTINCT_WTI_TWELVE_CONTIGUOUS_FIXED_CHRONOLOGICAL_RECENCY_SIGN_SCORE_ABS18_CONTINUATION`.

## Reputable-Source Criteria And Kill Boundary

- R1 passes with explicit translation risk through a complete-read,
  peer-reviewed WTI monthly-trend parent.
- R2 passes with every state, arithmetic, direction, risk, and lifecycle rule
  locked before Q02.
- R3 passes with registered `XTIUSD.DWX` D1 and MT5-native state only, subject
  to continuous-CFD basis and financing risk.
- R4 passes because runtime uses deterministic timestamps, prices,
  logarithms, signs, integer arithmetic, ATR, and framework state only.

Q02 retires zero trades, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, or any clock, endpoint,
sign, weight, score, side, attempt, risk, stop, spread, lifecycle, or
determinism defect. No result may be rescued by changing the sample, weights,
threshold, direction, carrier, stop, hold, spread, or retry policy.

This packet authorizes one card, allocation, branch-only non-live build,
strict Q01, and one paced Q02 enqueue. It authorizes no optimization, manual
tester launch, portfolio admission, portfolio-gate change, correlation waiver,
deployment, live manifest, `T_Live`, AutoTrading, or live use.
