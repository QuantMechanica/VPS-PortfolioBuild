# WTI Monthly Qn-Core Dispersion Trend - Source Approval

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

- proposed slug: `wti-mqndisp-tr`
- proposed strategy ID: `AI-CODEX-WTI-MQNDISP-TREND-20260901_S01`
- proposed source ID: `AI-CODEX-WTI-MQNDISP-TREND-20260901`
- proposed symbol / host: exact `XTIUSD.DWX`, D1, slot 0
- decision clock: first executable tick after a genuine broker-month
  transition
- signal: the completed month's final seventeen D1 closes, sixteen adjacent
  log returns, the 36th order statistic among all 120 pairwise absolute
  return distances, and continuation only when absolute net displacement is
  at least four times that unscaled Qn core

The deterministic registry owns the EA ID. This source decision neither
predicts nor reserves an identity.

## Approved Source Basis

Two bounded parent records were read completely before this decision.

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
   1273-1283, DOI `10.1080/01621459.1993.10476408`, was read across all eleven
   pages from the authors' KU Leuven-hosted published PDF. PDF SHA-256:
   `F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969`.
   Section 3 defines Qn from the kth order statistic of pairwise absolute
   distances, with `h=floor(n/2)+1` and `k=C(h,2)`, and distinguishes the raw
   order statistic from the distribution-specific consistency multiplier.
   Retrieval evidence is stored beside the bounded source packet.

The papers do not test this WTI-only within-month conjunction, final-seventeen
selection, unscaled Qn core, four-core gate, continuous CFD, fixed-dollar
risk, ATR stop, or the QM book. The sample, raw-core choice, threshold,
continuous-CFD translation, execution gates, and lifecycle are transparent
pre-result QM choices. No source return, WTI-only alpha, Qn significance,
probability, trade count, cost, drawdown, CFD equivalence, decorrelation, or
portfolio result transfers.

The source-intake skill was not used to bypass a trading-site policy. The
OWNER supplied no individual trading URL. The Qn record is an author-hosted
academic paper reached through its public bibliographic lineage, read in
full, hashed, and used only for its stated scale-estimator arithmetic.

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
5. Form all 120 distances `abs(r[j]-r[i])` for `0<=i<j<=15`, sort ascending,
   and select `q_core=D[35]`, the 36th one-based order statistic. This follows
   the source's `h=9`, `k=C(9,2)=36` construction for `n=16` but deliberately
   omits every consistency multiplier. Require exactly 120 finite
   nonnegative distances and `q_core>1e-12`.
6. BUY when `net >= 4*q_core`; SELL when `net <= -4*q_core`; otherwise stay
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
qualified entries per full year before history, Qn-core, direction, quote,
spread, ATR, sizing, margin, or execution gates. An ordering prior of roughly
seven to nine completed positions per full post-warm-up year is not a source
claim and must be falsified at Q02.

Q02 must retire zero-trade output or fewer than five completed positions in
any full post-warm-up calendar year.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,774 registry identities,
1,410 card files, and all 45 Strategy Wiki nodes. It found no exact or fuzzy
identity. Evidence:
`artifacts/qm5_wti_mqndisp_tr_preallocation_dedup_20260901.json`, SHA-256
`831C20BF85E9B38C85F29D71F15D22422BD24BD10F3A9C40223DDBCA6AEC066D`.

Manual semantic review fixes the load-bearing boundaries:

- `QM5_41126_wti-mpath-eff-mom` divides net displacement by the sum of
  absolute returns over every return ending in the month. This candidate
  selects one lower-quartile pairwise-distance order statistic from exactly
  sixteen within-month returns. Fixed return vector
  `[.0010,.0011,.0009,.0012,.0008,.0013,.0007,.0014,.0006,.0015,.0005,
  .0016,-.0500,.0491,-.0400,.0402]` buys here (`net=.0119`,
  `q_core=.0004`) while L1 path efficiency is about `.062` and stays flat.
- `QM5_41124_wti-mrms-coherence-mom` uses every squared daily return and a
  mean-to-RMS gate. The same vector has RMS coherence about `.033` and stays
  flat, while the lower-order pairwise core deliberately resists its four
  extreme observations.
- Fixed vector
  `[-.007421,.009985,.000350,-.014180,-.012633,.004963,.019301,.002529,
  -.021856,-.015511,.017713,-.026402,-.027677,.006700,.018567,.003460]`
  has L1 efficiency about `.2013` and RMS coherence about `.1704`, but stays
  flat here because `abs(net)/(4*q_core)` is about `.9676`.
- `QM5_41250_wti-mperm-scale-tr` compares six old and six recent monthly
  returns through two MADs and all 924 label assignments. This candidate has
  one completed month's daily-return distribution, no old/recent monthly
  split, no MAD, and no permutation tail.
- `QM5_41261`, `QM5_41266`, `QM5_41267`, and `QM5_41271` use two-sample or
  group-centered scale-state scores across monthly returns. This candidate
  uses a single fixed within-month sample and gates net displacement by its
  raw Qn order-statistic core.
- `QM5_20187_wti-tsmom1m` follows the completed-month endpoint sign without a
  path-dispersion gate. This candidate may stay flat on the same endpoint.
- certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  pullback and shares neither carrier, information set, direction, nor
  lifecycle.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL17_RETURN_QN_CORE_DISPERSION_NORMALIZED_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_QN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK`:
  a complete-read peer-reviewed WTI trend paper supports the carrier, monthly
  cadence, and broad continuation premise; a complete-read peer-reviewed Qn
  paper supports the exact pairwise-distance order statistic. Their trading
  conjunction and four-core gate are explicitly untested QM synthesis.
- R2 `PASS`: month clock, session range, final-seventeen selection, sixteen
  returns, all 120 distances, 36th order statistic, no consistency factor,
  inclusive four-core direction, attempt, risk, stop, spread, and lifecycle
  are deterministic and locked before Q02.
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
count, order-statistic index, Qn-core, side, attempt, fixed-risk, stop,
lifecycle, or determinism defect; fewer than five completed positions in any
full post-warm-up year; zero trades; nonpositive governed economics; or any
downstream gate failure. No failed result may be rescued by changing the
sample, order statistic, multiplier, threshold, carrier, direction, risk,
hold, or by adding another filter.

Direct WTI supplies crude-oil exposure absent from the stated
XAU/SP500/NDX/XNG book, but it does not prove factor or portfolio
decorrelation. Unchanged Q09 alone owns overlap. This approval excludes manual
backtests; optimization; live, demo, shadow, and stress presets; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; and terminal control.

