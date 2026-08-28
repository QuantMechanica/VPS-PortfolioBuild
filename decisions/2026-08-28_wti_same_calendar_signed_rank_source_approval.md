# WTI Same-Calendar Signed-Rank Seasonality — Source Approval

Date: 2026-08-28

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue. Enqueue does not authorize manual tester execution or
work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It asks for one new structural, low-frequency
commodity or energy edge, identifies direct WTI as an acceptable missing
exposure, requires reputable-source criteria and `RISK_FIXED` backtests, and
excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-srank`
- proposed strategy ID:
  `KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026_S01`
- proposed source ID: `KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026`
- proposed symbol / host: exact `XTIUSD.DWX`, D1, slot 0
- decision clock: first executable D1 tick after each genuine broker-month
  transition
- signal: direction of a Wilcoxon-style signed absolute-rank sum over the
  prior five-to-ten valid returns for that same calendar month

The governed allocator owns the EA ID. This source decision neither predicts
nor reserves an ID.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
   It preserves a complete read of Keloharju, Linnainmaa, and Nyberg (2016),
   *Return Seasonalities*, *Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, plus its open NBER working paper. The governed packet
   records explicit crude-oil membership, the same-calendar-month return
   information object, a five-year history floor, and adverse single-CFD and
   futures/CFD translation limits.
2. R Core Team `stats` implementation
   `src/library/stats/R/wilcox.test.R` at repository commit
   `bac583951b728e97b9786804d3b4081f0fe18df5`, blob
   `60eb142e6a6c6a1355d96a881d9464ea017cdf18`, SHA-256
   `669C3DC5B93B8DFA7F1C1ED866725960BA6F34C55E1E0378D3775E8EAA0E3C15`.
   All 1,137 lines were read through the public GitHub API. For a one-sample
   signed-rank statistic it subtracts the location `mu`, ranks absolute
   observations, and defines `V` as the sum of ranks attached to positive
   signed observations.
3. R Core Team manual `src/library/stats/man/wilcox.test.Rd` at the same
   commit, blob `b630339352861e45975540421b408124414bbea8`, SHA-256
   `4B75352AB44829943EF35F0B174D7FA84CF17EFB4F22F1BD6CBA1B09EF0A3E69`.
   All 262 lines were read. It distinguishes the one-sample signed-rank method
   from the two-sample Wilcoxon/Mann-Whitney rank-sum method and fixes the
   one-sample location-null interpretation.

The reproducible retrieval receipt is
`artifacts/qm5_wti_samecal_srank_source_retrieval_20260828.json`. The source
router classified the public GitHub files `ROUTE_GITHUB_API`. It classified
the generic R manual, NBER page, and original-paper DOI routes
`DEFERRED:SOURCE_POLICY`; no blocked content, table, body text, or inferred
result from those routes is used. The original Wilcoxon article body is not
represented as read.

Keloharju et al. do not test this signed-rank single-WTI rule. R Core defines
the statistic but does not claim trading efficacy. The bounded history,
strict no-zero/no-absolute-tie contract, sign-only use of the centered score,
continuous-CFD carrier, fixed-dollar risk, stop, consumed attempt, and
lifecycle are transparent QM falsification choices. No source return,
significance, p-value, hit rate, density, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible entry gate. One
   month may produce at most one consumed attempt.
2. Exclude the current month. For the same calendar month in years `Y-1`
   through `Y-10`, reconstruct the completed log return from the immediately
   preceding month-end close to that historical month-end close. Accept only
   exact adjacent month endpoints under one uniform native or `+1` energy D1
   label normalization. Skip an invalid year without substitution and require
   five to ten valid observations.
3. Require every return finite and nonzero beyond exact epsilon `1e-12` and
   require all absolute returns pairwise distinct beyond the same epsilon.
   These restrictions keep the trading score an exact integer and avoid
   average-rank or zero-handling variants.
4. Rank absolute returns from 1 (smallest) through `n` (largest). Compute
   `V_plus` as the sum of ranks whose original return is positive,
   `T=n(n+1)/2`, and centered signed score `S=2*V_plus-T`.
5. If `S>0`, BUY WTI. If `S<0`, SELL WTI. Exact zero or invalid state consumes
   the month flat. Score magnitude never changes risk.
6. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against one frozen
   `3.5*ATR(20,D1)` hard stop. Attach no target and reject a genuinely positive
   entry spread above 1,500 points.
7. Close on the first tick in a later broker month or after 35 calendar days.
   Immediately repair duplicate, wrong-symbol, wrong-magic, wrong-side,
   invalid-volume, or stopless owned exposure.

There is no p-value, significance threshold, arithmetic mean, sample median,
positive-hit threshold, fixed favorable-month list, recent-return trend,
inventory, event, curve, volume, oscillator, optimizer, or external runtime
series. Both news axes, legacy news mode, and Friday close are OFF.

## Reputable-Source Criteria

- R1 `PASS_WITH_STATISTIC_AND_SINGLE_CFD_TRANSLATION_RISK`: a complete
  peer-reviewed `Journal of Finance` commodity-seasonality packet with
  explicit crude-oil membership plus complete pinned R Core code and manual
  for the operative statistic. The exact conjunction is untested.
- R2 `PASS`: calendar clock, endpoint identity, year bounds, sample floor,
  epsilon, tie rejection, absolute ranks, centered integer score, side,
  attempt, fixed risk, stop, and lifecycle are locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5-native state supplies every runtime input.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, comparisons,
  integer arithmetic, ATR risk controls, and execution state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Pre-Result Density Boundary

The rule consumes one decision each broker month and trades whenever the
valid centered signed-rank score is nonzero. The structural ceiling is twelve
positions per full post-warm-up year and the pre-result operating prior is
ten to twelve, above the unchanged five-trades/year Q02 floor. This is a
design-density bound, not a market probability or performance claim.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,690 registry identities, 1,341
cards, and 45 current Strategy Wiki nodes. It found no exact identity and the
two expected fuzzy neighbors `QM5_20099_wti-samecal` and
`QM5_41055_wti-medcal`. Evidence is
`artifacts/qm5_wti_samecal_srank_preallocation_dedup_20260828.json`, SHA-256
`26CC216D1ED87B6C16F5FFAA51DD53D4D25BFA76798F6792798E447C28EF7DD1`.

Manual semantic review resolves both fuzzy results:

- `QM5_20099` uses the arithmetic mean of five-to-ten same-calendar returns.
  For `[.01,.02,.03,.04,-.20]`, this candidate buys because positive ranks
  sum to 10 against negative rank 5 (`S=5`), while the arithmetic mean is
  negative and `QM5_20099` sells.
- `QM5_41055` uses the ordinary sample median. For six small negative returns
  `[-.01,-.02,-.03,-.04,-.05,-.06]` and four larger positive returns
  `[.07,.08,.09,.10]`, this candidate buys (`V_plus=34`, `T=55`, `S=13`)
  while the median is negative and `QM5_41055` sells.
- `QM5_41059_wti-samecal-hit` uses an asymmetric positive-observation count
  against a fixed hit-rate boundary. For six small positive returns and four
  larger negative returns, the candidate sells (`V_plus=21`, `T=55`,
  `S=-13`) even though positive observations are the majority.
- Fixed-month WTI cards never rank a rolling same-calendar sample. Recent
  WTI rank, slope, change-point, and robust-location cards use contiguous
  recent month ends rather than disjoint historical observations for the
  upcoming calendar month.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback and shares neither the WTI carrier nor this state.

The same-calendar WTI sample, absolute-magnitude ranks, signed rank sum,
strict tie contract, monthly renewal, and direct WTI carrier are jointly load
bearing. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_RENEWAL`.

## Kill And Safety Boundary

Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades, with nonpositive governed economics, or on any month,
endpoint, sample, zero/tie, rank, score, side, attempt, fixed-risk, stop,
lifecycle, or determinism defect. No failed result may be rescued by changing
the sample, statistic, epsilon, carrier, direction, risk, hold, spread cap,
or by adding another gate.

Direct WTI supplies crude-oil exposure absent from the stated
XAU/SP500/NDX/XNG book, but it does not prove factor or portfolio
decorrelation. Unchanged Q09 alone owns realized overlap. This approval
excludes manual backtests; live, demo, shadow, stress, and optimization
setfiles; AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and terminal control.
