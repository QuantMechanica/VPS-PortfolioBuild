# XAU/XAG Median Same-Calendar Relative Seasonality — Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and two-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced logical-basket Q02 enqueue if the tester and
host-CPU ceilings permit. This decision does not authorize a manual tester
dispatch.

Authority: the current explicit OWNER commodity/energy sleeve mission on
branch `agents/board-advisor`. The mission requests one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, expressly offers a market-neutral XAU/XAG basket,
requires reputable-source criteria and `RISK_FIXED` backtests, and excludes
live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-medcal`
- proposed strategy ID: `KELOHARJU-XAUXAG-MEDCAL-2026_S01`
- source ID: `KELOHARJU-FMR-XAUXAG-SAMECAL-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: sample median of five to ten synchronized, exact-prior-year
  XAU-minus-XAG completed log returns for the decision calendar month
- lifecycle: follow the median sign with opposite metal legs until the next
  broker month, with atomic repair and a 40-calendar-day survivor guard

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Claim Boundary

The bounded source-of-record packet
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md` was read
completely before this decision. Its SHA-256 is
`9266E47C7F3235D900C9432FEAC33A417807AE1E2CC9685FF2FEADAB46DBF75E`, and its
last source-packet commit is `d3d5aa3a14fac157d97a96fc3c35f1662650dcb6`.

That governed composite joins two named-author, peer-reviewed lineages:

1. Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities,"
   *The Journal of Finance* 71(4), 1557–1590, DOI
   `10.1111/jofi.12398`, supplies recurring same-calendar commodity-return
   information, monthly renewal, and a five-year history floor. Its complete
   open-paper review is recorded in
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
2. Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in Commodity
   Futures Markets," *Journal of Banking & Finance* 34(10), 2530–2548, DOI
   `10.1016/j.jbankfin.2010.04.009`, supplies the governed XAU/XAG
   cross-sectional carrier and one-month opposite-leg translation.

The sample median is an explicit, pre-result QM robustness translation. The
source composite uses an arithmetic mean and does not test the ordinary
median, a five-to-ten-observation rule, Darwinex continuous CFDs, shared
fixed-risk sizing, ATR stops, or this exact operational lifecycle. No source
return, coefficient, significance, density, profit factor, trade count,
drawdown, cost, hedge, CFD equivalence, neutrality, decorrelation, or
portfolio result transfers.

## Locked Mechanic

On the first executable `XAUUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure and close the prior package before entry-only gates,
   then persist broker `yyyymm` before history, signal, news, quote, spread,
   ATR, sizing, margin, or submission. Never retry that month.
2. Under one uniform native or `+1` metal D1-label convention, reconstruct
   synchronized completed XAU and XAG log returns for calendar month `M` in
   exact years `Y-1..Y-10`. Require strict adjacent-month endpoints,
   confirming following bars, positive finite prices, and matching endpoint
   timestamps across the two legs. Skip a missing year without substitution
   and require five to ten valid pairs.
3. For every valid year form
   `d_i = ln(XAU_end/XAU_prior_end) - ln(XAG_end/XAG_prior_end)`.
4. Sort the finite `d_i` values ascending. For odd `n`, select the middle
   value; for even `n`, use the arithmetic mean of the two middle values.
5. Above `+1e-12`, buy XAU and sell XAG. Below `-1e-12`, sell XAU and buy
   XAG. Equality inside the inclusive epsilon band consumes the month flat.
   Signal magnitude never changes size.
6. Split exactly one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget into equal fixed-risk halves. Attach
   frozen `3.5 * ATR(20,D1)` hard stops, no targets, and reject crossed or
   negative-spread quotes plus genuinely positive spreads above 1,500 XAU
   points or 3,000 XAG points.
7. Prepare both orders before submission. Immediately flatten all owned legs
   after partial submission, wrong composition, missing stop, or malformed
   state.
8. Close both legs at the first later normalized broker-month boundary. A
   40-calendar-day stale guard repairs only a survivor.
9. Lock both current news axes and legacy news mode OFF, and disable framework
   Friday flatten so the monthly package can span weekends.
10. Never retry, scale in, pyramid, grid, martingale, optimize, introduce a
    ratio/OLS fallback, or add a result-conditioned filter.

Exact year selection, synchronized endpoints, relative orientation, sample
bounds, even/odd median arithmetic, sign, consumed attempt, shared fixed
risk, atomicity, stops, and month lifecycle are load-bearing. No arithmetic
mean, Huber, t-score, signed-rank, sign-score, ratio z-score, recent-return,
current-month, or favorable-month fallback is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_ROBUST_LOCATION_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`:
  two complete-read, DOI-bearing, peer-reviewed lineages support the
  same-calendar information object and governed XAU/XAG opposite-leg carrier;
  the ordinary median and exact conjunction are disclosed untested QM choices.
- R2 `PASS`: month clock, normalization, synchronized endpoints, exact years,
  sample bounds, odd/even median, side map, attempt state, shared risk, stops,
  spreads, atomicity, and exits are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state
  supply every runtime field. Label, history, roll, financing, legging, and
  CFD-basis risks remain explicit Q02 risks.
- R4 `PASS`: timestamps, completed OHLC, logarithms, sorting, comparisons,
  ATR-risk plumbing, quotes, positions, deals, and terminal state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_medcal_preallocation_dedup_20260830.json`, SHA-256
`3989F7EBA257EF1FEAD63D8A4ABCE61FDE6AA6F6B61BB8DFEC9067B5011024EB`, scanned
4,725 EA-registry identities, 1,363 cards, and all 45 current Strategy Wiki
nodes. It returned `CLEAN` with no exact or above-threshold fuzzy match.

Manual semantic review fixes the important executable boundaries:

- `QM5_20186_xauxag-samecal` follows the arithmetic mean of synchronized
  relative returns. For `[+0.01,+0.01,+0.01,+0.01,-0.20]`, that EA sells XAU
  while this candidate's median buys XAU.
- `QM5_41206_xauxag-samecal-huber10` requires ten of ten years, a positive
  median/MAD scale, and 32 iterative Huber updates. This candidate accepts
  five to ten pairs and directly selects the ordinary sample median without
  scale or iteration.
- `QM5_41213_xauxag-samecal-signscore` discards magnitudes and applies a
  sample-size-aware Bernoulli abstention band. For
  `[+0.001,-0.20,-0.20,+0.20,+0.20]`, this candidate buys XAU on the positive
  median while the sign-score package remains flat.
- `QM5_41210_xauxag-samecal-tstat` divides a metric mean by sample standard
  error; the same vector leaves its t-score near zero while the median remains
  positive.
- `QM5_41203_xauxag-samecal-srank` preserves absolute-rank weights rather
  than using the unweighted center order statistic.
- Ratio z-score, OLS/CADF residual, recent-window momentum, channel, session,
  correlation-break, and monthly path-distribution baskets observe different
  information objects.

Verdict:
`CLEAN_AND_SEMANTICALLY_DISTINCT_XAUXAG_SAMECAL_RELATIVE_SAMPLE_MEDIAN_SIGN_MONTHLY_BASKET`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed packages per full
post-warm-up year. Q02 retires on zero packages, fewer than five completed
packages in any full scored year, nonpositive governed economics, wrong
calendar endpoints, desynchronized legs, current-month leakage, invalid
sample or median, wrong side, repeated entry, orphan persistence, missing
stops, invalid fixed-risk mode, wrong lifecycle, or nondeterminism. Failure
may not be rescued by changing the estimator, sample, threshold, direction,
carrier, risk, stop, spread, hold, or retry policy.

The opposite legs target relative precious-metal seasonality but do not prove
dollar, beta, volatility, or portfolio neutrality. Only unchanged Q09 may
measure realized book overlap.

This approval excludes manual backtests; component-leg Q02 rows; live, demo,
shadow, stress, and optimization setfiles; terminal dispatch or control;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate changes;
portfolio admission; decorrelation claims; and correlation waivers. Q02 may
be enqueued once only if the exact-path tester count and host CPU are below
the governed ceilings. At the ceiling, stop before queue mutation and record
a non-live handoff.
