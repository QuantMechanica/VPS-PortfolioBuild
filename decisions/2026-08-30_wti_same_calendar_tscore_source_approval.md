# WTI Same-Calendar One-Standard-Error Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its hard CPU
ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly permits structural WTI seasonality, requires
reputable-source criteria and `RISK_FIXED` backtests, and forbids live and
portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-samecal-tstat`
- proposed strategy ID: `KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026_S01`
- proposed source ID: `KELOHARJU-RCORE-WTI-SAMECAL-TSTAT-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after each genuine normalized broker-month
  transition
- state: up to ten exact prior-year WTI returns for the upcoming calendar
  month, with at least five observations
- statistic: arithmetic mean divided by its sample standard error
- lifecycle: follow the seasonal sign only outside a strict
  one-standard-error band, until the next broker month

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

Extraction may use only these completely read governed records:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   covering Keloharju, Linnainmaa, and Nyberg (2016), "Return
   Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`, including the complete 57-page NBER review.
2. Commit-pinned R Core primary software
   `src/library/stats/R/t.test.R` at
   `bac583951b728e97b9786804d3b4081f0fe18df5`, blob
   `2c1e8d19a3150978e1b56f3ee8985f43a17382f6`, read completely through the
   deterministic GitHub route recorded in
   `artifacts/qm5_wti_samecal_tstat_source_route_20260830.json`.

Keloharju et al. supply recurring same-calendar commodity-return information,
explicit crude-oil membership, monthly renewal, and a five-year history floor.
The R Core source fixes only the transparent one-sample arithmetic:
`sample_variance`, `standard_error=sqrt(sample_variance/n)`, and
`t=(mean-0)/standard_error`.

No source tests this exact confidence-gated single-WTI Darwinex CFD rule, the
strict threshold, fixed-risk sizing, ATR stop, spread ceiling, or the current
portfolio. No source return, alpha, significance, profit factor, drawdown,
trade density, cost, futures/CFD equivalence, decorrelation, or portfolio
result transfers. The locked `abs(t)>1` rule is a QM falsification threshold,
not a conventional-significance claim; runtime never computes a p-value.

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
3. Compute `mean=sum(r)/n`, sample variance with denominator `n-1`,
   `se=sqrt(variance/n)`, and `t=mean/se`. Require finite positive variance
   and standard error.
4. At `t > +1.0 + 1e-10`, buy WTI. At `t < -1.0 - 1e-10`, sell WTI.
   Equality, the inclusive interior band, or invalid state consumes the month
   flat. Signal magnitude never changes risk.
5. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Attach a
   frozen `3.5*ATR(20,D1)` broker hard stop, no target, and reject crossed
   quotes, negative modeled spread, or spread above 1,500 WTI points.
6. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no p-value lookup, distribution table, mean-only fallback, rank/trim/Winsor/
Huber fallback, current-month input, contrarian flip, magnitude sizing, curve,
inventory, event, volume, optimizer artifact, trained output, banned signal
indicator, or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_SINGLE_CFD_AND_LOCKED_THRESHOLD_RISK`: a complete-read,
  DOI-bearing peer-reviewed trading lineage supplies same-calendar commodity
  information and explicit crude-oil membership; commit-pinned primary
  software fixes the statistic. The exact conjunction remains untested.
- R2 `PASS`: calendar, normalized endpoints, exact-year bound, sample floor,
  mean, `n-1` variance, standard error, strict score band, side, attempt,
  fixed risk, stop, spread, and lifecycle are deterministic and locked.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native `XTIUSD.DWX` D1 history and MT5 state provide every
  runtime field; history, label, roll, financing, and CFD-basis risks remain
  explicit.
- R4 `PASS`: dates, completed prices, logarithms, sums, sample variance,
  square root, comparisons, ATR-risk controls, and execution state only; no
  trained output, banned signal indicator, or external runtime feed.

## Non-Duplicate Decision

The corrected-root canonical checker scanned 4,710 registry identities,
1,356 card files, and all 45 Strategy Wiki nodes. It found no exact collision
and returned two expected fuzzy neighbors. Receipt:
`artifacts/qm5_wti_samecal_tstat_preallocation_dedup_20260830.json`, SHA-256
`DB72E22F089B1BAB6AD22C1C597DC35D4D98AED64E7D8C96DA51550A8D1596BF`.

Manual review fixes the executable boundary:

- `QM5_20099_wti-samecal` follows every nonzero raw arithmetic mean. This
  candidate divides the same mean by its sample standard error and abstains
  throughout a strict fixed band.
- `QM5_41191_wti-samecal-srank` converts observations to signed absolute
  ranks and discards metric distance; it has no mean standard error.
- `QM5_41199`, `QM5_41201`, `QM5_41202`, and `QM5_41204` use trimmed-mean,
  Hodges-Lehmann, Winsorized-mean, and fixed-scale Huber estimators. None has
  `n-1` sample variance, a mean standard error, or the fixed confidence gate.
- `QM5_41209_wti-seas-resid-mom` standardizes the just-completed WTI return
  against earlier occurrences of that completed month and follows the
  residual in the next month. This candidate instead forecasts the upcoming
  month from its historical same-calendar distribution.
- `QM5_41210_xauxag-samecal-tstat` computes the statistic on synchronized
  XAU-minus-XAG relative returns and manages an opposite-leg metals basket.
  This candidate reads and trades only WTI; carrier, return orientation,
  position topology, risk, and realized exposure are load bearing.

For the fixed WTI-return vector
`[0.020,0.015,0.010,0.005,0.001,-0.040]`, the raw mean is positive while the
one-sample score is inside `[-1,+1]`. `QM5_20099` buys WTI; this candidate
stays flat. Sample dispersion and the abstention band are therefore
load-bearing rather than a parameter rename.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_MEAN_STANDARD_ERROR_GATE_MONTHLY_DIRECTIONAL_CARRIER`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, sample, mean, variance, standard-error,
score, threshold, side, attempt, fixed-risk, stop, spread, lifecycle, or
determinism defect. A failed result may not be rescued by changing the sample,
threshold, direction, carrier, stop, hold, spread, or retry rule.

WTI is economically distinct from the stated XAU/SP500/NDX/XNG book, but
that does not prove low realized correlation. Only unchanged Q09 owns
portfolio overlap. This approval excludes manual backtests;
live/demo/shadow/stress/optimization setfiles; terminal control; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; and correlation waivers.
