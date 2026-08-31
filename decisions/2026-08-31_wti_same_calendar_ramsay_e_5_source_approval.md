# WTI Same-Calendar Ramsay-E Location — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue only while the governed whole-host
CPU ceiling remains clear. This decision does not authorize a manual tester
run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, and a `RISK_FIXED`
backtest preset. It excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-ramsaye5`
- proposed strategy ID:
  `KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026_S01`
- proposed source ID:
  `KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: a fixed 32-update Ramsay-E iteratively reweighted location over the
  exact prior five matching-calendar-month WTI log returns, initialized at
  their median with one frozen rescaled-MAD scale and `a=0.3`
- participation: follow the final robust location's strict sign
- lifecycle: hold one WTI position for one broker month, with one consumed
  attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable records were read completely before this decision:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open NBER Working Paper 20815 is
   represented by
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its complete-paper review
   record is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
3. The complete bounded Ramsay-E class and robust-location routine in the
   official statsmodels 0.15.0 source rendering were reviewed at
   `https://www.statsmodels.org/stable/_modules/statsmodels/robust/norms.html`.
   The 197,780-byte retrieval has SHA-256
   `52994832B273BCC5F1F4F890F62E513B815CC46A1E4436367A64547DACBA819D`;
   its durable receipt is
   `artifacts/qm5_wti_samecal_ramsaye5_statsmodels_retrieval_20260831.json`.
4. The complete governed soft-L1 packet
   `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026/source.md`,
   SHA-256
   `03C593131C02B34366CFDF420AD33DAF2202BC2969F1506A3EC49C056227E157`,
   preserves the already reviewed median start, rescaled-MAD frozen-scale,
   exact-five-year endpoint, and fixed-iteration plumbing. It transfers no
   soft-L1 weight or result.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. Official statsmodels
source identifies Ramsay's E as a soft-redescending M-estimator, fixes default
`a=0.3`, `psi(u)=u*exp(-a*abs(u))`, IRLS weight
`exp(-a*abs(u))`, median initialization, and the weighted-location update.

No source tests this conjunction. The single-WTI zero comparison, exact
five-year sample, raw MAD, `1.4826` scale, fixed 32-update path, continuous
Darwinex CFD, epsilon, fixed-dollar risk, ATR stop, spread cap, attempt
ledger, and operational lifecycle are transparent QM falsification choices.
No source return, alpha, Sharpe ratio, drawdown, density, cost, WTI-only
result, CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair malformed owned exposure and close the prior package before
   entry-only gates. Persist broker `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, or submission; never retry that month.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in each exact year
   `Y-5..Y-1`. Require strict adjacent-month endpoints, a confirming later D1
   bar, positive finite closes, and all five returns. Missing or invalid
   history consumes the month flat; no substitute year or shorter sample.
3. Preserve returns in chronological year order and sort only copies:

   ```text
   s      = sort_ascending(copy(r))
   median = s[2]
   d[i]   = abs(r[i] - median)
   a      = sort_ascending(copy(d))
   MAD    = a[2]
   scale  = 1.4826 * MAD

   mu[0] = median
   for j = 0..31:
     u[i]      = (r[i] - mu[j]) / scale
     weight[i] = exp(-0.3 * abs(u[i]))
     mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])
   ```

   Reject nonpositive or nonfinite MAD, scale, absolute standardized
   residual, exponent, weight, weight sum, weighted sum, or intermediate
   location. A finite exponent that underflows to a zero weight is rejected;
   the five-observation decision fails closed rather than silently deleting
   an observation.
4. With `epsilon=1e-12`, buy WTI only if `mu[32] > +epsilon`. Sell WTI only
   if `mu[32] < -epsilon`. The inclusive epsilon band consumes the month
   flat. Location magnitude never changes risk.
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
8. Never retry, scale in, pyramid, grid, martingale, optimize, refit scale,
   stop early for convergence, select another start, or substitute a mean,
   median, soft-L1, Cauchy, arctangent, Huber, Hampel, bisquare, trim,
   Winsorized, capped, or order-statistic location.

Exact calendar-year membership, return orientation, median and raw MAD,
rescaled frozen scale, Ramsay-E `a`, exponential weight, 32 updates, epsilon,
consumed attempt, fixed risk, hard stop, and monthly lifecycle are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_RAMSAY_E_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. Official statsmodels
  source fixes the Ramsay-E definition and default constant. The fitted
  five-return trading conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, median, MAD, scale, `a`, exponential weight, update count, epsilon,
  side, attempt state, risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, metadata, positions, deals, and terminal state supply every runtime
  field. History, label, roll, financing, gap, and CFD-basis risks remain.
- R4 `PASS`: timestamps, completed closes, logarithms, deterministic sorting,
  absolute deviations, exponentials, fixed multiplication, division,
  comparisons, ATR risk controls, and execution state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_ramsaye5_preallocation_dedup_20260831.json`,
SHA-256
`9F3FAEC5AE93C269494C4787DBFD87EF3E6B19D9926C7925DAD302E3CDF2459E`,
scanned 4,739 registry identities, 1,377 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and surfaced expected fuzzy
same-calendar/Hampel/Cauchy/arctangent/soft-L1 relatives for manual review.

On `[-0.135,-0.010,-0.005,+0.005,+0.050]`, the locked Ramsay-E path ends at
approximately `+0.000567268656` and buys. On otherwise matched fixed-scale
paths, soft-L1 ends near `-0.003712679327`, Cauchy near
`-0.002607060341`, and arctangent near `-0.003417275042`; the raw mean is
`-0.019` and median `-0.005`. All five sell. On
`[-0.130,-0.025,+0.005,+0.020,+0.190]`, Ramsay-E ends near
`-0.000066275832` and sells while soft-L1, arctangent, raw mean, and raw
median buy. Sign reflection reverses every strict mapping.

Ramsay-E uses exponential residual attenuation with positive weight for each
finite residual. That differs from soft-L1's inverse square root, Cauchy's
quadratic rational weight, arctangent's quartic rational weight, Huber's
unit/inverse-linear curve, and the exact-zero tails of Hampel and bisquare.
The locked fixtures demonstrate actual decision disagreements, not a renamed
lookback or threshold.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_RAMSAY_E_EXPONENTIAL_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year; this is a pre-result estimate, not a source result.
Q02 retires on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong normalized endpoints, missing exact
years, wrong median, MAD, scale, `a`, weight, update count, epsilon or side,
current-month leakage, repeated entry, missing stop, wrong lifecycle,
nondeterminism, invalid risk mode, or insufficient history. Failure may not
be rescued by changing the sample, estimator, direction, carrier, stop,
spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict Q01 and only if the governed whole-host CPU check remains clear.
At a ceiling, stop before queue mutation and record a non-live handoff.
