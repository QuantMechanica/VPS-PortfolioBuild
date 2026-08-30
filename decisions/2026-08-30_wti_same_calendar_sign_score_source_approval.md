# WTI Same-Calendar Sign-Score Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its hard CPU
ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly permits structural WTI seasonality,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-signscore`
- proposed strategy ID:
  `KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026_S01`
- proposed source ID:
  `KELOHARJU-PAPAILIAS-RCORE-WTI-SAMECAL-SIGNSCORE-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after each genuine normalized broker-month
  transition
- state: nonnegative-return count across up to ten exact prior-year WTI
  returns for the upcoming calendar month, with at least five observations
- statistic: signed one-sample Bernoulli score against null probability 0.5
- lifecycle: follow only a sign imbalance outside a strict one-standard-error
  band, until the next broker month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

Extraction may use only these completely read governed records:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   covering Keloharju, Linnainmaa, and Nyberg (2016), "Return
   Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, including the complete 57-page NBER version.
2. `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`, SHA-256
   `5EFDB021EE4D1B00A2D7CE356A5EACA85511896C4FD999A5B069B5F936ABA32F`,
   covering Papailias, Liu, and Thomakos (2021), "Return Signal Momentum,"
   *Journal of Banking & Finance* 124, 106063, DOI
   `10.1016/j.jbankfin.2021.106063`, including the complete accepted
   manuscript and appendices.
3. Commit-pinned R Core primary software
   `src/library/stats/R/prop.test.R` at
   `9deb2ebef8d0a2fe5cae965697ee4751af857bd1`, blob
   `fc38bd4be1ba8630dbd224162ab5873ae6ac5261`, SHA-256
   `59fb39522e418d9e1db8bac0626354cd7e87ed996747032ddce5fc406a57d694`,
   read completely through the public primary-source route recorded in
   `artifacts/qm5_wti_samecal_signscore_source_route_20260830.json`.

Keloharju et al. supply recurring same-calendar commodity-return information,
explicit crude-oil membership, monthly renewal, and a five-year history
floor. Papailias et al. supply the deterministic nonnegative-return binary
map and explicit WTI membership. R Core fixes the one-sample null at 0.5 and
the uncorrected Pearson score arithmetic.

No source tests this exact sign-score conjunction, the strict score band, a
single Darwinex WTI CFD, fixed-risk sizing, ATR stop, spread ceiling, or the
current portfolio. No source return, alpha, significance, profit factor,
drawdown, trade density, cost, futures/CFD equivalence, decorrelation, or
portfolio result transfers. The locked `abs(score)>1` rule is a QM
falsification threshold, not a conventional-significance claim; runtime
never computes a p-value.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure and persist broker `yyyymm` before every fallible
   entry gate. Never retry that month after any downstream outcome.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in exact years
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. Missing older years are skipped without replacement;
   require at least five valid observations. No current-month price enters.
3. Map each finite return to `1` when it is nonnegative and `0` when it is
   negative. Let `x` be the nonnegative count and `n` the valid sample count.
4. With null `p0=0.5` and no continuity correction, compute the signed score
   `z=(x-n*p0)/sqrt(n*p0*(1-p0))=(2*x-n)/sqrt(n)`. Require a finite positive
   denominator and finite score.
5. At `z > +1.0 + 1e-10`, buy WTI. At `z < -1.0 - 1e-10`, sell WTI.
   Equality, the inclusive interior band, or invalid state consumes the
   month flat. Signal magnitude never changes risk.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Attach a
   frozen `3.5*ATR(20,D1)` broker hard stop, no target, and reject crossed
   quotes, negative modeled spread, or spread above 1,500 WTI points.
7. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There
is no p-value lookup, continuity correction, magnitude weighting, arithmetic
mean, median, rank weight, trimmed/Winsor/Huber fallback, current-month input,
contrarian flip, magnitude sizing, curve, inventory, event, volume, optimizer
artifact, trained output, banned signal indicator, or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_AND_SMALL_SAMPLE_RISK`: two complete-
  read, DOI-bearing peer-reviewed trading lineages supply same-calendar
  commodity information, WTI membership, and the return-sign map; commit-
  pinned primary software fixes the score arithmetic. The exact conjunction
  and fixed threshold remain untested.
- R2 `PASS`: calendar, normalized endpoints, exact-year bound, sample floor,
  binary map, null probability, score denominator, strict band, side,
  attempt, fixed risk, stop, spread, and lifecycle are deterministic and
  locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history and MT5 state provide every
  runtime field; history, label, roll, financing, and CFD-basis risks remain
  explicit.
- R4 `PASS`: dates, completed prices, logarithms, integer counts, square
  root, comparisons, ATR-risk controls, and execution state only; no trained
  output, banned signal indicator, or external feed.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,711 registry identities,
1,357 card files, and all 45 Strategy Wiki nodes. It found no exact collision
and returned one expected fuzzy neighbor. Receipt:
`artifacts/qm5_wti_samecal_signscore_preallocation_dedup_20260830.json`,
SHA-256
`2DDE757731CADAA6E29949741C2E7E9075E59764F402022BF435B7EBC592EBD6`.

Manual review fixes the executable boundary:

- `QM5_20099_wti-samecal` takes the sign of the arithmetic mean of return
  magnitudes and always chooses a side when the mean is nonzero. This
  candidate discards magnitude and may stay flat inside a sample-size-aware
  sign band. For `[0.09,-0.01,-0.01,-0.01,-0.01]`, the raw mean is positive
  while this score is below `-1`; the existing EA buys and this one sells.
- `QM5_41059_wti-samecal-hit` uses the same binary signs but buys at
  `positive_frequency>=0.40` and sells otherwise, with no symmetric
  confidence band. At three nonnegative and three negative observations it
  buys; this candidate has `z=0` and stays flat.
- `QM5_41191`, `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use
  signed ranks or robust return magnitudes. None reduces the sample to an
  unweighted Bernoulli count and standardizes it by null variance.
- `QM5_41209_wti-seas-resid-mom` follows the standardized magnitude surprise
  of the just-completed month into the next month. This candidate forecasts
  the upcoming named month from historical binary signs only.
- `QM5_41211_wti-samecal-tstat` standardizes the arithmetic mean by its
  sample standard error. For `[0.001,0.001,0.001,0.001,-0.100]`, this
  candidate buys on four of five nonnegative signs while the magnitude
  t-score remains inside its flat band.

The binary information object, null variance, sample-size-aware score, and
symmetric abstention band are load bearing rather than a threshold rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_BERNOULLI_SIGN_SCORE_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, sample, binary-map, null, score, threshold,
side, attempt, fixed-risk, stop, spread, lifecycle, or determinism defect. A
failed result may not be rescued by changing the sample, threshold, tie map,
direction, carrier, stop, hold, spread, or retry rule.

WTI is economically distinct from the stated XAU/SP500/NDX/XNG book, but
that does not prove low realized correlation. Only unchanged Q09 owns
portfolio overlap. This approval excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
