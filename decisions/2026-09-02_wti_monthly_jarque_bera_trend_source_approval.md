# WTI Monthly Jarque-Bera Shape-Gated Trend - Source Approval

Date: 2026-09-02

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue is not tester dispatch and remains
subject to the active whole-host CPU ceiling.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. It requests one new structural low-frequency
commodity edge, reputable-source criteria, fixed-risk backtests, committed
non-duplicate work, and Q02 enqueue while excluding live and portfolio-gate
changes.

## Candidate Identity

- proposed slug: `wti-mjb-tr`
- proposed strategy ID: `JARQUEBERA-MOP-WTI-OMNIBUS-20260902_S01`
- proposed source ID: `JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: Jarque-Bera distribution-shape statistic at or above `1.04` on
  forty-eight completed monthly WTI log returns, followed in the newest
  twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. SciPy `scipy.stats.jarque_bera`, `skew`, and `kurtosis`, pinned at commit
   `0f0a3dd37f88ecd8c4d83a5913df56471274fefa`. The governed router returned
   `ROUTE_GITHUB_API`; the complete bounded implementation was read through
   the public GitHub contents API. It fixes biased central-moment estimators,
   Fisher excess kurtosis, `JB=n/6*(s^2+k^2/4)`, and the explicit warning that
   chi-square inference requires a much larger sample.
2. SciPy's complete pinned `TestJarqueBera` class. Its R-compatible five-value
   fixture fixes statistic `0.17651605223752` for independent verification.
3. Jarque and Bera (1987), *International Statistical Review* 55(2), 163-172,
   DOI `10.2307/1403192`. Bibliographic attribution only; no inaccessible
   body claim is used.
4. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
5. `strategy-seeds/sources/JARQUEBERA-SCIPY-MOP-WTI-OMNIBUS-20260902/source.md`,
   SHA-256
   `6C50EFC59F3C036C5107BAB15CCCD4804365595E8CC6F774C2ED1AE5BCFAA3AB`,
   and `retrieval_route_20260902.json`, SHA-256
   `7DE447F859BC67F8BBE8260F696DB6DFD5EB352C618767D90D09CF6F64069B1D`,
   bind the exact extraction and claim limits.

No source tests the exact raw-return Jarque-Bera/twelve-month-direction
conjunction, the `1.04` boundary as a profitable gate, Darwinex CFD
equivalence, fixed risk, costs, lifecycle, activity, or portfolio
correlation. No source p-value, rejection result, return, accuracy, alpha,
Sharpe ratio, drawdown, or decorrelation statistic transfers.

## Locked Mechanic

For forty-eight chronological completed-month log returns, subtract their
arithmetic mean and calculate biased population central moments:

```text
m2 = sum((x-mean)^2)/48
m3 = sum((x-mean)^3)/48
m4 = sum((x-mean)^4)/48
skew = m3/(m2^1.5)
excess = m4/(m2^2)-3
JB = 48/6 * (skew^2 + excess^2/4)
```

Require positive finite closes, finite intermediate arithmetic, and
`m2>1e-18`. Qualify inclusively at `JB>=1.04`; buy when the newest twelve-
return sum exceeds `1e-12`, sell below `-1e-12`, and consume ties or invalid
states flat. The squared moment terms intentionally detect non-normal
distribution shape without assigning side; the independent continuation
carrier owns direction.

The boundary is the two-decimal pre-data approximation to the empirical
median `1.0396466455041877` from 200,000 independent standard-normal
48-observation paths using NumPy 2.4.6 PCG64 seed `20260902`. It is a state
divider, not a significance test. The receipt, SHA-256
`A150F770B1BCB0C52C578C3C7456238EDB0092B14509B47E62C8F83196A6459C`,
qualifies `49.981%`, or `5.99772` theoretical clocks per twelve months. It is
only a market-free cadence check; Q02 owns actual activity and economics.

There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target, a
1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; bounded deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,799 registry rows, 1,428 cards,
and 45 Wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_mjb_tr_preallocation_dedup_20260902.json`, SHA-256
`3185D235BA92BA469C33605D2EE4E102644120100106F9152925CE40E61334CC`.

The nearest semantic systems remain mechanically distinct. `QM5_20290`
trades skewness sign as a direct premium and `QM5_20295` trades Pearson
kurtosis around benchmark three; neither squares and jointly aggregates the
two standardized moments or takes direction from an independent momentum
carrier. `QM5_41313` aggregates serial autocorrelations, whereas Jarque-Bera
is permutation-invariant and measures marginal distribution shape. Entropy,
rank, change-point, scale, calendar, event, channel, and relative-value
systems use different state objects. The certified `QM5_12567` is a two-day
long-only XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_JARQUE_BERA_JB_GE1P04_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, estimator, boundary,
direction, carrier, stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling,
enqueuing, or dispatching.
