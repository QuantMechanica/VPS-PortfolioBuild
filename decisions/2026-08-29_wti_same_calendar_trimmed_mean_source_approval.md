# WTI Five-Year Same-Calendar Trimmed-Mean Seasonality - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its CPU ceiling.
Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified
XAU/SP500/NDX/XNG book, names direct WTI as an acceptable missing exposure,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-trim5`
- proposed strategy ID: `KELOHARJU-TRIM-WTI-SAMECAL5-2026_S01`
- proposed source ID: `KELOHARJU-TRIM-WTI-SAMECAL5-2026`
- carrier / host: exact `XTIUSD.DWX`, D1, slot 0
- clock: first executable D1 tick after each genuine broker-month transition
- state: exact prior-five-year returns for the upcoming calendar month,
  sorted with one observation removed from each tail and the middle three
  averaged
- lifecycle: follow the strict trimmed-mean sign until the next broker month

The governed allocator owns the EA ID. This source decision neither predicts
nor reserves an ID.

## Approved Source Basis

The following bounded repository packets were read completely before this
decision. Their reproducible read receipt is
`artifacts/qm5_wti_samecal_trim5_source_provenance_20260829.json`.

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
   It preserves a complete review of Keloharju, Linnainmaa, and Nyberg
   (2016), *Return Seasonalities*, *Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`, and its open 57-page NBER version. The record
   explicitly includes crude oil in the 24-futures commodity panel, fixes
   historical returns from the same calendar month as the information
   object, and records the source's five-year eligibility floor.
2. `strategy-seeds/sources/MOP-WTI-TRIMMEAN-2026/source.md`, SHA-256
   `63F8C5FC06BAE2D90B50673C6B7B966FBAF5962150D70F695DD3DA8DBB221FA8`.
   It preserves a peer-reviewed WTI time-series-momentum lineage and exact
   governed arithmetic for sorting a bounded return sample, removing fixed
   observations from both tails, and averaging only the retained center.

Keloharju et al. use an arithmetic average in a broad cross-sectional futures
portfolio. The second packet uses a trimmed mean of contiguous recent WTI
returns. Neither source tests this exact five-observation same-calendar
trimmed mean, its standalone continuous-CFD carrier, fixed cash risk, or the
QM book. The five-year fixed sample and one-observation-per-tail trim are
transparent, pre-result QM translations. No source return, coefficient,
significance, hit rate, density, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition in year `Y` and calendar month `M`:

1. Process prior-position lifecycle repair, then persist the current broker
   `yyyymm` before history, signal, news, spread, quote, ATR, sizing, margin,
   or order gates. No flat, rejected, failed, stopped, or restarted outcome
   may retry in the same month.
2. Under exactly one uniform native or `+1` energy D1-label convention,
   reconstruct the completed WTI log return for calendar month `M` in each
   exact year `Y-1` through `Y-5` as
   `r[y] = ln(month_end_close / prior_month_end_close)`.
3. Require all five exact years. Each target-month endpoint must be the final
   normalized D1 close in `(y,M)`, its immediately preceding D1 bar must
   normalize into the immediately preceding calendar month, and a following
   D1 bar must normalize into the immediately following calendar month. No
   missing year may be skipped or replaced.
4. Require five finite returns, copy them, sort ascending, discard exact
   indexes `0` and `4`, and compute
   `trimmed_mean = (sorted[1] + sorted[2] + sorted[3]) / 3`.
5. BUY when `trimmed_mean > +1e-12`, SELL when
   `trimmed_mean < -1e-12`, and consume the month flat otherwise. Signal
   magnitude never changes risk.
6. Open at most one WTI position under `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, sized against one frozen
   `3.5*ATR(20,D1)` broker hard stop. Attach no target and reject a genuinely
   positive entry spread above 1,500 points.
7. Close on the first tick in a later broker month or after 35 elapsed
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no full-sample mean fallback, median fallback, signed rank, hit-rate gate,
fixed favorable-month list, current-month return, recent trend, inventory,
event, curve, volume, oscillator, optimizer artifact, or external runtime
series.

## Reputable-Source Criteria

- R1 `PASS_WITH_FIXED_SAMPLE_AND_TRIM_TRANSLATION_RISK`: complete
  peer-reviewed *Journal of Finance* same-calendar commodity evidence with
  explicit crude-oil membership plus a complete governed peer-reviewed WTI
  trimmed-arithmetic packet. The exact conjunction is explicitly untested.
- R2 `PASS`: label normalization, exact years and endpoints, five-observation
  requirement, sort, deleted indexes, retained indexes, divisor, sign band,
  attempt, fixed risk, stop, spread, and lifecycle are locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5-native state supply every runtime field.
  The five-prior-year requirement is a binding warm-up risk.
- R4 `PASS`: timestamps, logarithms, sorting, finite arithmetic, comparisons,
  ATR risk controls, and native execution state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Pre-Result Density Boundary

After five exact prior years exist, the rule consumes one decision each broker
month and trades whenever the trimmed mean is outside the exact tie band. Its
structural ceiling is twelve positions per full post-warm-up year and the
pre-result operating prior is ten to twelve. That clears the unchanged
five-trades/year design floor but is not a market probability or performance
claim.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,698 registry identities, 1,344
cards, and all 45 current Strategy Wiki nodes. It found no exact identity and
only the expected fuzzy same-calendar mean neighbor `QM5_20099_wti-samecal`.
Receipt:
`artifacts/qm5_wti_samecal_trim5_preallocation_dedup_20260829.json`, SHA-256
`B21C3BDECE4F7A0A6DCA751095C43FC0B3480DA8DA59CB7629450EE6033AB794`.

Manual family review establishes functional non-equivalence:

- `QM5_20099` averages the complete same-calendar sample. For sorted returns
  `[-.30,-.04,-.03,.08,.09]`, its full mean is `-.04` and sells, while this
  rule drops `-.30` and `.09`, averages `[-.04,-.03,.08]` to
  `+.003333...`, and buys.
- `QM5_41055_wti-medcal` uses only the central order statistic. The same
  vector has median `-.03` and sells while this rule buys.
- `QM5_41191_wti-samecal-srank` weights signs by absolute ranks. On the same
  vector its centered signed-rank score is `-1` and sells while this rule
  buys.
- `QM5_41059_wti-samecal-hit` counts positive observations against a fixed
  boundary. For `[-.30,-.04,.01,.02,.03]`, three of five returns are positive
  and its hit-rate state is favorable, while this rule averages
  `[-.04,.01,.02]` to `-.003333...` and sells.
- `QM5_20270_wti-trimmean-mom` uses twelve contiguous recent monthly returns,
  removes two from each tail, and follows the middle eight. This candidate
  uses five disjoint observations from the upcoming calendar month in the
  exact prior five years, removes one from each tail, and follows the middle
  three. The information object, sample, retained set, and seasonal clock all
  differ.
- Fixed-month WTI systems never recompute a rolling cross-year robust
  estimator, while certified `QM5_12567_cum-rsi2-commodity` is a short-horizon
  long-only XNG oscillator pullback.

The exact five historical calendar years, disjoint same-month return state,
one-tail deletion, middle-three mean, direct WTI carrier, and monthly renewal
are jointly load bearing. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_MIDDLE_THREE_TRIMMED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Kill And Safety Boundary

Q02 must retire at zero trades, below five completed positions in any full
post-warm-up year, with nonpositive governed economics, or on any label,
month, endpoint, exact-year, sample-count, sort, tail-deletion, retained-sum,
divisor, sign, attempt, fixed-risk, stop, lifecycle, or determinism defect. No
failed result may be rescued by changing the years, allowing replacement,
changing the trim, adding a filter, or altering direction, risk, hold, spread,
or retry rules.

Direct WTI supplies crude-oil exposure absent from the stated certified book,
but this record does not prove factor or portfolio decorrelation. Unchanged
Q09 alone owns realized overlap. This approval excludes manual backtests;
live, demo, shadow, stress, and optimization setfiles; terminal control;
AutoTrading; `T_Live`; deploy or live manifests; portfolio-gate changes;
portfolio admission; correlation waivers; and any live-use claim.
