---
source_id: AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901
title: WTI monthly Siegel-Tukey alternating-extremes scale continuation
publisher: QuantMechanica governed AI synthesis from peer-reviewed WTI and statistical-method research plus complete official NIST evidence
source_type: ai_originated_peer_reviewed_official_method_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_siegel_tukey_scale_trend_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
method_records:
  - SIEGEL-TUKEY-1960
  - NIST-DATAPLOT-SIEGEL-TUKEY-2023
created: 2026-09-01
created_by: Research+Development
cards_extracted:
  - QM5_41271_wti-msiegel-tukey-scale-tr
---

# WTI Monthly Siegel-Tukey Alternating-Extremes Scale Continuation

## Approval And Complete Read

The durable approval is
`decisions/2026-09-01_wti_monthly_siegel_tukey_scale_trend_source_approval.md`.
The current explicit OWNER commodity/energy mission authorizes one reputable-
source, structural low-frequency sleeve and identifies direct WTI trend or
seasonality as eligible. This packet is bounded to one card, one branch build,
strict Q01, and one paced non-live Q02 enqueue.

The complete bounded evidence was read before card extraction:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   which preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, including own-return continuation and
   explicit NYMEX WTI membership;
2. the complete visible NIST Dataplot `SIEGEL TUKEY TEST` page, normalized
   visible-text SHA-256
   `1E08B7B58AAB8BFCA2638A8BC949B79AFD6C85CECB944BAB4693A86D161468AA`,
   including the alternating-extremes rank assignment, rank-sum reduction,
   tail options, exact small-sample example, related commands, reference, and
   implementation dates;
3. Crossref and publisher metadata for Siegel and Tukey (1960), "A
   Nonparametric Sum of Ranks Procedure for Relative Spread in Unpaired
   Samples," *Journal of the American Statistical Association* 55(291),
   429-445, DOI `10.1080/01621459.1960.10482073`.

The publisher abstract states the intended two-independent-sample relative-
spread problem, distribution-free null scope, tie correction availability,
and absence of a normality requirement. The publisher body was access-
controlled, so no complete original-paper body read, hidden derivation,
critical-table value, or PDF hash is claimed. Exact operational arithmetic
comes from the completely read official NIST record. Retrieval hashes and
access boundaries are stored beside this packet.

No external runtime source, inferred result, trained output, or unpublished
performance number enters the hypothesis.

## Source-Defined Findings

### WTI carrier

Moskowitz, Ooi, and Pedersen document monthly own-return continuation across
liquid futures, include NYMEX WTI in the commodity universe, and explicitly
test a one-month formation/one-month hold commodity portfolio. The paper does
not establish a WTI-only result and does not use continuous CFDs or fixed-
dollar ATR risk.

### Siegel-Tukey construction

The NIST record defines the deterministic method:

1. combine two samples and sort pooled observations from smallest to largest;
2. assign rank 1 to the smallest, 2 to the largest, 3 to the next largest, 4
   to the second smallest, and continue this alternating-extremes pattern;
3. apply a Mann-Whitney rank-sum calculation to the transformed ranks.

For sixteen distinct pooled values, following that prescription exactly gives
the ascending-observation score path:

```text
rank position:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
ST score:       1  4  5  8  9 12 13 16 15 14 11 10  7  6  3  2
```

Both extremes receive small scores, with the alternating direction breaking
the otherwise mirrored pairs. A sample that occupies more pooled extremes
tends to have a smaller score sum. The EA rejects every exact pooled return
tie, so no tie-score convention is needed.

## Bounded Trading Hypothesis

WTI physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand adjustments can move the dispersion and tail
occupancy of monthly returns. At each broker-month transition:

```text
C[0..16] = seventeen consecutive completed WTI broker-month closes
r[i] = ln(C[i+1]/C[i]), i=0..15
old = r[0..7]; recent = r[8..15]

require all returns finite and pairwise distinct
sort pooled returns ascending while retaining old/recent labels
assign the locked sixteen-value Siegel-Tukey score path
S_recent = sum(ST score for each recent-labelled rank position)

enumerate every sixteen-bit mask with exactly eight recent labels
tail_count = count(S_mask <= S_recent)
require assignment_count == 12,870
qualify iff S_recent <= 68 and tail_count <= 6,698

recent_return = sum(r[8..15])
BUY  iff recent_return >  1e-12
SELL iff recent_return < -1e-12
FLAT otherwise
```

The score boundary 68 is the exact rank-sum expectation
`8*(16+1)/2`. Complete enumeration gives 6,698 qualifying assignments out of
12,870, or `0.5204351204351204`; exactly 526 assignments lie at the boundary.
This is an inclusive half-support activity gate, not a p-value, significance
level, critical value, or efficacy claim. Overlapping chronological blocks
also violate independent-sample inference, so the score is only a
deterministic structural state.

Continue the sign of the recent eight-month cumulative return for one broker
month. Consume the month before history, signal, news, spread, quote, ATR,
sizing, margin, or order gates. Use a frozen `3.5*ATR(20,D1)` hard stop, no
target, `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a
1,500-point spread ceiling, next-month close, and forty-day stale repair.

## Reputable-Source Criteria

- R1: `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`. The WTI carrier
  has a complete-read peer-reviewed paper with DOI and durable PDF hash. The
  method has original peer-reviewed JASA lineage plus Crossref/publisher
  metadata and a completely read official NIST algorithm page. The
  inaccessible original body and every QM translation are disclosed.
- R2: `PASS`. Month clock, closes, returns, split, tie rule, score path,
  enumeration, inclusive boundary, direction, attempt, risk, stop, spread,
  and lifecycle are deterministic and frozen before testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history and MT5-native state provide every runtime input. Continuous-CFD
  roll, basis, financing, gaps, and broker-month labels remain risks.
- R4: `PASS`. Only timestamps, completed prices, logarithms, sorting, integer
  ranks, bounded enumeration, comparisons, ATR risk controls, quotes,
  positions, deals, and persistent state are used. There is no ML, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Review

The corrected-root dedup receipt
`artifacts/qm5_wti_msiegel_tukey_scale_tr_preallocation_dedup_20260901.json`,
SHA-256
`F3DA6AE29D70BC1BF5E210D7F61D64966A0908898DA4B2DCB6C0EBC7ACD62A72`,
checked 4,770 registry rows, 1,407 cards, and 45 strategy-wiki nodes. It found
one fuzzy match, `QM5_41261_wti-mab-scale-tr`, at score
`0.7142857142857143`, requiring manual formula review.

The existing card uses twelve monthly returns, six-by-six blocks, the
mirrored Ansari-Bradley score path
`1,2,3,4,5,6,6,5,4,3,2,1`, 924 assignments, and boundary `21/522`. The new
source uses sixteen returns, eight-by-eight blocks, a non-mirrored alternating-
extremes permutation of ranks, 12,870 assignments, and boundary `68/6698`.

Two centered, distinct-return chronological rank fixtures prove both
disagreement directions when each rule uses its own approved window:

```text
fixture A ranks = [7,6,1,8,14,9,5,15,2,12,3,11,4,10,16,13]
new ST score=61 -> qualify; existing AB score=22 -> flat

fixture B ranks = [15,14,7,3,5,10,1,11,12,6,13,8,4,2,16,9]
new ST score=74 -> flat; existing AB score=20 -> qualify
```

The relevant recent cumulative sums are positive in both fixtures, so this
is qualification disagreement rather than a side-effect of a neutral or
opposite direction. The load-bearing mechanic is therefore not a parameter
variant of `QM5_41261`.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_RANK_SUM_EXACT_12870_LOWER_TAIL6698_RECENT_RETURN_CONTINUATION`.

## Failure And Claim Boundaries

- Retire on zero positions or fewer than five completed positions in any full
  post-warm-up calendar year.
- Retire on nonpositive governed economics, deterministic-reference mismatch,
  malformed lifecycle behavior, or any downstream gate failure.
- No result-driven change to sample, score direction, boundary, return side,
  stop, spread, or hold is authorized after Q02.
- Q09 alone can establish realized decorrelation. WTI carrier identity is not
  a correlation result.
- No source claims this conjunction, its activity, WTI-only profitability,
  continuous-CFD equivalence, fixed-risk economics, or portfolio admission.

## Extraction Boundary

Exactly one card may be extracted from this source. After extraction, update
`cards_extracted` with that card ID. The approved scope ends after branch
build, deterministic reference tests, strict Q01, and one CPU-admitted
non-live Q02 enqueue. It excludes optimization, live/demo/shadow/stress
presets, portfolio-gate changes, deploy/live manifests, `T_Live`, and
AutoTrading.
