# WTI Monthly Spectral Entropy Trend - Source Approval

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

- proposed slug: `wti-mspectral-entropy-tr`
- proposed strategy ID: `URIGUEN-MOP-WTI-SPECENT-20260902_S01`
- proposed source ID: `URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902`
- exact host/traded slot zero: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine broker month
- signal: normalized one-sided DFT spectral entropy no greater than `0.88`
  on forty-eight completed monthly WTI log returns, followed in the newest
  twelve-month return direction

The governed allocator owns the numeric EA ID. This record neither predicts
nor hand-allocates it.

## Reviewed Evidence

1. Uriguen et al. (2017), *PLOS ONE* 12(9), e0184044, DOI
   `10.1371/journal.pone.0184044`. The complete open-access paper was read end
   to end. Equation 1 fixes entropy over a normalized power distribution and
   the zero-power-bin convention; its method section fixes the broad-flat
   versus concentrated-power interpretation.
2. Tagged SciPy 1.17.1 `_spectral_py.py`, SHA-256
   `9C1FA9FA599CE670EBE91617CE43D11229A9D95F4B7ADCBFD675BB2A44EB408E`.
   The complete `periodogram` function/docstring and relevant helper branches
   pin constant detrending, real one-sided DFT power, doubling of paired
   positive bins, and an undoubled even-length Nyquist bin.
3. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves the complete published-paper read, monthly own-return
   continuation, and explicit WTI membership.
4. `strategy-seeds/sources/URIGUEN-SCIPY-MOP-WTI-SPECENT-20260902/source.md`
   SHA-256
   `B0FBB9993C5FE3BF6643EC13E96AEBCDD669CA077D1A2A8A2677D65CAABE4514`,
   and `retrieval_route_20260902.json` bind the exact extraction and claim
   limits.

No source tests the exact forty-eight-return spectral-entropy/twelve-month-
direction conjunction, the `0.88` threshold as a profitable gate, the
Darwinex CFD, fixed risk, costs, lifecycle, activity, or portfolio
correlation. No source return, EEG threshold, significance, accuracy, alpha,
Sharpe ratio, drawdown, or decorrelation statistic transfers.

## Locked Mechanic

For forty-eight chronological completed-month log returns, subtract their
arithmetic mean. Compute the exact length-48 DFT without taper or padding at
one-sided non-DC bins `k=1..24`. Use twice the squared magnitude for paired
bins `1..23`, the undoubled squared magnitude for Nyquist bin `24`, normalize
the 24 powers to unit sum, and calculate
`Hspec=-sum(p*ln(p))/ln(24)`. Require finite arithmetic, total power above
`1e-24`, a unit probability sum, and entropy within its roundoff tolerance.
Qualify inclusively at `Hspec<=0.88`; then buy when the newest twelve-return
sum exceeds `1e-12`, sell below `-1e-12`, and consume ties or invalid states
flat.

There is one attempt per broker month, persisted before every fallible gate.
Risk is exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop, no target, a
1,500-point spread ceiling, next-month renewal, and forty-day stale exit.
Both news axes, legacy news, Friday close, and stress rejection are OFF.

The fixed-seed market-free null receipt, SHA-256
`1C364172B3F4E9EE4FDC0AD882160E7C7D4F14B37FDE0E8C29F6B70EA820CE60`,
qualifies 59.188% of 100,000 samples, or `7.10256` theoretical attempts per
twelve clocks. It is only a pre-data cadence check. Q02 owns the actual
five-per-year floor and economics.

## Reputable-Source And Duplicate Decision

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`.
- R2: `PASS` with all arithmetic, clock, risk, and lifecycle rules fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` on registered native WTI D1.
- R4: `PASS`; bounded deterministic arithmetic, no ML or banned signal.

The corrected-root dedup receipt scanned 4,797 registry rows, 1,426 cards,
and 45 wiki nodes with a `CLEAN` verdict:
`artifacts/qm5_wti_mspecent_tr_preallocation_dedup_20260902.json`, SHA-256
`5CC47A1D3CDDC1C1BE9F706D0D368666D44B635D9380D05CE51D071578BCF7E8`.

The nearest semantic systems remain mechanically distinct. `QM5_41308`
counts time-domain ordinal labels; `QM5_41309` parses a sign word into LZ76
phrases; `QM5_41310` uses a raw squared successive-difference ratio;
`QM5_41311` counts local raw-magnitude template recurrences; `QM5_9520` is an
intraday ternary Shannon-state crossover. This candidate measures the global
distribution of demeaned return power across one-sided DFT frequencies.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_ONESIDED_DFT_SPECENT_LE088_GATED_12M_CONTINUATION`.

## Kill And Safety Boundary

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, or on any deterministic
contract defect. No result-based change to sample, DFT, bins, weights,
threshold, direction, carrier, stop, hold, spread, or retry is allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. If the measured factory ceiling binds, stop without compiling or
enqueuing.
