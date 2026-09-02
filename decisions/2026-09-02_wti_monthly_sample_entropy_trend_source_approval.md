# WTI Monthly Sample Entropy Trend - Source Approval

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

- proposed slug: `wti-msampen-tr`
- proposed strategy ID: `RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902_S01`
- proposed source ID: `RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: sample entropy no greater than 2.5 on sixty completed monthly WTI
  log returns, followed in the newest twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. Tomcala (2020), *Entropy* 22(8), 863, DOI `10.3390/e22080863`.
   The complete open-access paper was read end to end. Equation 2 and Appendix
   B fix the sample-entropy formula and conventional `m=2`, lag-one,
   `r=0.2*sample-sd` settings.
2. Pinned CRAN `TSEntropies` `SampEn_R.R`, SHA-256
   `2E74A7DA4C836E039E48F7985E68218D8C23B954AAEE5051873AD2BC7CF73933`.
   The complete method file fixes strict radius comparison, maximum-coordinate
   template distance, sample-standard-deviation radius, self-match exclusion,
   and the exact count ratio.
3. Richman and Moorman (2000), *American Journal of Physiology-Heart and
   Circulatory Physiology* 278(6), H2039-H2049, DOI
   `10.1152/ajpheart.2000.278.6.H2039`. Original provenance and publisher
   abstract only; no complete-body claim is made.
4. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
5. `strategy-seeds/sources/RICHMAN-MOORMAN-MOP-WTI-SAMPEN-20260902/source.md`
   and `retrieval_route_20260902.json` bind the exact extraction and claim
   limits.

No source tests the exact sixty-return sample-entropy/twelve-month-direction
conjunction, the `2.5` threshold as a profitable gate, the Darwinex CFD,
fixed risk, costs, lifecycle, activity, or portfolio correlation. No source
return, alpha, significance, Sharpe ratio, drawdown, or decorrelation statistic
transfers.

## Locked Mechanic

For sixty chronological completed-month log returns, compute sample standard
deviation, set `r=0.2*sd`, count all distinct lag-one length-two and
length-three templates with Chebyshev distance strictly below `r`, and set
`SampEn=ln(B/A)`. Require finite arithmetic, `sd>1e-12`, and integer
`B>=A>0`. Qualify inclusively at `SampEn<=2.5`; then buy when the newest
twelve-return sum exceeds `1e-12`, sell below `-1e-12`, and consume ties or
invalid states flat.

There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target, a
1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

The fixed-seed market-free null receipt qualifies 59.272% of 100,000 samples,
or 7.11264 theoretical attempts per twelve clocks. It is only a pre-data
cadence check. Q02 owns the actual five-per-year floor and economics.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; bounded deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,796 registry rows, 1,425 cards,
and 45 wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_msampen_tr_preallocation_dedup_20260902.json`, SHA-256
`1DC955560717980BCB73A2B69DBDB64CA038E5EFC990E7D0C1E9AFE827D11CF6`.

The nearest semantic systems remain mechanically distinct. `QM5_41308`
counts disjoint ordinal labels; `QM5_41309` parses a return-sign word into
LZ76 phrases; `QM5_41310` uses a raw squared successive-difference ratio;
`QM5_9520` is an intraday ternary Shannon-state crossover. This candidate
counts raw-magnitude template recurrences at dimensions two and three.

Verdict:
`CLEAN_WTI_MONTHLY_60_RETURN_M2_R020SD_SAMPEN_LE250_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, tolerance, dimension,
threshold, direction, carrier, stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling or
enqueuing.
