# WTI Same-Calendar Five-Sample Hampel Location — Source Approval

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

- proposed slug: `wti-samecal-hampel5`
- proposed strategy ID:
  `KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026_S01`
- proposed source ID:
  `KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: a frozen-scale Hampel redescending location fitted to the exact prior
  five matching-calendar-month WTI log returns
- lifecycle: follow the strict fitted-location sign for one broker month,
  with one consumed attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records and bounded primary records were
read completely before this decision:

1. Keloharju, Matti; Linnainmaa, Juhani T.; and Nyberg, Peter (2016),
   "Return Seasonalities," *The Journal of Finance* 71(4), 1557-1590,
   DOI `10.1111/jofi.12398`. The complete open NBER Working Paper 20815 is
   represented by
   `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`.
2. Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012),
   "Time Series Momentum," *Journal of Financial Economics* 104(2),
   228-250, DOI `10.1016/j.jfineco.2011.11.003`. The complete-paper review
   record is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
3. Hampel, Frank R.; Ronchetti, Elvezio M.; Rousseeuw, Peter J.; and Stahel,
   Werner A. (1986), *Robust Statistics: The Approach Based on Influence
   Functions*, Wiley. This is the named reference for the Hampel proposal in
   the CRAN `MASS` manual.
4. Venables, W. N.; and Ripley, B. D. (2002), *Modern Applied Statistics with
   S*, fourth edition, Springer, together with the author-maintained CRAN
   `MASS` documentation and `R/rlm.R` implementation for `psi.hampel`. The
   relevant manual and function source were read completely on 2026-08-30 at
   `https://stat.ethz.ch/CRAN/web/packages/MASS/MASS.pdf` and
   `https://rdrr.io/cran/MASS/src/R/rlm.R`. They fix the default constants
   `a=2`, `b=4`, `c=8`, define the returned weight as `psi(u)/u`, and identify
   iteratively reweighted least squares plus the non-unique-minimum risk of a
   redescending score.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. Hampel et al. plus the
author-maintained `MASS` manual and implementation supply the named
redescending influence function and exact default numerical convention.

No source tests this conjunction. The exact five-year sample, single
continuous Darwinex CFD, frozen raw-MAD scale, median initialization, fixed
32 updates, zero comparison, fixed-dollar risk, ATR stop, spread cap, attempt
ledger, and operational lifecycle are transparent QM falsification choices.
No source return, coefficient, alpha, Sharpe ratio, drawdown, density, cost,
WTI-only result, CFD equivalence, decorrelation, or portfolio result transfers.

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
3. For returns `r[0]..r[4]`, sort copies to obtain the odd median `m` and the
   odd median absolute deviation `MAD`. Freeze:

   ```text
   scale = 1.4826 * MAD
   mu[0] = m
   ```

   Reject a nonpositive or nonfinite `MAD` or scale. For exactly 32 updates,
   set `u[i]=(r[i]-mu[j])/scale` and apply the CRAN `MASS::psi.hampel`
   defaults as weights:

   ```text
   U = abs(u)

   w(u) = 1                                when U <= 2
          2/U                              when 2 < U <= 4
          2*(8-U)/(4*U)                    when 4 < U < 8
          0                                when U >= 8

   mu[j+1] = sum(w[i]*r[i]) / sum(w[i]), j=0..31
   ```

   The `u=0` weight is exactly one. Boundary inclusion is load-bearing:
   `U=2` remains unit weight, `U=4` has weight one half, and `U=8` has zero
   weight. Reject any nonfinite intermediate, negative weight, nonpositive
   weight sum, or location failure. Scale never updates and there is no early
   convergence stop, alternate start, or local-minimum search.
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
   raw mean, median, trim, Winsorization, pseudomedian, shortest interval,
   block median, trimean, midhinge, Huber, bisquare, MAD cap, Gastwirth,
   Harrell-Davis, score, rank, fitted scale, or alternate Hampel constants.

Exact calendar-year membership, return orientation, median/MAD convention,
frozen scale, `2/4/8` boundaries, 32 updates, strict side, consumed attempt,
fixed risk, hard stop, and monthly lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. A canonical robust-
  statistics book plus author-maintained CRAN documentation and source make
  the Hampel convention reproducible. The conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact sample,
  median/MAD, scale, constants, boundary inclusions, weights, update count,
  epsilon, side, attempt state, risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, metadata, positions, deals, and terminal state supply every runtime
  field. History, label, roll, financing, gap, and CFD-basis risks remain
  binding.
- R4 `PASS`: timestamps, completed closes, logarithms, sorting, absolute
  deviations, fixed piecewise weights, comparisons, ATR risk controls, and
  execution state only; no trained output, banned signal indicator, external
  runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_hampel5_preallocation_dedup_20260830.json`,
SHA-256
`21A13A996AC51D7DF59C019A5333463D71A6F9FE68CFE7CADB8AD517088E6AD9`,
scanned 4,734 registry identities, 1,372 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and surfaced 13 expected same-calendar
family fuzzy matches for mandatory manual review.

For the sorted return fixture
`[-0.050,-0.005,+0.002,+0.005,+0.080]`, the locked Hampel iteration finishes
near `-0.00580512` and therefore sells. On the same fixture:

- the arithmetic mean is `+0.0064` and buys;
- the ordinary median is `+0.002` and buys;
- the 32-step five-sample bisquare location is near `+0.000695375` and buys;
- the Harrell-Davis location is near `+0.00246784` and buys; and
- the Gastwirth location is `+0.0008` and buys.

The sign-reflected fixture reverses every mapping. The existing Huber card
requires ten exact years and never gives a finite tail observation zero
influence. The bisquare sibling uses a smooth squared compact-support weight,
whereas this rule has unit, plateau-decay, linear-redescending, and zero
regions at exact `2/4/8` standardized boundaries. Mean, median, trim, Winsor,
pseudomedian, shortest-half, block-median, trimean, midhinge, MAD-cap,
Gastwirth, Harrell-Davis, t-score, sign-score, rank, and recency siblings use
different information maps or participation gates.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_HAMPEL_248_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year. Q02 retires on zero positions, fewer than five in any
full scored year, nonpositive governed economics, wrong normalized endpoints,
missing exact years, wrong median/MAD, scale, boundary, weight, update count,
or side, current-month leakage, repeated entry, missing stop, wrong lifecycle,
nondeterminism, invalid risk mode, or insufficient history. Failure may not
be rescued by changing the sample, scale, constants, iterations, direction,
carrier, stop, spread, hold, or retry policy.

The WTI carrier and recurring calendar clock target an exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
if the governed exact-path tester count and whole-host CPU checks pass. At a
ceiling, stop before queue mutation and record a non-live handoff.
