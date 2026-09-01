---
source_id: AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901
title: WTI monthly strict signed-rank trend continuation
publisher: QuantMechanica governed synthesis from complete-read peer-reviewed WTI research and pinned primary software evidence
source_type: ai_originated_peer_reviewed_primary_software_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_signed_rank_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026: 57FF7096210C5E48A7236DAD6799A3E6CE706E726BD704416064D5A803D10B98
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41273_wti-msigned-rank-tr
---

# WTI Monthly Strict Signed-Rank Trend Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_signed_rank_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one
reputable-source, structural low-frequency sleeve and explicitly identifies a
direct WTI trend or seasonality edge as eligible. This packet is bounded to
one card, one branch build, strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence read before extraction is:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   preserving a complete read of Moskowitz, Ooi, and Pedersen (2012),
   *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, including monthly own-return continuation,
   the twelve-lag horizon, and explicit NYMEX WTI membership;
2. `strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md`,
   SHA-256
   `57FF7096210C5E48A7236DAD6799A3E6CE706E726BD704416064D5A803D10B98`,
   preserving complete pinned R Core `wilcox.test` implementation and manual
   evidence for one-sample signed absolute ranks; and
3. the prior method approval at
   `decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md`,
   SHA-256
   `2663F9C9D1A36A1101F7C0C7780196E0F1E1FEB574AD6CA28B269DE2E01FB501`,
   which records the R commit, blobs, file hashes, complete line counts, and
   inference boundary.

No fresh generic webpage is evidence. Exploratory NIST and DOI routes were
classified `DEFERRED:SOURCE_POLICY` by the deterministic source reader and
were excluded. No external runtime source, inferred result, trained output,
or unpublished performance number enters the hypothesis.

## Source-Defined Findings

Moskowitz, Ooi, and Pedersen document monthly own-return continuation across
liquid futures, include NYMEX WTI in the commodity universe, and study trend
signals through twelve monthly lags. Their result is not a WTI-only continuous
CFD result and does not define the QM rank filter, fixed-dollar risk, or ATR
stop.

The pinned R Core one-sample implementation defines the operative arithmetic
at location `mu=0`:

```text
x <- x - mu
r <- rank(abs(x))
V <- sum(r[x > 0])
```

The manual distinguishes this signed-rank statistic from the two-sample
rank-sum/Mann-Whitney statistic. This packet uses the centered form
`S=2*V-78` only as a deterministic direction and strength score. It computes
no p-value, confidence interval, significance result, or location estimate.

## Bounded Trading Hypothesis

At each broker-month transition:

```text
C[0..12] = thirteen chronological completed WTI month-end closes
r[i] = ln(C[i+1]/C[i]), i=0..11

require every r[i] finite and abs(r[i]) > 1e-12
require every pair abs(r[i]), abs(r[j]) distinct beyond 1e-12
rank abs(r) strictly from 1 through 12
V_plus = sum(rank(abs(r[i])) where r[i] > 0)
T = 78
S = 2*V_plus - T

BUY  iff S >= 18
SELL iff S <= -18
FLAT otherwise
```

Continue that rank-weighted return direction for one broker month. Consume the
month before history, signal, news, spread, quote, ATR, sizing, margin, or
order gates. Use a frozen `3.5*ATR(20,D1)` hard stop, no target,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a 1,500-point
spread ceiling, next-month close, and forty-day stale repair.

## Exact Support And Claim Boundary

Enumerating all 4,096 strict-rank sign assignments gives 1,062 assignments at
`S>=18` and 1,062 at `S<=-18`. The total activity support is
`2,124/4,096 = 0.5185546875`, or a market-free 6.22265625 states per twelve
monthly attempts. This is not a probability model for WTI and the threshold
is not a p-value or critical value.

Chronological monthly returns can be serially dependent. Ranks and signs can
also be dependent. The statistic is therefore a transparent structural state,
not a valid inference claim in this use.

## Reputable-Source Criteria

- R1: `PASS_WITH_COMPOSITE_SOURCE_AND_CONTINUOUS_CFD_TRANSLATION_RISK`. The
  carrier has a complete-read peer-reviewed paper with DOI and durable PDF
  hash; the method has complete pinned R Core implementation/manual evidence.
  Every QM translation and the absence of a WTI-only result are disclosed.
- R2: `PASS`. Month clock, closes, returns, zero/tie rule, ranks, score,
  inclusive boundary, direction, attempt, risk, stop, spread, and lifecycle
  are deterministic and frozen before testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and MT5-native state provide every runtime input. Continuous-CFD
  roll, basis, financing, gaps, and broker-month labels remain risks.
- R4: `PASS`. Only timestamps, completed prices, logarithms, sorting, integer
  ranks, comparisons, ATR risk controls, quotes, positions, deals, and
  persistent state are used. There is no ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_msigned_rank_tr_preallocation_dedup_20260901.json`,
SHA-256
`AE49BB417E6B8D35EEFBF8EA86FB6B3E1C3786ADACAF62FA6AA2F51EADBCE337`,
checked 4,772 registry rows, 1,408 cards, and 45 Strategy Wiki nodes. It found
no exact or above-threshold fuzzy identity.

Manual review still compares the semantically closest systems:

- `QM5_41191_wti-samecal-srank` uses five-to-ten disjoint returns for the
  same upcoming calendar month across prior years and enters on every nonzero
  score. This packet uses exactly twelve contiguous latest returns and a
  locked `|S|>=18` strength boundary.
- `QM5_12603_wti-tsmom12m` retains metric cumulative-return magnitude. Eleven
  positive returns `.01..11` and one `-1.00` produce `S=54` here but a
  negative cumulative return there; negation proves the reverse disagreement.
- A zero-threshold signed-rank rule enters on the fixed rank-sign assignment
  with positive ranks `{7,10,11,12}`, whose `S=2`; this packet stays flat.
- Seven small positive ranks `1..7` and five larger negative ranks `8..12`
  give a positive sign majority but `S=-22`, separating sign-count rules.
- `QM5_41176_wti-mwilcoxon-shift-tr` is a two-sample six-old/six-new
  Mann-Whitney location-shift statistic; it neither ranks signed absolute
  returns nor uses the one-sample centered score.

Verdict:
`DISTINCT_WTI_MONTHLY_TWELVE_CONTIGUOUS_STRICT_SIGNED_ABSOLUTE_RANK_SCORE_ABS18_CONTINUATION`.

## Failure And Extraction Boundaries

- Retire on zero positions or fewer than five completed positions in any full
  post-warm-up calendar year.
- Retire on nonpositive governed economics, deterministic-reference mismatch,
  malformed lifecycle behavior, or any downstream gate failure.
- No result-driven change to sample, epsilon, tie rule, threshold, side, stop,
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
