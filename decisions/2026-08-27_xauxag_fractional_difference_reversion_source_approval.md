# XAU/XAG Fixed Fractional-Difference Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity edge, expressly permits a market-neutral-
style `XAUUSD.DWX`/`XAGUSD.DWX` gold/silver ratio-reversion basket, requires
reputable-source criteria and `RISK_FIXED` backtests, and excludes live and
portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-fracd-rv`
- proposed strategy ID: `YAYA-CME-XAUXAG-FRACD-RV-2026_S01`
- proposed source ID: `YAYA-CME-XAUXAG-FRACD-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of each genuine new
  broker month
- signal: fade a held-out standardized fixed-order, fixed-truncation
  fractional difference of the synchronized daily log gold/silver ratio

The canonical allocator owns the EA ID. This record neither predicts nor
reserves an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It records Karsten Schweikert (2018), *Journal of Banking & Finance* 88,
   44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo, and Olayinka
   (2021), *Resources Policy* 72, 102045, DOI
   `10.1016/j.resourpol.2021.102045`. The first supports a state-dependent
   gold/silver long-run relation and warns against a universal constant
   vector; the second explicitly reports robust fractional-cointegration
   evidence for gold and silver prices.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   CME defines the gold/silver ratio, presents it as an intermarket spread,
   and distinguishes gold's monetary/safe-haven demand from silver's larger
   industrial-cycle exposure.

No new public URL was supplied or needed. The exact fractional-difference
order, finite recurrence, held-out standardization, monthly decision clock,
threshold, CFD mapping, order sides, risk, stops, and lifecycle below are
transparent QM translations. No source performance, coefficient, memory
estimate, significance, density, cost, neutrality, CFD-equivalence,
decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first synchronized executable D1 tick after a genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate. One month
   may produce at most one consumed attempt.
2. Load exactly 316 timestamp-matched completed D1 XAU/XAG close pairs in
   chronological order, ending at the newest completed host D1 bar. Reject
   missing, duplicate, nonchronological, stale, desynchronized, nonpositive,
   or nonfinite observations.
3. Form `s[t] = ln(XAU[t]) - ln(XAG[t])`.
4. Fix `d=0.40` and exactly 64 coefficients of `(1-L)^d`:

   ```text
   w[0] = 1
   w[k] = w[k-1] * (k - 1 - d) / k,  k=1..63
   fd[t] = sum(k=0..63, w[k] * s[t-k])
   ```

   Require finite weights and outputs. The order and truncation never fit or
   adapt to market data.
5. Use the first 252 available `fd` outputs as the baseline and hold the 253rd
   (latest) output out. Compute the baseline sample mean and sample standard
   deviation with denominator 251, then
   `z=(fd_latest-mean_baseline)/sample_sd`. Require finite positive variance.
6. If `z>=+0.50`, SELL XAU and BUY XAG. If `z<=-0.50`, BUY XAU and SELL XAG.
   Otherwise consume the month flat. Exact equality is inclusive; signal
   magnitude never changes size.
7. Open at most one opposite-side equal-target-notional package under one
   aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Split stop risk equally, attach frozen
   `3.5*ATR(20,D1)` hard stops, cap entry spreads at 1,500 XAU points and 500
   XAG points, and cap rounded notional mismatch at 20 percent.
8. Submit XAU first and XAG second. Retain exposure only when exactly one
   correctly directed, stopped position exists in each slot; otherwise close
   every owned leg immediately without retry.
9. Close the complete package on the first tick in a later broker month or
   after forty calendar days. Repair any orphaned, duplicated, same-side,
   wrong-symbol/magic, stopless, or notional-invalid package immediately.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 history, timestamps, logarithms, arithmetic, ATR, quotes,
contract metadata, position/deal state, and persistent terminal state.

## Reputable-Source Criteria

- R1 `PASS_WITH_FIXED_FRACDIFF_TRANSLATION_RISK`: two identified peer-reviewed
  gold/silver relationship papers, including fractional cointegration, plus
  official exchange carrier research; the trading conjunction is untested.
- R2 `PASS`: sample count, synchronization, recurrence, order, truncation,
  held-out baseline, threshold, sides, attempt state, risk, atomicity, and
  lifecycle are fixed before Q02.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5-native state supply every
  runtime input.
- R4 `PASS`: deterministic fixed arithmetic only; no fitted memory parameter,
  trained output, ML, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed checker scanned 4,684 registry identities, 1,335 cards, and
the actual 45-node Company Reference Strategy Wiki. It returned no exact or
fuzzy match. Evidence is
`artifacts/qm5_xauxag_fracd_rv_preallocation_dedup_20260827.json`, SHA-256
`98BA647CF8B8618B85AC71E62E99640A4CED0A9A589576D4FDF8957340657DB9`.

Manual semantic review fixes the boundary:

- `QM5_20157_xau-xag-ratio` standardizes the raw rolling log ratio; it does
  not apply the fixed fractional-difference operator or a held-out baseline.
- `QM5_20161_xauxag-ols-rv` fits a rolling hedge regression; this candidate
  fits no coefficient, intercept, center, or memory order from market data.
- `QM5_21526_xau-xag-cadf` freezes an annual OLS/CADF/OU model and uses a
  fitted half-life; this rule uses one fixed linear fractional filter and a
  monthly one-period lifecycle.
- `QM5_20012_xauxag-cmtar` uses a published monthly threshold-error equation;
  it does not transform the daily ratio with `(1-L)^0.40`.
- rank, sign, robust-location, return-spread, seasonal, stochastic, quantile,
  channel, and raw-ratio baskets operate on different state objects.

Verdict:
`CLEAN_XAUXAG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Kill And Safety Boundary

The `abs(z)>=0.50` pre-result density prior is approximately 7.4 monthly
opportunities per year under a standard-normal reference only; it is not a
market claim. Q02 must retire below five completed packages in any full
post-warm-up year, at zero trades, with nonpositive governed economics, or on
any history, recurrence, baseline, direction, attempt, risk, atomicity,
lifecycle, or determinism defect. No result may be rescued by changing the
order, truncation, sample, threshold, carrier, direction, risk, hold, or by
adding another filter.

Opposite equal-target-notional legs reduce common outright-metal direction
but do not prove neutrality or decorrelation; unchanged Q09 alone owns the
realized portfolio result. This approval excludes manual backtests; live,
demo, shadow, stress, and optimization setfiles; AutoTrading; `T_Live`;
deploy or live manifests; portfolio-gate changes; portfolio admission;
correlation waivers; terminal control; and a second queue row. Q02 may be
enqueued once only after a current strict compile/review PASS and only below
the factory CPU ceiling.
