# WTI Monthly Raw von Neumann Ratio Trend - Source Approval

Date: 2026-09-02

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue is not tester dispatch and remains
subject to the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. It requests one new structural low-frequency
commodity edge, reputable-source criteria, fixed-risk backtests, committed
non-duplicate work, and Q02 enqueue while excluding live and portfolio-gate
changes.

## Candidate Identity

- proposed slug: `wti-mvnratio-tr`
- proposed strategy ID: `AI-CODEX-WTI-MVNRATIO-TREND-20260902_S01`
- proposed source ID: `AI-CODEX-WTI-MVNRATIO-TREND-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: raw von Neumann successive-difference ratio below two on the latest
  twenty completed monthly WTI log returns, followed in the newest
  twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. NIST/SEMATECH Dataplot, "Mean Successive Differences Test,"
   `https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/msdt.htm`.
   The complete public page was read in sections. It fixes the raw squared
   successive-difference ratio, the random-normal average of two, and the
   interpretation of small values as long-term trend.
2. John von Neumann (1941), "Distribution of the Ratio of the Mean Square
   Successive Difference to the Variance," *Annals of Mathematical
   Statistics* 12(4), 367-395, DOI `10.1214/aoms/1177731677`.
   Bibliographic provenance only; the body is not claimed as completely read.
3. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
4. `strategy-seeds/sources/AI-CODEX-WTI-MVNRATIO-TREND-20260902/source.md`
   and its `retrieval_route_20260902.json` bind the exact extraction and claim
   limits.

No source tests the exact 20-return ratio/12-month direction conjunction,
the mean boundary as a profitable gate, the Darwinex CFD, fixed risk, stop,
spread, lifecycle, trade density, costs, or portfolio correlation. No source
return, alpha, Sharpe ratio, drawdown, or decorrelation statistic transfers.

## Locked Mechanic

For chronological completed-month closes `C[0..20]`, compute twenty adjacent
log returns `r[0..19]`, their mean, centered sum of squares `V`, successive
squared-difference sum `D`, and `eta=D/V`. Require finite values and
`V>1e-18`. Qualify strictly at `eta<2.0`; then buy when
`sum(r[8..19])>1e-12`, sell below `-1e-12`, and otherwise consume flat.

There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` broker stop, no target,
a 1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

The threshold is a prespecified NIST null-mean split, not a significance
claim. A fixed-seed market-free null simulation qualified 49.9715% of 200,000
20-observation samples, or 5.9966 expected packages/year. Q02 still owns the
actual five-per-year floor and economics.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; closed-form deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,795 registry rows, 1,424 cards,
and 45 wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_mvnratio_tr_preallocation_dedup_20260902.json`, SHA-256
`8539B7F5E61A88376EA0E2BA0CE1AF42E7EB2B7028C0356A3C7BB1C663D09142`.

The nearest neighbor `QM5_41170` applies a Bartels rank ratio to thirteen
price-level ranks, intentionally discarding magnitude. This candidate applies
the raw von Neumann ratio to twenty monthly log-return magnitudes. It also
differs from net/absolute path efficiency, q-horizon variance ratios,
regression, entropy, sign-run, calendar, event, and channel systems.

Verdict:
`CLEAN_WTI_MONTHLY_20_RAW_RETURN_VON_NEUMANN_ETA_LT2_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, threshold, direction,
carrier, stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling or
enqueuing.
