# WTI Monthly Welch Mean-Shift Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded WTI structural-trend Strategy
Card, deterministic EA-ID and one-slot magic allocation, one branch-only
non-live build, strict Q01 validation, and one paced Q02 enqueue only while
the governed whole-host CPU ceiling remains clear. This decision does not
authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, reputable-source criteria, a `RISK_FIXED`
backtest preset, committed non-duplicate work, and one paced Q02 handoff. It
forbids live, AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate identity

- proposed slug: `wti-mwelch-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MWELCH-20260831_S01`
- source ID: `AI-CODEX-WTI-MWELCH-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: fixed older/recent blocks of six adjacent monthly WTI log returns,
  unequal-variance standardized mean shift, and recent-mean sign alignment
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and supporting evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/source.md`. The canonical
R1 rule in `processes/qb_reputable_source_criteria.md` expressly permits an
AI-originated strategy when its prompt/output trail, claim boundary, and one
source ID are durable.

The packet was synthesized only after reading the complete governed WTI
source `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
That packet records a complete 23-page read of Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI
membership and monthly own-return continuation findings.

The method boundary was verified against two primary public records on
2026-08-31:

- B. L. Welch (1938), "The Significance of the Difference Between Two Means
  When the Population Variances Are Unequal," *Biometrika* 29(3-4), 350-362,
  DOI `10.1093/biomet/29.3-4.350`. Oxford Academic exposed complete
  bibliographic metadata but not the article body; no inaccessible formula,
  critical value, table, or claim is imported.
- SciPy 1.18.0 official `scipy.stats.ttest_ind` documentation and tag-pinned
  public source. The documentation identifies `equal_var=False` as Welch's
  unequal-variance form and fixes the statistic orientation as an arithmetic-
  mean difference divided by standard error.

The reproducible access record is
`strategy-seeds/sources/AI-CODEX-WTI-MWELCH-20260831/retrieval_route_20260831.json`.
The Welch and SciPy records support method identity and arithmetic only; they
do not become additional card source IDs.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized broker-month key before history, signal, news,
   spread, quote, stop, sizing, margin, or order checks. Never retry the same
   month.
2. Reconstruct thirteen consecutive completed WTI broker-month end closes,
   oldest to newest, and form twelve adjacent log returns `r[0..11]`.
3. Fix `old=r[0..5]` and `recent=r[6..11]`. Calculate each arithmetic mean
   and unbiased sample variance using denominator five.
4. Calculate
   `se2 = var_old/6 + var_recent/6` and
   `score = (mean_recent - mean_old)/sqrt(se2)`.
   Require finite arithmetic and `se2 > 1e-18`.
5. Buy only when `score >= 0.75` and `mean_recent > 1e-12`. Sell only when
   `score <= -0.75` and `mean_recent < -1e-12`. Every other state consumes
   the month flat. Score magnitude never scales risk.
6. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread
   ceiling.
7. Close at the next genuine broker month or after forty calendar days.
   Both news axes and Friday close remain off so the month hold is not
   rewritten into weekly packages.

This is a fixed-block trading translation of an unequal-variance mean score,
not a significance test. It calculates no p-value or degrees of freedom. The
samples, threshold, sign alignment, carrier, risk, stop, and lifecycle are
pre-result QM choices.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY`: exactly one durable
  AI-originated source ID, a complete-read peer-reviewed WTI trading packet,
  a named peer-reviewed Welch record, and complete official public SciPy
  method documentation are preserved. No inaccessible source efficacy is
  imported.
- R2 `PASS`: month clock, endpoints, return orientation, fixed samples,
  means, unbiased variances, standard error, threshold, side, attempt, risk,
  hard stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 execution state supply every runtime input.
  Futures-to-CFD, roll, financing, gap, and broker-month-label risks remain.
- R4 `PASS`: timestamps, completed prices, logarithms, finite sums, means,
  variances, comparisons, ATR risk control, and native position/deal state
  only; no ML, trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The corrected-root canonical receipt
`artifacts/qm5_wti_mwelch_shift_tr_preallocation_dedup_20260831.json`,
SHA-256 `418F80E037B15060AA00B11736783446818B7AAA892B49EF9C9F9A95B0777D67`,
scanned 4,748 registry identities, 1,386 card files, and 45 Strategy Wiki
nodes. It returned `CLEAN` with no exact or fuzzy match.

Manual mechanic review fixes the semantic boundary:

- `QM5_41176_wti-mwilcoxon-shift-tr` counts 36 cross-block wins among
  monthly price levels; this candidate uses adjacent monthly returns,
  magnitude-bearing means, and two separate sample variances.
- `QM5_41183_wti-mks-shift-tr` keeps a maximum signed ECDF count gap among
  price levels; this candidate has no rank, sort, or ECDF state.
- `QM5_41184_wti-mww-runs-shift-tr` counts pooled sample-label runs; this
  candidate has no run count or label sequence.
- `QM5_41137_wti-mmedian-shift-mom` compares daily log-price medians in two
  adjacent months; this candidate compares twelve completed monthly returns
  split into fixed half-years.
- `QM5_41245_wti-mcusum-shift-tr` searches eleven return splits and requires
  a unique central maximum; this candidate fixes one six/six split and uses
  an unequal-variance denominator.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly direct-WTI mean-shift rule.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_WELCH_RETURN_MEAN_SHIFT_ALIGNED_CONTINUATION`.

## Kill and safety boundary

The fixed score boundary admits at most twelve entries/year and is expected
to produce roughly five to eight completed positions/year before execution
gates; that is a design prior, not test evidence. Q02 retires the unchanged
baseline on zero positions, fewer than five positions in any full scored
post-warm-up year, nonpositive governed economics, future leakage, wrong
return orientation, wrong variance denominator, degenerate standard error,
boundary or sign-alignment error, missing stop, invalid risk mode, malformed
lifecycle, or nondeterminism. Failure may not be rescued by changing the
sample, split, threshold, sign alignment, stop, or hold.

WTI supplies physical crude-oil exposure absent from the certified book, but
this approval does not assert realized independence. Q09 alone may evaluate
portfolio overlap.

This approval excludes a manual backtest; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers.
