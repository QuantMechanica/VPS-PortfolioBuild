# WTI Same-Calendar Five-Sample Harrell-Davis Median - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue only if the governed tester and
whole-host CPU ceilings permit. This decision does not authorize a manual
tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, and a `RISK_FIXED`
backtest preset. It excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-hd5`
- proposed strategy ID:
  `KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026_S01`
- proposed source ID:
  `KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: the Harrell-Davis estimate of the median of the exact prior five
  matching-calendar-month WTI log returns, using the fixed beta(3,3)
  order-statistic weights
- lifecycle: follow the strict estimated-median sign for one broker month,
  with one consumed attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records and bounded primary/author-maintained
records were read completely before this decision:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open NBER Working Paper 20815 is
   represented by
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   last committed as `a1dd9e7751f843db82c0b230a46ed7fe6526accd`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete-paper review
   record is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   last committed as `1c312453ad3a61978bc59c3aa0d3f51153daf93c`.
3. Harrell, Frank E.; and Davis, C. E. (1982), "A New Distribution-Free
   Quantile Estimator," *Biometrika* 69(3), 635-640, DOI
   `10.1093/biomet/69.3.635`. The publisher record and abstract were reviewed
   at `https://academic.oup.com/biomet/article/69/3/635/221346`; they define
   the estimator as a linear combination of order statistics.
4. Frank Harrell's author-maintained `Hmisc` documentation and implementation
   for `hdquantile` were read completely for the relevant function on
   2026-08-30 at
   `https://search.r-project.org/CRAN/refmans/Hmisc/html/hdquantile.html` and
   `https://github.com/harrelfe/Hmisc/blob/master/R/Misc.s`. The implementation
   fixes `m=n+1`, beta parameters `p*m` and `(1-p)*m`, cumulative-beta values
   at `0/n..n/n`, adjacent differences as order-statistic weights, and the
   weighted sum.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. Harrell and Davis plus
the author-maintained implementation supply the named distribution-free
quantile estimator and its exact numerical convention.

No source tests this conjunction. The exact five-year sample, median target,
single continuous Darwinex CFD, fixed-dollar risk, ATR stop, spread cap,
attempt ledger, and operational lifecycle are transparent QM falsification
choices. No source return, coefficient, significance, alpha, Sharpe ratio,
drawdown, density, cost, WTI-only result, CFD equivalence, decorrelation, or
portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair malformed owned exposure and close the prior package before
   entry-only gates. Persist broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, or submission; never retry that month.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-5..Y-1`. Require strict adjacent-month endpoints, a confirming later
   D1 bar, positive finite closes, and all five returns. Missing or invalid
   history consumes the month flat; no substitute year or shorter sample is
   permitted.
3. Sort a copy of the five returns ascending as `s[0]..s[4]`. For sample size
   `n=5` and target quantile `p=0.5`, the Harrell-Davis convention sets
   `m=n+1=6` and both beta parameters to `3`. With regularized beta CDF
   `I_z(3,3)=10*z^3-15*z^4+6*z^5`, each weight is:

   ```text
   w_i = I_(i/5)(3,3) - I_((i-1)/5)(3,3), i=1..5

   weights = [0.05792, 0.25952, 0.36512, 0.25952, 0.05792]
           = [181, 811, 1141, 811, 181] / 3125

   hd_median = (181*s[0] + 811*s[1] + 1141*s[2]
                + 811*s[3] + 181*s[4]) / 3125
   ```

   Compute the integer-numerator form and independently check the decimal
   weighted sum within `1e-12`. Reject a nonfinite intermediate, nonascending
   order, nonpositive weight, weight sum other than one, or invariant
   disagreement. There is no runtime beta function, alternate quantile type,
   fitted weight, iteration, fallback estimator, or sample-size adaptation.
4. Above `+1e-12`, buy WTI. Below `-1e-12`, sell WTI. Equality inside the
   inclusive epsilon band consumes the month flat. Signal magnitude never
   changes risk.
5. Apply exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Attach one frozen `3.5 * ATR(20,D1)` broker hard
   stop, no target, and reject crossed or negative-spread quotes plus a
   genuinely positive spread above 1,500 points.
6. Close at the first later normalized broker-month boundary. A forty-day
   elapsed-calendar guard repairs only a survivor. Close duplicate,
   wrong-symbol, invalid-side, wrong-magic, or stopless owned exposure
   immediately.
7. Lock both current news axes and legacy news mode OFF and disable framework
   Friday flattening because the structural hold spans weekends.
8. Never retry, scale in, pyramid, grid, martingale, optimize, or substitute a
   raw mean, ordinary median, fixed trim, endpoint Winsorization, trimean,
   midhinge, pseudomedian, shortest interval, block median, Huber location,
   bisquare location, MAD-capped mean, Gastwirth location, sign score, or
   fitted weight.

Exact calendar-year membership, return orientation, ascending order, fixed
beta(3,3) interval weights, strict side, consumed attempt, fixed risk, hard
stop, and monthly lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_QUANTILE_ESTIMATOR_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. A peer-reviewed
  *Biometrika* paper and author-maintained implementation make the estimator
  reproducible. The five-sample conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact-year endpoints, exact
  sample, sort, beta parameters, fixed rational weights, independent
  invariant, epsilon, side, attempt state, risk, stop, spread, and exits are
  deterministic and locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, symbol metadata, positions, deals, and terminal state supply every
  runtime field. History, label, roll, financing, gap, and CFD-basis risks
  remain binding.
- R4 `PASS`: timestamps, completed closes, logarithms, sorting, fixed
  rational weighted sums, comparisons, ATR risk controls, and execution
  state only; no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_hd5_preallocation_dedup_20260830.json`, SHA-256
`08046E588E84E3AE010A4C3CA5F32F68CA1097D961731C5AD5401366D81E35A9`,
scanned 4,733 registry identities, 1,371 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and surfaced 13 expected same-calendar
family fuzzy matches for mandatory manual review.

Manual executable review establishes non-equivalence:

- Sorted returns `[-0.30,-0.30,+0.05,+0.25,+0.25]` give the candidate
  `+0.002384`, so it buys. The raw mean and endpoint-Winsorized mean are both
  `-0.01`, the middle-three trimmed mean is flat, and the midhinge is
  `-0.025`; those siblings sell or abstain.
- Sorted returns `[-0.30,-0.20,-0.05,+0.30,+0.30]` give the candidate
  `+0.007696`, so it buys. The ordinary median and Gastwirth location are
  `-0.05` and `-0.01`, while the Tukey trimean is flat; those siblings sell
  or abstain.
- Sorted returns `[-0.30,-0.30,+0.05,+0.20,+0.20]` give the candidate
  `-0.013488`, so it sells, while the ordinary median and Gastwirth location
  are `+0.05` and `+0.01` and therefore buy. Sign reflection reverses every
  strict mapping.
- `QM5_20099` and `QM5_41055` use an arithmetic mean or ordinary historical
  median. `QM5_41199`, `QM5_41201`, `QM5_41202`, `QM5_41227`, `QM5_41228`,
  and `QM5_41229` through `QM5_41233` use a fixed trim, inclusive-pair
  pseudomedian, endpoint Winsorization, chronological block median,
  shortest-three interval, quartile trimean, midhinge, redescending
  bisquare, MAD-capped mean, or Gastwirth location. None assigns the fixed
  positive beta(3,3) interval mass to all five order statistics.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_HARRELL_DAVIS_MEDIAN_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong return orientation, sort or weight defect,
current-month leakage, wrong side, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history.
Failure may not be rescued by changing the sample, estimator, weights,
direction, carrier, stop, spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
