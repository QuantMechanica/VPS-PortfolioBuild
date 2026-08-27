# WTI Monthly Wald-Wolfowitz Label-Runs Shift Trend — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize tester dispatch or
work at or above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`. It requests one genuinely different structural,
low-frequency commodity/energy edge, permits direct `XTIUSD` trend or
seasonality, requires reputable-source criteria and a `RISK_FIXED` backtest
preset, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-mww-runs-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-M2RUNS-20260827_S01`
- source ID: `AI-CODEX-WTI-M2RUNS-20260827`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: continue the newer fixed five-month block's median direction only
  when pooled old/new labels form at most five runs

The governed deterministic allocator owns the EA ID. This decision neither
reserves nor predicts one.

## Approved Source Basis

The single lineage source is the complete governed AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-M2RUNS-20260827/source.md`, SHA-256
`AB4B8ADE3D3E4B4CA1B7AE6D9ADE98DD69AD30BC5D5CEDEC0EC6F9D073795FB6`.
Canonical R1 expressly permits an AI source when its prompt/output trail and
mechanization boundary are captured.

Supporting evidence is bounded as follows:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   preserves a complete-paper review of peer-reviewed monthly own-price
   continuation and explicit WTI membership.
2. Wald and Wolfowitz (1940), "On a Test Whether Two Samples Are from the
   Same Population," *The Annals of Mathematical Statistics* 11(2),
   147-162, DOI `10.1214/aoms/1177731909`, is retained as peer-reviewed
   bibliographic metadata only.
3. The mandatory runtime reader classified the DOI
   `DEFERRED:SOURCE_POLICY`. Receipt:
   `strategy-seeds/sources/AI-CODEX-WTI-M2RUNS-20260827/retrieval_route_20260827.json`.
   No complete read, inaccessible method detail, or source alpha is claimed.

The exact fixed-block label-runs trade is a disclosed Codex synthesis under
the OWNER mission. No source return, alpha, probability, critical value,
significance, trade density, Sharpe ratio, drawdown, cost, CFD equivalence,
decorrelation, or portfolio statistic transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate.
2. Reconstruct exactly ten immediately prior consecutive completed
   broker-month end closes; reject malformed, nonpositive, nonfinite, or tied
   values.
3. Fix `O=C[0..4]` and `N=C[5..9]`. Pool and sort all values ascending while
   retaining their fixed block labels. Count `R=1+adjacent label changes`.
4. Qualify only when `R<=6`. Buy when the exact five-value newer median is
   above the older median; sell when it is below. Otherwise consume flat.
   There is no p-value, lookup table, fallback, or adaptive threshold.
5. Use one position, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
   1,500-point spread ceiling.
6. Close at the next genuine broker-month transition or after forty calendar
   days; immediately repair invalid owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Exact enumeration
gives 162 qualifying assignments among 252 strict fixed five/five label
orders, split symmetrically into 81 long and 81 short states. The random-rank
density prior is `12*162/252 = 7.7143` decisions/year. This is neither a
market result nor a significance claim.

An exhaustive pre-build check corrected a transcription error in the run
table and the resulting locked boundary from five to six before compilation,
Q01, Q02, or market-result observation. The one-time correction and its
fail-closed rationale are recorded in
`decisions/2026-08-27_qm5_41184_prebuild_density_correction.md`.

## Reputable-Source Criteria

- R1 `PASS_WITH_PUBLIC_METHOD_ACCESS_LIMITATION`: one permitted AI-originated
  governed source ID, a transparent public-access defer, a peer-reviewed
  method bibliography, and complete-read peer-reviewed WTI carrier support.
- R2 `PASS`: clock, endpoints, fixed blocks, ties, pooled sort, label runs,
  boundary, medians, side, consumed attempt, risk, stop, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 history
  and MT5 state supply every runtime input.
- R4 `PASS`: native sorting, comparisons, integer counts, calendar, ATR risk,
  and execution state only; no trained output, prohibited signal, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical invocation explicitly bound the current Company
Reference vault and returned `CLEAN` after scanning 4,683 registry identities,
1,334 cards, and 45 Wiki nodes. Evidence:
`artifacts/qm5_wti_mww_runs_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`88D3A10D84ECB5C876FA9916F24234DA802EDEB8AFA1A8D0805B2EC387EC27B1`.

The pooled membership-run count is distinct from `QM5_41182`'s chronological
above/below-median runs, `QM5_41183`'s maximum signed ECDF gap,
`QM5_41176`'s sum of all cross-block wins, and `QM5_41172`'s variable
chronological change point. It also shares no logic with certified
`QM5_12567`, a long-only two-day XNG cumulative-RSI pullback.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_FIVE_BY_FIVE_POOLED_LABEL_RUNS_LE6_MEDIAN_DIRECTED_DISTRIBUTION_SHIFT_CONTINUATION`.

## Kill And Safety Boundary

Q02 retires the candidate at zero trades, below five completed positions in
any full post-warm-up year, with nonpositive governed economics, or on any
endpoint, split, tie, sort, run-count, median, threshold, side, attempt, risk,
lifecycle, or determinism defect. No failed result may be rescued by changing
the blocks, boundary, direction, carrier, risk, hold, or adding a filter.

Direct WTI exposure supplies a crude-oil driver absent from the stated
XAU/SP500/NDX/XNG book, but does not prove low realized correlation. Unchanged
Q09 owns overlap. This approval excludes manual backtests; live, demo,
shadow, stress, and optimization presets; AutoTrading; `T_Live`; deploy/live
manifests; portfolio-gate changes; portfolio admission; correlation waivers;
terminal control; and a second queue row. Q02 may be enqueued once only after
a current strict compile and review PASS and only below the factory CPU
ceiling.
