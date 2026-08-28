---
source_id: KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026
title: WTI same-calendar-month signed absolute-rank seasonality extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research and pinned R Core statistical code
source_type: peer_reviewed_and_primary_software_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md
parent_source_ids:
  - KELOHARJU-RETSEAS-2016
parent_sha256:
  KELOHARJU-RETSEAS-2016: 54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0
created: 2026-08-28
created_by: Research+Development
cards_extracted:
  - wti-samecal-srank
---

# WTI Same-Calendar-Month Signed Absolute-Rank Source Packet

## Approval And Retrieval Boundary

The durable approval is
`decisions/2026-08-28_wti_same_calendar_signed_rank_source_approval.md`,
committed as `62ee0c240` before this extraction. Its reproducible retrieval
receipt is
`artifacts/qm5_wti_samecal_srank_source_retrieval_20260828.json`.

The trading parent is
`strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
`54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
That OWNER-approved complete-read packet records Keloharju, Linnainmaa, and
Nyberg (2016), *Return Seasonalities*, *Journal of Finance* 71(4), 1557-1590,
DOI `10.1111/jofi.12398`, and its open NBER working paper. It records crude
oil inside the paper's 24-futures commodity panel, historical returns from
the same calendar month as the operative information object, and a minimum
five-year history requirement.

The statistical source of record is the R Core Team `stats` implementation
at public `wch/r-source` commit
`bac583951b728e97b9786804d3b4081f0fe18df5`:

- `src/library/stats/R/wilcox.test.R`, blob
  `60eb142e6a6c6a1355d96a881d9464ea017cdf18`, 42,614 bytes, 1,137 lines,
  SHA-256
  `669C3DC5B93B8DFA7F1C1ED866725960BA6F34C55E1E0378D3775E8EAA0E3C15`;
- `src/library/stats/man/wilcox.test.Rd`, blob
  `b630339352861e45975540421b408124414bbea8`, 12,273 bytes, 262 lines,
  SHA-256
  `4B75352AB44829943EF35F0B174D7FA84CF17EFB4F22F1BD6CBA1B09EF0A3E69`.

Both pinned files were read completely through the public GitHub API after
the deterministic source router returned `ROUTE_GITHUB_API`. The router
returned `DEFERRED:SOURCE_POLICY` for the generic R manual, NBER page, and
original-paper DOI routes. No content, result, table, or inference from those
blocked routes appears here. The original Wilcoxon article body is not
represented as read.

## Source Findings Used

The Keloharju parent supports a falsifiable same-calendar-month commodity
return experiment and explicit crude-oil membership. It uses a broad
cross-sectional futures ranking based on historical arithmetic-average
returns. It does not test a direct WTI signed-rank rule.

The pinned R Core implementation fixes the operative one-sample arithmetic:

```text
x <- x - mu
r <- rank(abs(x))
V <- sum(r[x > 0])
```

The manual distinguishes this one-sample signed-rank statistic from the
two-sample rank-sum/Mann-Whitney statistic. The EA uses only the signed rank
statistic at `mu=0`; it computes no p-value, significance claim, confidence
interval, or location estimate.

The records do not establish that weighting same-calendar WTI return signs by
their within-sample absolute ranks predicts WTI. The bounded history, direct
CFD carrier, zero and absolute-tie rejection, sign-only direction, fixed risk,
stop, spread ceiling, consumed attempt, and lifecycle are explicit QM
choices. No source return, alpha, p-value, probability, density, drawdown,
cost, CFD equivalence, decorrelation, or portfolio statistic transfers.

## Exact Statistical Contract

For `n` valid historical log returns from the target calendar month, where
`5 <= n <= 10`, let `r[k]` be the completed WTI return from the immediately
preceding month-end close to the target historical month-end close.

Require:

- every return is finite;
- `abs(r[k]) > 1e-12` for every observation;
- every pair of absolute returns differs by more than `1e-12`; and
- no invalid historical year is substituted by a year outside `Y-1..Y-10`.

Assign strict integer ranks `a[k]` from 1 for the smallest `abs(r[k])` to `n`
for the largest. Define:

```text
V_plus = sum(a[k] for every r[k] > 0)
T      = n*(n+1)/2
S      = 2*V_plus - T

require sum(all ranks) == T
require -T <= S <= T

BUY  iff S > 0
SELL iff S < 0
FLAT iff S == 0 or any contract check fails
```

The centered form is equivalent to positive-rank sum minus negative-rank
sum. It is used only as a direction score. Magnitude never changes position
size. Exact epsilon zeros and absolute ties consume the month flat rather
than selecting a Wilcoxon/Pratt zero convention or average ranks.

## Locked Calendar Translation

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Normalize the D1 session label under exactly one convention: native
   same-day labels or a uniform `+1` calendar-day energy offset. The normalized
   current D1 date must equal the current broker date. The same offset applies
   to every historical endpoint.
2. Persist the current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order gates. Never retry the month after a
   flat score, malformed history, rejection, stop, or restart.
3. For the target month `M` in each exact historical year `H=Y-1..Y-10`,
   select the final D1 close in `(H,M)` and the immediately preceding D1 bar's
   close. Require that preceding bar to normalize into the immediately
   preceding calendar month and require a following D1 bar in the immediately
   next calendar month so the historical target month is complete.
4. Form `r(H,M)=ln(end_close/pre_close)`. Skip an invalid year without
   substitution. Require five to ten valid observations.
5. Apply the exact signed absolute-rank contract. Buy on positive `S`, sell on
   negative `S`, and consume exact zero or invalid state flat.
6. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen
   `3.5*ATR(20,D1)` broker hard stop. Attach no target and reject a genuinely
   positive entry spread above 1,500 points.
7. Close on the first tick in a later broker month or after 35 elapsed
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 OHLC/timestamps, broker time, quotes, contract metadata,
positions, deals, terminal global variables, and V5 framework services.

## Pre-Result Density Boundary

The rule consumes one decision each broker month and trades whenever the
valid centered score is nonzero. Its structural ceiling is twelve positions
per full post-warm-up year. The pre-result operating prior is ten to twelve,
above the unchanged five-trades/year Q02 floor. This is a design-density
bound; it is not a WTI probability or performance result.

## Non-Duplicate Functional Boundary

The fail-closed canonical checker scanned 4,690 registry identities, 1,341
card files, and 45 Strategy Wiki nodes. It found no exact identity and two
expected fuzzy matches. Receipt:
`artifacts/qm5_wti_samecal_srank_preallocation_dedup_20260828.json`.

The following fixed fixtures prove that the state functions are not
interchangeable:

- Existing `QM5_20099_wti-samecal` uses an arithmetic mean. On
  `[.01,.02,.03,.04,-.20]`, the candidate has `V_plus=10`, `T=15`, `S=5` and
  buys; the mean is negative and 20099 sells.
- Existing `QM5_41055_wti-medcal` uses an ordinary sample median. On
  `[-.01,-.02,-.03,-.04,-.05,-.06,.07,.08,.09,.10]`, the candidate has
  `V_plus=34`, `T=55`, `S=13` and buys; the median is negative and 41055
  sells.
- Existing `QM5_41059_wti-samecal-hit` counts positive observations against a
  fixed asymmetric hit boundary. On
  `[.01,.02,.03,.04,.05,.06,-.07,-.08,-.09,-.10]`, the candidate has
  `V_plus=21`, `T=55`, `S=-13` and sells even though six of ten returns are
  positive.
- Fixed-month WTI cards never rank a rolling same-calendar sample. Recent
  WTI rank, slope, change-point, and location systems use a contiguous recent
  path rather than disjoint observations from the upcoming month in prior
  years.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback, with neither this carrier nor this information object.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_RENEWAL`.

## Reputable-Source Criteria

- R1 `PASS_WITH_STATISTIC_AND_SINGLE_CFD_TRANSLATION_RISK`: complete
  peer-reviewed commodity-seasonality lineage with explicit crude-oil
  membership plus complete pinned R Core source and manual for the statistic.
- R2 `PASS`: calendar, endpoints, year bounds, sample floor, zero/tie rule,
  ranks, score, side, attempt, risk, stop, and lifecycle are deterministic and
  locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` D1 history and native MT5 state supply every runtime field.
- R4 `PASS`: timestamps, logarithms, sorting, comparisons, integer arithmetic,
  ATR risk controls, and execution state only; no trained signal, banned
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Falsification And Safety Boundary

Retire or fail on any month-selection, endpoint, normalization, sample,
zero/tie, rank, invariant, score, side, attempt, fixed-risk, stop, lifecycle,
or determinism defect; fewer than five completed positions in any full post-
warm-up year; zero trades; nonpositive governed economics; or downstream
portfolio-correlation rejection. No failed result may be rescued by changing
the sample, statistic, epsilon, direction, risk, hold, spread cap, or adding a
filter.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this source packet does not prove low realized correlation. Q09
alone owns overlap. This packet authorizes no manual backtest, live/demo/
shadow preset, AutoTrading, `T_Live`, deploy or live manifest, portfolio-gate
change, portfolio admission, correlation waiver, terminal control, or tester
dispatch.
