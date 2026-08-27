# WTI Monthly Mann-Whitney Location-Shift Trend - Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize tester dispatch or
work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge outside the directional XAU/SP500/NDX/XNG book,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `wti-mwilcoxon-shift-tr`
- proposed strategy ID: `MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026_S01`
- proposed source ID: `MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: continue a strict fixed six-older versus six-newer completed-month
  WTI Mann-Whitney location shift at `U_new>=24` or `U_new<=12`

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves complete-paper Moskowitz-Ooi-Pedersen time-series-momentum
   evidence, explicit NYMEX WTI membership, and monthly renewal.
2. H. B. Mann and D. R. Whitney (1947), "On a Test of Whether one of Two
   Random Variables is Stochastically Larger than the Other," *The Annals of
   Mathematical Statistics* 18(1), 50-60, DOI
   `10.1214/aoms/1177730491`. Crossref confirms the bibliographic identity;
   the article body is not represented as completely read because the
   deterministic router classified the publisher route
   `DEFERRED:SOURCE_POLICY`.
3. The complete R Core Team `stats::wilcox.test` source and manual at public
   `wch/r-source` commit
   `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. The router selected the
   GitHub API and both pinned files were read completely. They define the
   operative two-sample statistic as combined rank sum less the minimum rank
   sum and document its equivalent pair-count interpretation. Exact evidence
   is in
   `strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/retrieval_route_20260827.json`.
4. The governed composite packet
   `strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`.

The records support a falsifiable monthly WTI continuation experiment and the
exact ordinal two-sample statistic, not the proposed trading conjunction. The
twelve endpoints, six/six split, boundaries, continuous-CFD mapping,
fixed-dollar risk, stop, attempt state, and lifecycle are disclosed QM
hypotheses.

No source return, alpha, probability, significance, Sharpe ratio, density,
drawdown, transaction cost, WTI-only result, CFD equivalence, decorrelation,
or portfolio-correlation statistic transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist current broker `yyyymm` as consumed before every fallible gate.
2. Reconstruct the latest D1 close from exactly twelve immediately prior,
   consecutive completed broker months; reject ties and malformed history.
3. Split once after observation six. Count all 36 strict comparisons of newer
   versus older endpoints and prove `U_new + U_old = 36`.
4. Buy only at `U_new>=24`, sell only at `U_new<=12`, and otherwise consume
   the month flat. No p-value, variable split, maximum search, or fallback
   exists.
5. Use one position, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
   1,500-point entry-spread ceiling.
6. Close at the next broker-month transition or after forty calendar days and
   repair invalid owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. Exact enumeration
of the 924 no-tie six-rank assignments yields 364 qualifying assignments, or
4.727 decisions per twelve opportunities. This is a pre-result density design
fact, not a significance or WTI-performance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence, a named peer-reviewed Mann-Whitney
  record, and complete pinned R Core method files; exact conjunction untested.
- R2 `PASS`: clock, month selection, fixed blocks, tie rule, pair-count
  identity, boundaries, side, attempt, risk, stop, and lifecycle are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 plus MT5
  state supplies every runtime input.
- R4 `PASS`: deterministic comparisons and native state only; no trained
  output, banned signal method, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,675 EA-registry rows, 1,326 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_mwilcoxon_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`C2F817B5CFAE47788BC8261553D32855191869912B8438858E90EB3CAEA17640`.

Manual functional review fixes a new statistic, not a renamed horizon:

- `QM5_20264_wti-rank-trend` counts all ordered pairs over thirteen endpoints;
  this rule counts only cross-block pairs at one fixed split in the latest
  twelve endpoints.
- `QM5_41172_wti-mpettitt-shift-tr` searches all splits for a unique dominant
  central rank-sum change point; this rule never searches or maximizes.
- `QM5_41173_wti-mspearman-tr` scores exact price-rank displacement from time
  rank; this rule is invariant to ordering inside each fixed block.
- `QM5_41137_wti-mmedian-shift-mom` compares daily observations in two
  adjacent months; this rule compares twelve completed monthly endpoints.
- Fixed thirteen-rank paths in the source packet prove candidate/neighbor
  disagreements, including opposite candidate/Pettitt decisions.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly WTI rank-location trend.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed WTI positions per full
post-warm-up year. Q02 must retire below four in any full year, at zero trades,
with nonpositive governed economics, or on any month, endpoint, split, tie,
pair count, threshold, side, attempt, risk, lifecycle, or determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns overlap. No failed result may be rescued by changing the sample, split,
tie rule, boundary, direction, risk, hold, or by adding another filter.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
