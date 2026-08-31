---
source_id: AI-CODEX-WTI-MWELCH-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly fixed-block Welch mean-shift continuation
author: OpenAI Codex
supporting_authors: B. L. Welch; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_monthly_welch_mean_shift_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted:
  - QM5_41249_wti-mwelch-shift-tr
---

# WTI Monthly Fixed-Block Welch Mean-Shift Continuation

## Canonical origin

This packet is the single R1 lineage for one bounded AI-originated strategy.
The current explicit OWNER mission requests one new structural low-frequency
commodity/energy sleeve and expressly permits a direct `XTIUSD.DWX` trend or
seasonality construction. `processes/qb_reputable_source_criteria.md` permits
AI-originated sources when the exact hypothesis, claim boundary, and durable
prompt/output trail are preserved.

Codex synthesized the rule below before any market test and after the
fail-closed canonical duplicate scan. It is not presented as a Welch or
Moskowitz trading rule. Those records support the statistical state object,
WTI carrier, and monthly continuation direction only.

## Supporting evidence and read boundary

### WTI carrier and monthly continuation

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Its bounded findings include monthly
own-return continuation and explicit NYMEX WTI membership.

The paper does not test two fixed adjacent six-return samples, an unequal-
variance standardized mean shift, the `0.75` boundary, a continuous WTI CFD,
the QM lifecycle, or this strategy's economics. No paper return, alpha,
Sharpe ratio, drawdown, trade count, cost result, or WTI-only efficacy
transfers.

### Unequal-variance mean-comparison method

B. L. Welch (1938), "The Significance of the Difference Between Two Means
When the Population Variances Are Unequal," *Biometrika* 29(3-4), 350-362,
DOI `10.1093/biomet/29.3-4.350`, is the named peer-reviewed method record.
Oxford Academic exposed complete bibliographic metadata but not the article
body. No inaccessible table, threshold, formula derivation, or result is
reconstructed.

The complete public SciPy 1.18.0 `scipy.stats.ttest_ind` method page and its
tag-pinned public source were reviewed. The documentation states that
`equal_var=False` performs Welch's unequal-variance form and defines the
statistic orientation as the difference of arithmetic means divided by its
standard error. Retrieval evidence is in `retrieval_route_20260831.json`.

SciPy and Welch document a statistical comparison, not this trading rule.
The fixed samples, score boundary, sign-alignment rule, WTI carrier, risk,
stop, and lifecycle below are disclosed pre-result QM choices. The EA uses no
SciPy runtime dependency and calculates no p-value or degrees of freedom.

## Locked hypothesis

Physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand adjustments can shift WTI's monthly
return location while its volatility changes. When the latest six completed
monthly log returns have moved far enough from the preceding six under an
unequal-variance standard error, continue only a recent mean whose sign agrees
with the shift.

On the first executable D1 tick of a genuine new broker month:

1. Reconstruct thirteen consecutive completed `XTIUSD.DWX` broker-month end
   closes, oldest to newest, excluding every current-month price.
2. Form twelve adjacent chronological log returns `r[0..11]`.
3. Fix `old=r[0..5]` and `recent=r[6..11]`; never search for a split.
4. Compute each arithmetic mean and unbiased sample variance with denominator
   five.
5. Compute `se2 = var_old/6 + var_recent/6` and
   `score = (mean_recent - mean_old) / sqrt(se2)`.
6. Buy only when `score >= 0.75` and `mean_recent > 1e-12`; sell only when
   `score <= -0.75` and `mean_recent < -1e-12`; otherwise stay flat.
7. Persist the month before every fallible gate, risk exactly one
   `RISK_FIXED` budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and exit
   at the next genuine month or the forty-calendar-day stale boundary.

The score magnitude never scales exposure. There is no p-value, critical
table, fitted split, pooled-variance assumption, endpoint fallback, same-
month retry, target, trail, break-even, partial, grid, scale-in, martingale,
or pyramid.

## Exact arithmetic contract

For chronological completed-month closes `C[0..12]`:

```text
for i = 0..11:
    r[i] = log(C[i+1] / C[i])

old    = r[0..5]
recent = r[6..11]

mean_old    = sum(old) / 6
mean_recent = sum(recent) / 6

var_old    = sum((old[i]    - mean_old)^2 for i=0..5) / 5
var_recent = sum((recent[i] - mean_recent)^2 for i=0..5) / 5

se2 = var_old/6 + var_recent/6
require se2 > 1e-18
score = (mean_recent - mean_old) / sqrt(se2)

BUY  iff score >=  0.75 and mean_recent >  1e-12
SELL iff score <= -0.75 and mean_recent < -1e-12
FLAT otherwise
```

All closes, logarithms, returns, sums, means, centered differences,
variances, `se2`, its square root, and the score must be finite. Every
completed month must be present exactly once and in strict chronological
order. Degenerate variance, a boundary miss, sign disagreement, zero recent
mean, malformed history, or arithmetic failure consumes the month flat.

## Non-duplicate boundary

The corrected-root canonical checker returned `CLEAN` after scanning 4,748
EA-registry identities, 1,386 card files, and 45 current Strategy Wiki nodes.
Receipt:
`artifacts/qm5_wti_mwelch_shift_tr_preallocation_dedup_20260831.json`,
SHA-256 `418F80E037B15060AA00B11736783446818B7AAA892B49EF9C9F9A95B0777D67`.

The nearest structural families retain different information:

- Mann-Whitney `QM5_41176` counts all 36 cross-block wins among monthly price
  levels and rejects every tie; this rule compares adjacent monthly returns
  in magnitude units with separate sample variances.
- fixed-block KS `QM5_41183` keeps only the maximum signed ECDF count gap of
  price levels; this rule has no ranks, combined sort, or ECDF.
- Wald-Wolfowitz `QM5_41184` counts pooled sample-label runs in price levels;
  this rule has no label-run state.
- daily median shift `QM5_41137` compares two months of daily log-price
  levels; this rule uses twelve completed monthly returns in fixed half-years.
- centered CUSUM `QM5_41245` searches all eleven return splits and retains a
  unique central maximum; this rule fixes exactly one six/six split and uses
  an unequal-variance denominator.
- certified `QM5_12567` is a long-only two-day XNG cumulative-RSI pullback;
  this rule is symmetric monthly direct WTI and contains no oscillator.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_WELCH_RETURN_MEAN_SHIFT_ALIGNED_CONTINUATION`.

## Reputable-source criteria

- R1: `PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY`. One durable
  AI-originated source ID, complete-read peer-reviewed WTI evidence, a named
  Welch bibliographic record, and complete public SciPy method evidence.
- R2: `PASS`. Clock, endpoints, return orientation, fixed samples, means,
  variances, denominator, boundary, side, attempt, risk, stop, spread, and
  lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 and MT5
  state supply every runtime input; roll, basis, financing, gap, and month-
  label risks remain.
- R4: `PASS`. Deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. The fixed `0.75` score is
a density-aware pre-result trading boundary, not a Welch critical value.
At most twelve attempts occur per year; approximately five to eight completed
positions per full post-warm-up year is a design prior only.

Q02 kills zero trades, any full post-warm-up year below five completed
positions, nonpositive governed economics, or any implementation defect.
Q09 alone owns realized overlap. Failure may not be rescued by changing the
sample size, split, variance definition, score boundary, sign alignment,
carrier, stop, risk, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if CPU capacity permits. It authorizes no manual
backtest, live/demo/shadow/stress/optimization preset, AutoTrading action,
`T_Live` change, deploy/live manifest, portfolio-gate edit, correlation
waiver, or portfolio admission.
