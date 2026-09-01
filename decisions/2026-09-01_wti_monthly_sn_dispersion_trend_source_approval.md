# WTI Monthly Sn-Core Dispersion Trend - Source Approval

Date: 2026-09-01

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue. Enqueue does not authorize a manual tester run or work
above the active whole-host CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It asks for exactly one new structural,
low-frequency commodity or energy edge outside the certified
XAU/SP500/NDX/XNG book, identifies direct WTI trend or seasonality as eligible,
requires reputable-source criteria and `RISK_FIXED` backtests, and excludes
the portfolio gate, live manifests, `T_Live`, and AutoTrading.

## Candidate Identity

- proposed slug: `wti-msndisp-tr`
- proposed strategy ID: `AI-CODEX-WTI-MSNDISP-TREND-20260901_S01`
- proposed source ID: `AI-CODEX-WTI-MSNDISP-TREND-20260901`
- proposed symbol / host: exact `XTIUSD.DWX`, D1, slot 0
- decision clock: first executable tick after a genuine broker-month
  transition
- signal: the completed month's final seventeen D1 closes, sixteen adjacent
  log returns, sixteen leave-one-out lower-median distances, their outer lower
  median as a raw Sn core, and continuation only when absolute net displacement
  is at least three times that core

The deterministic registry owns the EA ID. This source decision neither
predicts nor reserves an identity.

## Approved Source Basis

Three bounded parent records were read completely before this decision.

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   preserves a complete 23-page read of Moskowitz, Ooi, and Pedersen (2012),
   *Time Series Momentum*, *Journal of Financial Economics* 104(2), 228-250,
   DOI `10.1016/j.jfineco.2011.11.003`. It documents own-return continuation
   at monthly horizons, explicitly reports a one-month formation/one-month
   holding commodity portfolio, and identifies NYMEX WTI in the commodity
   universe.
2. Rousseeuw and Croux (1993), *Alternatives to the Median Absolute
   Deviation*, *Journal of the American Statistical Association* 88(424),
   1273-1283, DOI `10.1080/01621459.1993.10476408`, was re-retrieved from the
   authors' KU Leuven-hosted published PDF and checked against the existing
   complete eleven-page read. PDF SHA-256:
   `F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969`.
   The paper defines Sn as a nested median of pairwise absolute distances and
   separates the raw functional from its `1.1926` consistency multiplier.
3. CRAN `robustbase` release `0.99-7`, commit
   `54c5cc98e27050a78bbd03be15f07a7ba88de62a`, was read completely for
   `R/qnsn.R` and `src/qn_sn.c`. Its primary implementation pins raw Sn as
   `LOMED_i HIMED_j |x_i-x_j|`, equivalently
   `LOMED_i LOMED_{j!=i} |x_i-x_j|`. For sixteen values, each inner lower
   median is the eighth order statistic of fifteen distances and the outer
   lower median is the eighth order statistic of sixteen inner values.

The papers and software do not test this WTI-only within-month conjunction,
final-seventeen selection, unscaled Sn core, three-core gate, continuous CFD,
fixed-dollar risk, ATR stop, or the QM book. The sample, raw-core choice,
threshold, continuous-CFD translation, execution gates, and lifecycle are
transparent pre-result QM choices. No source return, WTI-only alpha, Sn
significance, probability, trade count, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible entry gate. One
   month may produce at most one consumed attempt.
2. Exclude every current-month price. Reconstruct the immediately completed
   broker month and require 17 through 23 chronological completed D1
   sessions.
3. Select the final seventeen closes in chronological order, `C[0]..C[16]`.
   Require positive finite values and strict timestamps.
4. Form sixteen adjacent log returns
   `r[i]=ln(C[i+1]/C[i])`, `i=0..15`. Require finite returns and verify
   `sum(r)` equals `ln(C[16]/C[0])` within `1e-10`.
5. For every `i`, form and sort the fifteen finite distances
   `abs(r[i]-r[j])`, `j!=i`, and retain the eighth one-based value as
   `inner[i]`. Sort all sixteen `inner` values and retain the eighth one-based
   value as `sn_core`. This is the raw Sn functional: no `1.1926` consistency
   multiplier and no finite-sample multiplier enter the signal. Require
   `sn_core>1e-12`.
6. BUY when `net >= 3*sn_core`; SELL when `net <= -3*sn_core`; otherwise stay
   flat. The boundary is inclusive. Signal magnitude never changes risk.
7. Open at most one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`, sized against one frozen `3.5*ATR(20,D1)` broker hard
   stop. Attach no target and reject a genuinely positive entry spread above
   1,500 points.
8. Close on the first tick in a later broker month or after forty elapsed
   calendar days. Immediately repair duplicate, wrong-symbol, wrong-magic,
   wrong-side, invalid-volume, or stopless owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 D1 OHLC/timestamps, broker time, quotes, contract metadata,
positions, deals, terminal global variables, and V5 framework services.

## Activity Boundary

There is one consumed decision per broker month and therefore at most twelve
qualified entries per full year. A pre-result ordering prior of roughly six
to eight completed positions per full post-warm-up year is not a source claim
and must be falsified at Q02. Q02 must retire zero-trade output or fewer than
five completed positions in any full post-warm-up calendar year.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,776 registry identities,
1,412 card files, and all 45 Strategy Wiki nodes. It found no exact identity
and one expected fuzzy neighbor, `QM5_41275_wti-mqndisp-tr`. Evidence:
`artifacts/qm5_wti_msndisp_tr_preallocation_dedup_20260901.json`, SHA-256
`74C0023E963CD3105658E09BBFE64168DABE211FC00B82934C37D17B42F40CE5`.

Manual functional review resolves the fuzzy result:

- This candidate computes sixteen leave-one-out eighth-order distances and
  then an outer eighth-order value. `QM5_41275` computes one global 36th
  order statistic among all 120 distances. Neither functional can be reduced
  to the other, and their locked thresholds differ.
- Fixed return vector
  `[.008232,.000939,-.003412,-.014585,-.001265,.003701,.005557,-.004145,
  .001404,-.005253,-.016244,.018212,.000576,-.000055,.025836,-.002419]`
  has `net=.017079`, `sn_core=.005549`, and `q_core=.004351`. It BUYs here
  because `net/(3*sn_core)=1.026`, while Qn is flat at
  `net/(4*q_core)=.981`; L1 path efficiency `.153` and RMS coherence `.105`
  are also flat.
- Fixed return vector
  `[.001685,-.010370,-.005073,-.006910,-.007936,.005197,.013921,-.001685,
  .003583,.008084,.003411,-.002320,.011475,.001997,-.001300,.005011]`
  has `net=.018770`, `sn_core=.006399`, and `q_core=.004317`. It is flat
  here at `net/(3*sn_core)=.978`, while Qn BUYs at
  `net/(4*q_core)=1.087`; the L1 and RMS neighbors also BUY.
- Old/recent scale-state cards (`QM5_41250`, `41261`, `41266`, `41267`, and
  `41271`) compare two monthly-return groups. This candidate has one fixed
  within-month daily-return sample and no group comparison, p-value,
  permutation, normal score, or variance-ratio state.
- `QM5_20187` follows an endpoint sign without any dispersion gate.
- certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  pullback and shares neither carrier, information set, direction, nor
  lifecycle.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL17_RETURN_SN_NESTED_MEDIAN_DISPERSION_NORMALIZED_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK`:
  complete-read peer-reviewed WTI trend evidence supports the carrier and
  broad monthly continuation premise; complete-read peer-reviewed Sn evidence
  and commit-pinned primary software support the exact raw nested-median
  functional. Their trading conjunction is explicitly untested QM synthesis.
- R2 `PASS`: month clock, session range, final-seventeen selection, sixteen
  returns, 16x15 distance enumeration, inner/outer lower medians, omitted
  multipliers, inclusive three-core direction, attempt, risk, stop, spread,
  and lifecycle are deterministic and locked before Q02.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5-native state supplies every runtime input;
  futures-to-CFD roll, basis, financing, gaps, and broker-month labels remain
  falsification risks.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms, finite
  sorting, comparisons, ATR risk controls, and execution state only; no
  trained output, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Kill And Safety Boundary

Retire or fail on a clock, month membership, chronology, session count,
final-seventeen selection, return orientation, endpoint identity, distance
count, inner or outer order statistic, hidden multiplier, side, attempt,
fixed-risk, stop, lifecycle, or determinism defect; fewer than five completed
positions in any full post-warm-up year; zero trades; nonpositive governed
economics; or any downstream gate failure. No failed result may be rescued by
changing the sample, median convention, multiplier, threshold, carrier,
direction, risk, hold, or by adding another filter.

Direct WTI supplies crude-oil exposure absent from the stated
XAU/SP500/NDX/XNG book, but it does not prove factor or portfolio
decorrelation. Unchanged Q09 alone owns overlap. This approval excludes manual
backtests; optimization; live, demo, shadow, and stress presets; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; and terminal control.
