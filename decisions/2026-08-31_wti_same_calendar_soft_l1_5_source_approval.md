# WTI Same-Calendar Soft-L1 Location — Source Approval

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

- proposed slug: `wti-samecal-softl1-5`
- proposed strategy ID:
  `KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026_S01`
- proposed source ID: `KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine normalized
  broker-month transition
- state: a fixed 32-update soft-L1 iteratively reweighted location over the
  exact prior five matching-calendar-month WTI log returns, initialized at
  their median with one frozen rescaled-MAD scale
- participation: follow the final robust location's strict sign
- lifecycle: hold one WTI position for one broker month, with one consumed
  attempt and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records were read completely before this
decision:

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
3. The complete `scipy.optimize.least_squares` reference page maintained by
   the SciPy community was already reviewed and approved on 2026-08-31. Its
   governed 93,197-byte retrieval had SHA-256
   `CD8BCEEF256035736DDDE8E0F690C2487EFEFD5AFA773AEB50C822E5AF632435`;
   the durable complete-page record is
   `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-ARCTAN5-2026/source.md`
   at commit `99c197e13`.
4. The complete governed Cauchy packet
   `strategy-seeds/sources/KELOHARJU-SCIPY-WTI-SAMECAL-CAUCHY5-2026/source.md`,
   SHA-256
   `858FC0B9A828F87CD9590DA49646864629B9540C77C2390D5D2947BD4B39E2EC`,
   preserves the already reviewed median start, rescaled-MAD frozen scale,
   fixed-iteration robust-location convention, and local implementation
   risks.

A fresh generic-page retrieval was routed through the governed source reader
and classified `DEFERRED:SOURCE_POLICY`; receipt:
`artifacts/qm5_wti_samecal_softl1_5_source_route_20260831.json`. No proxy,
mirror, alternate scraper, or inferred page text was used. This decision
reuses only the earlier approved complete-page record and its hash.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
return information, monthly renewal, a five-year history floor, and explicit
crude-oil membership. Moskowitz, Ooi, and Pedersen supply explicit NYMEX WTI
membership, own-return direction, and monthly renewal. The approved SciPy
record supplies the soft-L1 loss and scale convention. The governed Cauchy
packet supplies only the existing deterministic fixed-path plumbing.

No source tests this conjunction. The single-WTI zero comparison, exact
five-year sample, median start, `1.4826*MAD` scale, derivative-weight
translation, exactly 32 updates, continuous Darwinex CFD, epsilon,
fixed-dollar risk, ATR stop, spread cap, attempt ledger, and operational
lifecycle are transparent QM falsification choices. No source return, alpha,
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
   `Y-5..Y-1`. Require strict adjacent-month endpoints, a confirming later D1
   bar, positive finite closes, and all five returns. Missing or invalid
   history consumes the month flat; no substitute year or shorter sample is
   permitted.
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
     weight[i] = 1 / sqrt(1 + u[i]^2)
     mu[j+1]   = sum(weight[i] * r[i]) / sum(weight[i])
   ```

   The weight is the first derivative of SciPy's documented soft-L1 loss
   `rho(z)=2*(sqrt(1+z)-1)` under `z=u^2`:
   `rho'(z)=1/sqrt(1+z)`. Reject nonpositive or nonfinite MAD, scale,
   radicand, root, weight, weight sum, weighted sum, or intermediate
   location.
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
   stop early for convergence, select another start after the fact, or
   substitute a raw mean, median, Cauchy, arctangent, Huber, Hampel,
   bisquare, trim, Winsor, capped, or order-statistic location.

Exact calendar-year membership, return orientation, median and raw MAD,
rescaled frozen scale, soft-L1 derivative weight, 32 updates, epsilon,
consumed attempt, fixed risk, hard stop, and monthly lifecycle are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_SOFT_L1_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  named-author, DOI-bearing, peer-reviewed trading papers with complete-read
  evidence support the same-calendar information object, explicit WTI
  carrier, own-return direction, and monthly renewal. A previously approved
  complete official SciPy page fixes the soft-L1 loss and scale convention.
  The derivative-weight trading conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, median, MAD, scale, weight, update count, epsilon, side, attempt
  state, risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history plus MT5-native broker time,
  quotes, metadata, positions, deals, and terminal state supply every runtime
  field. History, label, roll, financing, gap, and CFD-basis risks remain
  binding.
- R4 `PASS`: timestamps, completed closes, logarithms, deterministic sorting,
  absolute deviations, square roots, fixed multiplication, division,
  comparisons, ATR risk controls, and execution state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_softl1_5_preallocation_dedup_20260831.json`,
SHA-256
`0ECF970B9E8EB577F9EE375CF8D8E8881BA1DE6141C6E7B8F9667C45C01FD006`,
scanned 4,738 registry identities, 1,376 cards, and all 45 current Strategy
Wiki nodes. It found no exact identity and surfaced expected fuzzy
same-calendar, Cauchy, arctangent, Hampel, and Huber relatives for mandatory
manual review.

For sorted returns `[-0.120,-0.075,-0.020,+0.115,+0.120]`, raw MAD is
`0.100`, frozen scale is `0.14826`, and the locked soft-L1 iteration ends at
approximately `+0.001324252685`, so this card buys. On the otherwise matched
fixed-scale paths, Cauchy ends near `-0.004100768370` and arctangent near
`-0.004348219120`; both sell. The ordinary median also sells. Sign reflection
reverses every strict mapping.

Soft-L1 uses `1/sqrt(1+u^2)` and therefore retains heavier tail influence
than Cauchy's `1/(1+u^2)` and arctangent's `1/(1+u^4)`. Huber has a unit core
and inverse-linear tail under a separate ten-year sample; bisquare and Hampel
reach exact zero tail weight. On
`[-0.120,-0.115,-0.110,+0.155,+0.200]`, the locked soft-L1 location is about
`-0.100961055448` while the raw mean is `+0.002`; soft-L1 is therefore not a
renamed raw mean either.

Verdict:
`FUZZY_FAMILY_MATCHES_RESOLVED_AS_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_SOFT_L1_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed WTI positions per
full post-warm-up year; this is a pre-result estimate, not a source result.
Q02 retires on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong normalized endpoints, missing exact
years, wrong median, MAD, scale, weight, update count, epsilon or side,
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
