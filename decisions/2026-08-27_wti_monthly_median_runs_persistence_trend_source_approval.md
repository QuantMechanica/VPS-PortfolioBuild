# WTI Monthly Median-Runs Persistence Trend — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize tester dispatch or
work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity/energy edge, expressly permits a
structural `XTIUSD` trend edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-median-runs-tr`
- proposed strategy ID: `MOP-NIST-WTI-MEDRUN-TREND-2026_S01`
- proposed source ID: `MOP-NIST-WTI-MEDRUN-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: continue the newest completed month-end's above/below-sample-median
  regime only when the thirteen-endpoint formation has at most seven runs
  after omitting its unique median

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves a complete-paper review of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), DOI
   `10.1016/j.jfineco.2011.11.003`, including monthly continuation, monthly
   renewal, and explicit NYMEX WTI membership.
2. The official NIST/SEMATECH e-Handbook section 1.3.5.13, "Runs Test for
   Detecting Non-randomness," at
   `https://www.itl.nist.gov/div898/handbook/eda/section3/eda35d.htm`. The
   complete page defines above/below-median coding, consecutive same-sign
   runs, observed run count, and expected-run arithmetic. Retrieval evidence
   is
   `strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/retrieval_route_20260827.json`,
   SHA-256
   `9ACBE3A27118ABDF934FDD0EA75C4C1FFF52378BF7528271C0C751FB0531D374`.
3. The complete governed composite packet
   `strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/source.md`.

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. NIST supplies the operative median/runs method. No
source tests this exact thirteen-endpoint trading conjunction. The threshold,
newest-regime direction, continuous-CFD mapping, fixed risk, stop, attempt,
and lifecycle are disclosed QM choices.

No source return, alpha, probability, significance, trade density, Sharpe
ratio, drawdown, cost, CFD equivalence, decorrelation, or portfolio statistic
transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate.
2. Reconstruct the latest D1 close from exactly thirteen immediately prior
   consecutive completed broker months; reject ties and malformed history.
3. Assign strict ranks 1..13, omit unique median rank 7, map the remaining six
   lower ranks to `-1` and six upper ranks to `+1`, and count chronological
   same-sign runs `R` in the resulting twelve-element sequence.
4. Buy only when `R<=7` and the newest actual endpoint rank is above 7; sell
   only when `R<=7` and it is below 7. If `R>7` or the newest rank equals 7,
   consume the month flat. No p-value or fallback exists.
5. Use one position, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
   1,500-point spread ceiling.
6. Close at the next broker-month transition or after forty calendar days;
   immediately repair invalid owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. For six signs on
each side, the official expected-run formula equals seven; the inclusive gate
is not represented as a significance threshold. Exact enumeration gives
qualification rate `562/1001`, about 6.737 monthly opportunities per random-
order year. This is a pre-result density fact, not market evidence.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence and a complete official NIST method
  page; exact conjunction untested.
- R2 `PASS`: clock, endpoints, ranks, median omission, six/six balance, run
  count, threshold, direction, consumed attempt, risk, stop, and lifecycle
  are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 history
  and MT5 state supply every runtime input.
- R4 `PASS`: native comparisons, ranks, signs, counts, calendar, ATR risk, and
  execution state only; no ML, banned signal, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The first checker invocation failed closed because its legacy default Wiki
root no longer exists; no allocation followed it. The corrected invocation
explicitly bound the current Company Reference vault and returned `CLEAN`
after scanning 4,681 registry identities, 1,332 cards, and 45 Wiki nodes.
Evidence is
`artifacts/qm5_wti_median_runs_tr_preallocation_dedup_20260827.json`.

This is not `QM5_20273_wti-signrun-tr`: that EA counts longest consecutive
positive/negative returns, whereas this rule counts every transition in a
price-level sequence dichotomized around its own sample median. It also
differs functionally from all-pairs Mann-Kendall, adjacent squared-rank
Bartels, local turning-point, and time-rank Spearman systems. Fixed rank
vector `[10,3,8,5,1,11,7,12,9,13,2,6,4]` sells here at six runs while those
five named neighbors are all flat; vector
`[5,6,9,12,4,8,3,11,2,1,7,13,10]` is flat here at eight runs while Bartels
and turning-point persistence buy.

Verdict:
`CLEAN_WTI_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_REGIME_CONTINUATION`.

## Kill And Safety Boundary

Q02 retires the locked candidate at zero trades, below five completed
positions in any full post-warm-up year, with nonpositive governed economics,
or on any endpoint, rank, median, balance, run, threshold, side, attempt,
risk, lifecycle, or determinism defect. No failed result may be rescued by
changing the sample, threshold, direction, carrier, risk, hold, or by adding
a filter.

Direct WTI exposure adds a crude-oil driver absent from the stated
XAU/SP500/NDX/XNG book, but does not prove low realized correlation. Unchanged
Q09 owns overlap. This approval excludes manual backtests; live, demo,
shadow, stress, and optimization setfiles; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; correlation
waivers; terminal control; and a second queue row. Q02 may be enqueued once
only after a current strict compile/review PASS and only below the factory CPU
ceiling.
