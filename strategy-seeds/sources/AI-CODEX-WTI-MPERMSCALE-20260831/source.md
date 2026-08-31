---
source_id: AI-CODEX-WTI-MPERMSCALE-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly exact-permutation robust scale-expansion continuation
author: OpenAI Codex
supporting_authors: Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_monthly_permutation_mad_scale_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted: []
---

# WTI Monthly Exact-Permutation Robust Scale-Expansion Continuation

## Canonical origin

This packet is the single R1 lineage for one bounded AI-originated strategy.
The current explicit OWNER mission requests one new structural, low-frequency
commodity/energy sleeve and expressly permits a direct `XTIUSD.DWX` trend or
seasonality construction. `processes/qb_reputable_source_criteria.md` permits
AI-originated sources when the exact hypothesis, claim boundary, and durable
prompt/output trail are preserved.

Codex fixed the rule below before any market test and after a fail-closed
canonical duplicate scan. It is not presented as a Moskowitz, Ooi, and
Pedersen trading rule. Their paper supports the WTI carrier, monthly decision
clock, and own-return continuation direction only. The robust scale statistic,
all 924 fixed-size relabelings, the tail boundary, and the QM lifecycle are a
transparent pre-result synthesis.

## Supporting evidence and read boundary

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Its bounded findings include monthly
own-return continuation and explicit NYMEX WTI membership.

The paper does not split twelve WTI returns into adjacent six-return blocks,
compare median absolute deviations, enumerate fixed-size label assignments,
use a `416/924` upper-tail boundary, or test a continuous WTI CFD. No paper
return, alpha, Sharpe ratio, drawdown, trade count, cost result, or WTI-only
efficacy transfers. The reproducible local read record is
`retrieval_route_20260831.json`; no new public URL was used or represented as
read.

## Locked hypothesis

Physical supply, production, storage, transport, refining, hedging,
geopolitical, and demand shocks can move WTI into a wider return-distribution
regime. When the newest six completed monthly returns have a robust scale
expansion that ranks in the prescribed upper part of every possible six/six
relabeling, continue only the sign of the recent block mean for one month.

At the first executable D1 tick of a genuine new broker month:

1. Reconstruct thirteen consecutive completed `XTIUSD.DWX` broker-month end
   closes, oldest to newest, excluding every current-month price.
2. Form twelve adjacent chronological log returns `r[0..11]`.
3. Fix `old=r[0..5]` and `recent=r[6..11]`; never search for a time split.
4. For each six-value block, define its median as the average of sorted values
   three and four. Define its MAD as the median, under that same even-sample
   convention, of the six absolute deviations from the block median.
5. Compute `observed = MAD_recent - MAD_old` and require
   `observed > 1e-12`.
6. Enumerate every one of the `C(12,6)=924` choices of six returns as a
   pseudo-recent block; the complement is pseudo-old. Recompute both medians,
   both MADs, and `perm_delta = MAD_pseudo_recent - MAD_pseudo_old` for every
   assignment. Count inclusively with a `1e-14` comparison tolerance every
   `perm_delta >= observed`.
7. Qualify only when the inclusive upper-tail count is at most `416`. Buy
   when the arithmetic mean of the actual recent block is above `1e-12`;
   sell when it is below `-1e-12`; otherwise consume the month flat.
8. Persist the month before every fallible gate, risk exactly one
   `RISK_FIXED` budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and exit
   at the next genuine month or the forty-calendar-day stale boundary.

The tail count never scales exposure. `416/924` is a density-aware trading
boundary, not a significance level or an efficacy claim. There is no fitted
split, bootstrap, random draw, p-value, current-month fallback, same-month
retry, target, trail, break-even, partial, grid, scale-in, martingale, or
pyramid.

## Exact arithmetic contract

For chronological completed-month closes `C[0..12]`:

```text
for i = 0..11:
    r[i] = log(C[i+1] / C[i])

old    = r[0..5]
recent = r[6..11]

median6(x): sort x ascending; return (x[2] + x[3]) / 2
mad6(x):
    center = median6(x)
    dev[i] = abs(x[i] - center)
    return median6(dev)

observed = mad6(recent) - mad6(old)
require observed > 1e-12

tail_count = 0
assignment_count = 0
for each 12-bit mask having exactly six set bits:
    pseudo_recent = returns selected by the mask
    pseudo_old    = the complement
    perm_delta = mad6(pseudo_recent) - mad6(pseudo_old)
    if perm_delta >= observed - 1e-14:
        tail_count += 1
    assignment_count += 1

require assignment_count == 924
require tail_count <= 416

mean_recent = sum(recent) / 6
BUY  iff mean_recent >  1e-12
SELL iff mean_recent < -1e-12
FLAT otherwise
```

All closes, logarithms, returns, sort inputs, medians, deviations, MADs,
differences, and means must be finite. Every completed month must be present
exactly once and in strict chronological order. A non-expansion, excessive
tail count, zero recent mean, malformed history, wrong assignment count, or
arithmetic failure consumes the month flat.

## Non-duplicate boundary

The corrected-root canonical checker scanned 4,749 EA-registry identities,
1,387 card files, and 45 current Strategy Wiki nodes. It found no exact
identity and one expected fuzzy neighbor at score `0.53`:
`QM5_41249_wti-mwelch-shift-tr`. Receipt:
`artifacts/qm5_wti_mperm_scale_tr_preallocation_dedup_20260831.json`,
SHA-256 `133C36BA2F3B6CA20F658794A67CAD7A5277B8A454903A3C52F1D545D7928D4D`.

Manual mechanic review resolves the fuzzy match and nearby volatility
families:

- `QM5_41249` compares fixed-block arithmetic means and scales their
  difference by two sample variances. This rule ignores the old/recent mean
  difference for qualification, uses medians and median absolute deviations,
  and ranks the robust scale expansion over all 924 fixed-size relabelings.
- `QM5_20298_wti-vov-regime` compares two disjoint 252-sample distributions
  of rolling 20-day realized volatility and trades low-minus-high uncertainty.
  This rule uses only twelve completed monthly returns and trades an
  upper-tail robust scale expansion in the recent mean direction.
- `QM5_41108_wti-mrange-expansion-mom` compares two completed monthly high-low
  ranges and follows the newest monthly candle body. This rule uses neither
  monthly highs/lows nor candle bodies and requires a twelve-return exact
  relabeling distribution.
- `QM5_20288_wti-volnorm-mom` normalizes twelve separate monthly returns by
  their own within-month daily L2 paths and averages them. This rule compares
  the robust dispersion of two six-return blocks and never normalizes an
  individual return.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback; this rule is symmetric monthly direct WTI and contains
  no oscillator.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_EXACT_924_LABEL_PERMUTATION_ROBUST_SCALE_EXPANSION_RECENT_MEAN_CONTINUATION`.

## Reputable-source criteria

- R1: `PASS_WITH_AI_SYNTHESIS_BOUNDARY`. One durable AI-originated source ID
  and a complete-read peer-reviewed WTI monthly-continuation packet; the exact
  permutation-MAD conjunction is disclosed as an untested QM synthesis.
- R2: `PASS`. Clock, endpoints, returns, fixed blocks, median/MAD definition,
  all assignments, comparison tolerance, tail boundary, direction, attempt,
  risk, stop, spread, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 and MT5
  state supply every runtime input; roll, basis, financing, gap, and month-
  label risks remain.
- R4: `PASS`. Deterministic finite enumeration and native arithmetic only; no
  ML, trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. The upper-tail cap admits
at most twelve attempts and has a pre-result assignment-density prior of
`416/924`, approximately 45.02%; roughly five to six completed positions per
full post-warm-up year is a design prior only.

Q02 kills zero trades, any full post-warm-up year below five completed
positions, nonpositive governed economics, future leakage, or any
implementation defect. Q09 alone owns realized overlap. Failure may not be
rescued by changing the block size, robust scale definition, assignment set,
tail cap, direction rule, carrier, stop, risk, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if CPU capacity permits. It authorizes no manual
backtest, live/demo/shadow/stress/optimization preset, AutoTrading action,
`T_Live` change, deploy/live manifest, portfolio-gate edit, correlation
waiver, or portfolio admission.
