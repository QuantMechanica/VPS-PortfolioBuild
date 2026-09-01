---
source_id: AI-CODEX-WTI-M3BLOCK-RANK-TREND-20260901
title: WTI completed-month three-block ordinal close trend continuation
publisher: QuantMechanica governed synthesis from complete-read peer-reviewed WTI research
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_three_block_rank_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41274_wti-m3block-rank-tr
---

# WTI Completed-Month Three-Block Ordinal Close Trend Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_three_block_rank_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one
reputable-source, structural low-frequency sleeve and explicitly identifies a
direct WTI trend or seasonality edge as eligible. This packet is bounded to
one card, one branch build, strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence read before extraction is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
It preserves a complete read of Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, including monthly own-return continuation,
the source-declared one-month formation/one-month hold commodity portfolio,
and explicit NYMEX WTI membership.

No fresh generic webpage is source evidence. The public trading-source skill
requires an OWNER-supplied URL and policy-gated routing; neither condition
admits an exploratory page here. No snippet, external runtime source, inferred
result, trained output, or unpublished performance number enters the
hypothesis.

## Source-Defined Findings

Moskowitz, Ooi, and Pedersen document monthly own-return continuation across
liquid futures, include NYMEX WTI in the commodity universe, and explicitly
report a pooled commodity `k=1`, `h=1` rule. Their result is not a WTI-only
continuous-CFD result and does not define the QM daily-close blocks, ordinal
score, tie rule, fixed-dollar risk, ATR stop, spread ceiling, or lifecycle.

## Bounded Trading Hypothesis

At each broker-month transition:

```text
M = every chronological completed D1 session in the immediately prior month
require 17 <= len(M) <= 23
C[0..14] = final fifteen chronological closes in M
require every C finite and positive
require abs(C[i]-C[j]) > 0.5*_Point for every i != j

G0 = C[0..4]
G1 = C[5..9]
G2 = C[10..14]

W = 0
comparisons = 0
for every block pair a<b:
    for every x in Ga and y in Gb:
        comparisons += 1
        if y > x: W += 1

require comparisons == 75 and 0 <= W <= 75
BUY  iff 2*W > 75
SELL iff 2*W < 75
```

Continue that ordinal completed-month path direction for one broker month.
Consume the month before history, signal, news, spread, quote, ATR, sizing,
margin, or order gates. Use a frozen `3.5*ATR(20,D1)` hard stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a 1,500-point
spread ceiling, next-month close, and forty-day stale repair.

This is a deterministic classifier, not a Jonckheere-Terpstra test or any
other inference claim. Daily closes are serially dependent and price levels
are nonstationary. No p-value, critical value, independence assumption, or
significance statement is imported.

## Exact Support And Claim Boundary

With strict pairwise close ordering, `W` is integer and `2*W` is even, so it
cannot equal the odd center 75. Every valid month maps to exactly one side.
The market-free activity ceiling is twelve states per year before history,
ties, quotes, costs, ATR, sizing, margin, or execution. This is not a WTI
probability or performance forecast.

## Reputable-Source Criteria

- R1: `PASS_WITH_AI_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK`. The
  carrier and broad monthly continuation premise have a complete-read
  peer-reviewed paper with DOI and durable PDF hash. Every QM translation and
  the absence of a WTI-only result are disclosed.
- R2: `PASS`. Month clock, sessions, final-fifteen selection, blocks, tie
  rule, comparisons, center split, direction, attempt, risk, stop, spread,
  and lifecycle are deterministic and frozen before testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and MT5-native state provide every runtime input. Continuous-CFD
  roll, basis, financing, gaps, and broker-month labels remain risks.
- R4: `PASS`. Only timestamps, completed prices, comparisons, integer counts,
  ATR risk controls, quotes, positions, deals, and persistent state are used.
  There is no ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_m3block_rank_tr_preallocation_dedup_20260901.json`,
SHA-256
`2CC07EFAA3F1A5618442E1DA8B17E42A24B14B3E3561C12B985AC740E26D828D`,
checked 4,773 registry rows, 1,409 cards, and 45 Strategy Wiki nodes. It found
no exact identity and one naming-driven fuzzy neighbor, QM5_41273.

Manual review separates the substantive neighbors:

- `QM5_41115` votes three cumulative return signs and uses a parent-month
  anchor. This packet uses no parent and counts 75 cross-block close wins. The
  fixed vector recorded in the approval makes this packet buy while QM5_41115
  sells.
- `QM5_41111` counts adjacent daily return signs and requires endpoint
  agreement. This packet compares close levels and has no endpoint gate.
- `QM5_20264` uses 13 month-end observations and 78 all-pair comparisons;
  this packet uses 15 within-month D1 closes and only cross-block pairs.
- `QM5_41273` ranks absolute monthly-return sizes and applies an absolute-18
  score boundary. This packet has neither monthly returns nor magnitude ranks.
- `QM5_20187` follows a single monthly endpoint return. The fixed
  `[100..113,99]` path in the approval buys here while its endpoint is down.
- `QM5_12567` is a two-day long-only XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL15_CLOSE_THREE_BLOCK_75_PAIR_ORDINAL_DOMINANCE_CONTINUATION`.

## Failure And Extraction Boundaries

- Retire on zero positions or fewer than five completed positions in any full
  post-warm-up calendar year.
- Retire on nonpositive governed economics, deterministic-reference mismatch,
  malformed lifecycle behavior, or any downstream gate failure.
- No result-driven change to sample, blocks, epsilon, score, side, stop,
  spread, or hold is authorized after Q02.
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
