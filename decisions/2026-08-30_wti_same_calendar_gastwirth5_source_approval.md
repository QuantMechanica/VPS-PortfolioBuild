# WTI Same-Calendar Five-Sample Gastwirth Location - Source Approval

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

- proposed slug: `wti-samecal-gast5`
- proposed strategy ID:
  `KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026_S01`
- proposed source ID:
  `KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: the Gastwirth robust location of the exact prior five matching-
  calendar-month WTI log returns, using GNU Scientific Library linear
  quantile interpolation
- lifecycle: follow the strict location sign for one broker month, with one
  consumed attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records and bounded official documentation
were read completely before this decision:

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
3. Gastwirth, Joseph L. (1966), "On Robust Procedures," *Journal of the
   American Statistical Association* 61(316), 929-948, DOI
   `10.1080/01621459.1966.10482185`. The paper introduces robust location
   procedures; the author bibliography at George Washington University and
   DOI metadata confirm the citation.
4. GNU Scientific Library 2.8, official Statistics documentation, sections
   "Median and Percentiles" and "Gastwirth Estimator," completely read on
   2026-08-30 at
   `https://www.gnu.org/software/gsl/doc/html/statistics.html`. It fixes the
   reproducible estimator and quantile convention used here: quantiles use
   `i=floor((n-1)f)`, `delta=(n-1)f-i`, and linear interpolation
   `(1-delta)*x[i]+delta*x[i+1]`; the Gastwirth location is
   `0.3*Q(1/3)+0.4*Q(1/2)+0.3*Q(2/3)`.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. Gastwirth and the
official GSL documentation supply the named robust-location family and an
implementation-grade quantile convention.

No source tests this exact conjunction. The exact five-year sample, GSL
interpolation choice, single continuous Darwinex CFD, fixed-dollar risk, ATR
stop, spread cap, attempt ledger, and operational lifecycle are transparent
QM falsification choices. No source return, coefficient, significance, alpha,
Sharpe ratio, drawdown, density, cost, WTI-only result, CFD equivalence,
decorrelation, or portfolio result transfers.

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
3. Sort a copy of the five returns ascending as `s[0]..s[4]`. For each
   `f` in `{1/3, 1/2, 2/3}`, use the exact GSL interpolation:

   ```text
   h     = (5 - 1) * f
   i     = floor(h)
   delta = h - i
   Q(f)  = (1 - delta) * s[i] + delta * s[i+1]
   ```

   Thus, for exactly five values:

   ```text
   Q(1/3) = (2*s[1] + s[2]) / 3
   Q(1/2) = s[2]
   Q(2/3) = (s[2] + 2*s[3]) / 3
   location = 0.3*Q(1/3) + 0.4*Q(1/2) + 0.3*Q(2/3)
            = 0.2*s[1] + 0.6*s[2] + 0.2*s[3]
   ```

   Compute through the quantile contract, retain the simplified equality as
   an invariant, and reject any nonfinite intermediate or disagreement above
   `1e-12`. There is no alternate quantile type, endpoint inclusion,
   interpolation fallback, iteration, winsorization, or scale estimate.
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
   bisquare location, MAD-capped mean, sign score, or fitted weight.

Exact calendar-year membership, return orientation, ascending order,
one-third/one-half/two-third GSL interpolation, `0.3/0.4/0.3` aggregation,
strict side, consumed attempt, fixed risk, hard stop, and monthly lifecycle
are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. A named JASA robust-
  procedures paper plus official GNU numerical documentation make the exact
  estimator reproducible. The five-sample conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact-year endpoints, exact
  sample, sort, quantile convention, weights, epsilon, side, attempt state,
  risk, stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, symbol metadata, positions, deals, and terminal state supply every
  runtime field. History, label, roll, financing, gap, and CFD-basis risks
  remain binding.
- R4 `PASS`: timestamps, completed closes, logarithms, sorting, fixed linear
  interpolation, weighted sums, comparisons, ATR risk controls, and execution
  state only; no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_gast5_preallocation_dedup_20260830.json`, SHA-256
`C9ADEE43102AC02EDE2BFCD5891EA639A115D59658DF730B9F1A899F0B120F17`,
scanned 4,732 registry identities, 1,370 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and one expected slug-family fuzzy
neighbor, `QM5_20099_wti-samecal`, for mandatory manual review.

Manual executable review establishes non-equivalence:

- Sorted returns `[-0.30,-0.28,+0.02,+0.24,+0.26]` give the candidate
  `0.2*(-0.28)+0.6*(+0.02)+0.2*(+0.24)=+0.004`, so it buys. The raw mean
  and the three-central-value trimmed mean are both negative, so those
  siblings sell. The trimean is exactly flat. The raw-MAD cap is inactive
  (`median=0.02`, `MAD=0.24`) and therefore remains the negative raw mean,
  so `QM5_41232` sells.
- Sorted returns `[-0.20,-0.15,+0.04,+0.05,+0.06]` give the candidate
  `+0.004`, so it buys. The middle-three equal-weight mean is `-0.02`, the
  GSL-compatible trimean is `-0.005`, the midhinge is `-0.05`, and the
  endpoint-Winsorized five-term mean is `-0.032`; those siblings sell.
- Sorted returns `[-0.25,-0.20,+0.01,+0.04,+0.05]` give the candidate
  `-0.026`, so it sells, while the ordinary median is positive and buys.
  Sign reflection reverses each strict mapping, so none is a one-sided
  numerical accident.
- `QM5_20099` and `QM5_41055` use an arithmetic mean or ordinary historical
  median. `QM5_41199`, `QM5_41201`, `QM5_41202`, `QM5_41227`, `QM5_41228`,
  `QM5_41229`, `QM5_41230`, `QM5_41231`, and `QM5_41232` use a fixed trim,
  inclusive-pair pseudomedian, endpoint Winsorization, chronological block
  median, shortest-three interval, quartile trimean, midhinge, redescending
  bisquare, or MAD-capped mean. None uses one-third GSL interpolation and the
  resulting fixed `0.2/0.6/0.2` central-order-statistic weights.

Verdict:
`FUZZY_FAMILY_MATCH_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_GSL_GASTWIRTH_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong return orientation, sort or quantile defect, wrong
weights, current-month leakage, wrong side, repeated entry, missing stop,
wrong lifecycle, nondeterminism, invalid risk mode, or insufficient history.
Failure may not be rescued by changing the sample, estimator, quantile type,
weights, direction, carrier, stop, spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
