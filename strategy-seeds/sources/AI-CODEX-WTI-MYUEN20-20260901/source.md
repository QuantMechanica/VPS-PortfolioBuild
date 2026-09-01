---
source_id: AI-CODEX-WTI-MYUEN20-20260901
source_type: ai_originated_governed_synthesis
title: WTI monthly fixed-block 20-percent Yuen trimmed-location shift continuation
author: OpenAI Codex
supporting_authors: Karen K. Yuen; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community
status: approved_source_complete
approval_basis: decisions/2026-09-01_wti_monthly_yuen20_trimmed_shift_trend_source_approval.md
created: 2026-09-01
created_by: Codex
last_reviewed: 2026-09-01
cards_extracted: []
---

# WTI Monthly 20% Yuen Trimmed-Location Shift Continuation

## Canonical origin

This packet is the single R1 lineage for one bounded AI-originated strategy.
The current OWNER mission requests one new structural, low-frequency
commodity/energy sleeve outside the directional XAU/SP500/NDX/XNG book and
expressly permits direct `XTIUSD.DWX` trend or seasonality. The exact trading
rule was synthesized before any market test and after a fail-closed canonical
duplicate scan.

The rule is not presented as a Yuen, SciPy, or Moskowitz trading strategy.
Those records support only the robust two-sample location statistic, the WTI
carrier, and the general monthly own-return continuation direction. Every
sample choice, threshold, execution rule, risk control, and lifecycle is
pre-result QM synthesis.

## Supporting evidence and read boundary

### WTI carrier and monthly continuation

`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
records a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`. Its bounded findings include monthly
own-return continuation and explicit NYMEX WTI membership.

The paper does not test fixed adjacent ten-return samples, trimming,
Winsorized scale, a Yuen score, the `0.75` boundary, continuous WTI CFDs, or
the QM lifecycle. No paper return, alpha, Sharpe ratio, drawdown, trade count,
cost result, or WTI-only efficacy transfers.

### Robust unequal-variance trimmed-location method

Karen K. Yuen (1974), "The Two-Sample Trimmed t for Unequal Population
Variances," *Biometrika* 61(1), 165-170, DOI
`10.1093/biomet/61.1.165`, is the named peer-reviewed method record. Oxford
Academic exposes complete bibliographic metadata and the abstract but not the
subscriber article body. The abstract supports only the identity and purpose
of an unequal-variance trimmed two-sample statistic and its robustness study;
no inaccessible derivation, critical table, or result is reconstructed.

The complete public SciPy 1.18.0 `scipy.stats.ttest_ind` method page and its
tag-pinned source were read. They explicitly define tail trimming, the
Winsorized variance, effective trimmed sample size, statistic orientation,
and unequal-variance standard error. Retrieval evidence and exact response
hashes are in `retrieval_route_20260901.json`.

SciPy and Yuen document a statistical comparison, not this trading rule. The
fixed blocks, 20% trim, score boundary, direction mapping, WTI carrier, stop,
risk, and lifecycle below are disclosed pre-result QM choices. The EA has no
SciPy dependency and calculates no p-value or degrees of freedom.

## Locked hypothesis

WTI supply, production, storage, transport, refining, hedging, geopolitical,
and demand adjustments can shift the center of its monthly return
distribution while producing extreme observations. When the latest ten
completed monthly log returns have a sufficiently higher or lower robust
location than the preceding ten under separate Winsorized scales, continue
the direction of that location shift for one broker month.

On the first executable D1 tick of a genuine new broker month:

1. Reconstruct 21 consecutive completed `XTIUSD.DWX` broker-month end closes,
   oldest to newest, excluding every current-month price.
2. Form 20 adjacent chronological log returns `r[0..19]`.
3. Fix `old=r[0..9]` and `recent=r[10..19]`; never search for a split.
4. Sort each block. Delete the two smallest and two largest observations for
   the 20%-trimmed mean of the middle six.
5. Separately Winsorize each full ten-value block: replace indices 0 and 1
   with sorted index 2, and indices 8 and 9 with sorted index 7.
6. Compute each Winsorized variance around its own Winsorized mean with
   divisor five, because effective trimmed size `h=10-2*2=6` and the
   method uses `h-1`.
7. Compute `se2=wvar_old/6+wvar_recent/6` and
   `score=(tmean_recent-tmean_old)/sqrt(se2)`.
8. Buy only when `score>=0.75`; sell only when `score<=-0.75`; otherwise
   remain flat.
9. Persist the month before every fallible gate, risk exactly one
   `RISK_FIXED` budget, attach a frozen `3.5*ATR(20,D1)` hard stop, and exit
   at the next genuine month or the forty-calendar-day stale boundary.

The score magnitude never scales exposure. There is no p-value, theoretical
critical table, fitted split, pooled variance, current-month endpoint,
same-month retry, target, trail, break-even, partial, grid, scale-in,
martingale, or pyramid.

## Exact arithmetic contract

For chronological completed-month closes `C[0..20]`:

```text
for i = 0..19:
    r[i] = log(C[i+1] / C[i])

old    = sort(r[0..9])
recent = sort(r[10..19])
g = 2
h = 6

tmean(x) = sum(x[2..7]) / 6

winsor(x) = [x[2],x[2],x[2],x[3],x[4],x[5],x[6],x[7],x[7],x[7]]
wmean(x)  = sum(winsor(x)) / 10
wvar(x)   = sum((winsor(x)[i]-wmean(x))^2 for i=0..9) / 5

se2   = wvar(old)/6 + wvar(recent)/6
require se2 > 1e-18
score = (tmean(recent)-tmean(old)) / sqrt(se2)

BUY  iff score >=  0.75
SELL iff score <= -0.75
FLAT otherwise
```

All closes, logarithms, returns, sorted values, means, centered differences,
variances, `se2`, square root, and score must be finite. Every completed month
must appear exactly once in chronological order. Degenerate scale, a boundary
miss, malformed history, or arithmetic failure consumes the month flat.

The divisor five is deliberate. It is not the ordinary sample variance of
ten Winsorized observations: the pinned SciPy/Yuen implementation uses
degrees of freedom `h-1` with `h=6` after trimming.

## Non-duplicate boundary

The corrected-root canonical checker scanned 4,763 EA-registry identities,
1,400 card files, and 45 current Strategy Wiki nodes. It found no exact
identity and one expected fuzzy neighbor. Receipt:
`artifacts/qm5_wti_myuen20_shift_tr_preallocation_dedup_20260901.json`,
SHA-256 `8D33C19E0A75BEFCCCDF8778DD44C89A844DAE48E0FCF64E7D37520BD3C26ED7`.

Manual review separates the nearest family:

- `QM5_41249_wti-mwelch-shift-tr` uses twelve returns in raw six/six blocks,
  ordinary means, ordinary unbiased variances with divisor five, and an
  additional recent-mean sign-alignment gate.
- This rule uses twenty returns in ten/ten blocks, deletes four observations
  per block from the location, replaces four observations per block for the
  scale, uses the effective trimmed size six, and follows the robust location
  shift without the `41249` recent-mean gate.
- A fixed 20-return fixture
  `[-5,-0.5,3,0,1,0,-1,0,3,-5 | -1,-5,-2,0,-0.5,1,-3,2,-1,-3]`
  (common scale arbitrary) yields Yuen score about `-1.3862` and sells here,
  while the most-recent twelve-return `QM5_41249` Welch score is about
  `+0.6079` and stays flat.
- Fixture
  `[-0.5,-2,-3,3,2,0.5,-0.5,3,0,-0.5 | 0.5,-1,-3,-3,2,1,5,-5,5,0]`
  yields Yuen score about `-0.1889` and stays flat, while the most-recent
  twelve-return Welch rule scores about `+1.5246` and buys.

The trimmed location/scale state also differs mechanically from
Mann-Whitney ranks (`41176`), KS/Kuiper/Anderson-Darling distribution
distances (`41183`, `41263`, `41260`), CUSUM/Pettitt/Chow split searches
(`41245`, `41172`, `41254`), and Ansari-Bradley/MAD scale rules (`41261`,
`41250`).

Verdict:
`FUZZY_WELCH_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_YUEN20_TRIMMED_LOCATION_UNEQUAL_WINSORIZED_SCALE_SHIFT_CONTINUATION`.

## Reputable-source criteria

- R1: `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE`. One durable AI
  source ID, complete-read peer-reviewed WTI evidence, a named peer-reviewed
  Yuen record with explicit access boundary, and complete official SciPy
  method/source evidence.
- R2: `PASS`. Clock, endpoints, returns, membership, sort, trim, Winsorization,
  variance divisor, denominator, boundary, side, attempt, risk, stop, spread,
  and lifecycle are exact.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 and MT5
  state supply every runtime input; roll, basis, financing, gaps, and broker-
  month labeling remain explicit.
- R4: `PASS`. Deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Claim, kill, and safety boundary

This packet establishes no profitability, statistical significance,
independence, decorrelation, or portfolio fitness. The fixed `0.75` score is
a density-aware pre-result activity boundary, not a Yuen critical value. The
standard centered continuous reference implies roughly five to six boundary
events per twelve attempts before market and execution gates; that is a
design prior only, not a trade-frequency claim.

Q02 kills zero trades, any full post-warm-up year below five completed
positions, nonpositive governed economics, or any implementation defect. Q09
alone owns realized overlap. Failure may not be rescued by changing the
sample size, split, trim, Winsorization, variance divisor, score boundary,
carrier, stop, risk, or hold.

This packet authorizes one card, one branch-only non-live build, strict Q01,
and one paced Q02 handoff if CPU capacity permits. It authorizes no manual
backtest, live/demo/shadow/stress/optimization preset, AutoTrading action,
`T_Live` change, deploy/live manifest, portfolio-gate edit, correlation
waiver, or portfolio admission.
