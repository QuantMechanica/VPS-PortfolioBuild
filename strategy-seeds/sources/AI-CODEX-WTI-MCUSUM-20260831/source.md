---
source_id: AI-CODEX-WTI-MCUSUM-20260831
source_type: ai_originated_governed_synthesis
title: WTI monthly centered-CUSUM return-regime shift trend
author: OpenAI Codex
supporting_authors: E. S. Page; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; NIST/SEMATECH
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_monthly_centered_cusum_shift_trend_source_approval.md
created: 2026-08-31
created_by: Codex
last_reviewed: 2026-08-31
cards_extracted: []
---

# WTI Monthly Centered-CUSUM Return-Regime Shift Trend

## Canonical Origin

This packet is the single R1 lineage for one bounded AI-originated strategy.
The current explicit OWNER mission requests a new structural low-frequency
commodity/energy sleeve and permits a direct `XTIUSD.DWX` trend construction.
`processes/qb_reputable_source_criteria.md` permits AI-originated sources when
the exact hypothesis, evidence boundary, and prompt/output trail are durable.

Codex synthesized the rule below after a canonical pre-allocation scan. It is
not presented as an extracted Page, NIST, or Moskowitz trading rule. Those
records are supporting evidence only.

## Supporting Evidence And Complete-Read Boundary

### WTI carrier and monthly continuation

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Its bounded findings include monthly
own-return continuation and explicit NYMEX WTI membership.

The paper does not test centered return CUSUMs, an endogenous split, a
continuous WTI CFD, the central band, fixed-dollar risk, an ATR stop, or the
QM lifecycle. No paper return, alpha, Sharpe ratio, drawdown, trade count,
cost result, or WTI-only efficacy transfers.

### CUSUM method record

E. S. Page (1954), "Continuous Inspection Schemes," *Biometrika* 41(1/2),
100-115, DOI `10.1093/biomet/41.1-2.100`, is the named peer-reviewed method
record. Oxford Academic exposed the author, journal, volume, issue, date,
pages, and DOI. The article body was not accessible; no formula, threshold,
table, or result from the inaccessible body is reconstructed.

The complete public NIST/SEMATECH Engineering Statistics Handbook page
"CUSUM Control Charts" was read at
`https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc323.htm`. It defines
a cumulative sum around an estimated process mean and explains that a shift
in the mean produces directional drift in the path. The retrieval record is
`retrieval_route_20260831.json`.

NIST documents process monitoring, not a trading strategy. The retrospective
finite bridge, maximum split, central-band admission, post-segment side, WTI
carrier, and execution contract below are disclosed QM choices.

## Locked Hypothesis

Physical supply, inventory, transport, refining, hedging, investment,
geopolitical, and demand adjustments can shift WTI's monthly return regime.
When one unique central split creates the largest mean-centered cumulative
return excursion in the latest twelve completed months, follow the mean sign
of the post-split regime for the next month.

On the first executable D1 tick of a genuine new broker month:

1. Reconstruct thirteen consecutive completed `XTIUSD.DWX` broker-month end
   closes, oldest to newest.
2. Form twelve adjacent log returns `r[0..11]` and their arithmetic mean.
3. For split count `k=1..11`, compute
   `S[k] = sum(r[0..k-1]) - k*mean`.
4. Require one and only one maximum absolute `|S[k]|`, treating values within
   `1e-12` as tied, and require `4 <= k <= 8`.
5. Buy when the post-split arithmetic mean of `r[k..11]` exceeds `1e-12`;
   sell when it is below `-1e-12`; otherwise remain flat.
6. Persist the month before every fallible gate, risk exactly one
   `RISK_FIXED` budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and exit
   at the next genuine month or forty-calendar-day stale boundary.

The terminal `k=12` sum is identically zero and is excluded. The statistic
magnitude does not scale exposure. There is no p-value, control limit,
standardization, rank transform, Page tabular reset, endpoint fallback,
same-month retry, target, trail, break-even, partial, grid, scale-in,
martingale, or pyramid.

## Exact Arithmetic Contract

For `n=12`, define:

```text
mean = sum(r[0..11]) / 12

running = 0
for k = 1..11:
    running += r[k-1]
    S[k] = running - k*mean

M = max(abs(S[k]))
K = { k : abs(abs(S[k]) - M) <= 1e-12 }

qualify iff M > 1e-12 and size(K) == 1 and 4 <= K[0] <= 8
post_mean = sum(r[K[0]..11]) / (12-K[0])

BUY  iff qualify and post_mean >  1e-12
SELL iff qualify and post_mean < -1e-12
FLAT otherwise
```

All closes, logarithms, returns, sums, means, and path values must be finite.
Every requested completed month must be present exactly once and in strict
chronological order. Invalid state consumes the month flat.

## Non-Duplicate Boundary

The corrected-root canonical check returned `CLEAN` after scanning 4,744 EA
registry identities, 1,382 card files, and 45 current Strategy Wiki nodes.
Receipt:
`artifacts/qm5_wti_mcusum_shift_tr_preallocation_dedup_20260831.json`,
SHA-256 `F397FDCF63414FF4CFE1C64AA9D1EEE9DE368643F30B3451F2785F06B61C45D2`.

The nearest structural families retain different information:

- Pettitt `QM5_41172` ranks thirteen price levels and uses the signed rank
  path; this rule centers twelve magnitude-bearing log returns and uses the
  post-split return mean for side.
- fixed-block KS `QM5_41183` fixes six old and six new price levels and keeps
  a maximum ECDF count gap; this rule searches eleven return splits and keeps
  one central maximum arithmetic excursion.
- Mann-Whitney `QM5_41176` counts every fixed-block price pair; this rule has
  no ranks or pair counts.
- OLS trend `QM5_20261` uses a log-price slope and `R^2`; this rule fits no
  regression.
- same-calendar regime shift `QM5_41224` compares ten recurring named-month
  returns; this rule uses one contiguous twelve-month path.
- certified `QM5_12567` is an XNG long-only cumulative-RSI pullback; this rule
  is symmetric monthly direct WTI and contains no oscillator.

Verdict:
`CLEAN_WTI_MONTHLY_CENTERED_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTINUATION`.

## Reputable-Source Criteria

- R1: `PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY`. One durable
  AI-originated source ID, complete-read peer-reviewed WTI evidence, a named
  Page bibliographic record, and a complete official NIST method page.
- R2: `PASS`. Data, clock, formula, tie tolerance, split band, side, attempt,
  risk, stop, spread, and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 and
  MT5 state supply every runtime input; roll, basis, financing, gap, and month
  labels remain risks.
- R4: `PASS`. Deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Claim, Kill, And Safety Boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. Q02 kills zero trades, a
full post-warm-up year below five completed trades, nonpositive governed
economics, or any implementation defect. Q09 alone owns realized overlap.
No failed result may be rescued by changing the sample, central band,
uniqueness tolerance, post-mean side, carrier, stop, risk, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if CPU capacity permits. It authorizes no manual
backtest, live/demo/shadow/stress/optimization preset, AutoTrading action,
`T_Live` change, deploy/live manifest, portfolio-gate edit, correlation
waiver, or portfolio admission.
