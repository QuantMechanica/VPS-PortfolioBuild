# QM5_41159 WTI Monthly Least-Absolute-Deviation Trend — G0 Decision

Date: 2026-08-25

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41159_wti-lad-tr`. At the start of each broker month, the candidate
selects thirteen consecutive completed WTI month-end closes, fits the exact
time slope that minimizes total absolute vertical error by exhaustively
evaluating all 78 pairwise residual-order breakpoints, and follows the strict
slope sign for one broker month.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, build review, and one `RISK_FIXED` Q02 enqueue if the fresh
host/tester CPU guards permit. Approval does not pre-judge economics,
decorrelation, certification, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. The approved packet preserves a
  complete read of Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
  Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`, with explicit WTI membership, plus the
  complete author-preprint read recorded for Schweikert (2018), *Journal of
  Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, using Koenker-Bassett check loss. The exact
  median-regression WTI conjunction is an explicitly untested QM translation.
- R2: `PASS`. Symbol, clock, thirteen consecutive month keys, latest-close
  selection, log coordinate, all 78 candidate slopes, residual median index
  6, chronological absolute-loss sum, fixed `1e-12` equality guard, final
  minimizer median, direction, attempt, fixed risk, stop, spread, and exit are
  fully mechanical.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 state supply all runtime inputs. Q02 owns actual
  history sufficiency, fills, and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms,
  arithmetic, sorting, absolute loss, and comparisons only. ATR is risk-only.
  No trained logic, banned signal indicator, optimizer output, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/MOP-KOENKER-BASSETT-WTI-LAD-2026/source.md`, SHA-256
`7F4630DCF4D10D2004F94FA098712810048E05F56A9E8EFF45F85079F3752D5A`.
Its durable approval is
`decisions/2026-08-25_wti_monthly_lad_trend_source_approval.md`.

No source return, alpha, probability, trade density, risk, cost, continuous-
CFD equivalence, estimator superiority, or portfolio correlation transfers.
The LAD arithmetic, WTI CFD mapping, fixed-dollar risk, hard stop, spread cap,
and lifecycle are falsifiable implementation hypotheses.

## Locked Statistical Contract

For thirteen consecutive completed broker-month-end WTI closes, oldest to
newest:

```text
x[i] = i
y[i] = ln(C[i]), i=0..12

for every 0 <= i < j <= 12:
  b[i,j] = (y[j] - y[i]) / (j - i)
require exactly 78 finite candidates

for each candidate b:
  r[i] = y[i] - b*x[i]
  a[b] = ascending(r[0..12])[6]
  L[b] = sum(i=0..12, abs(y[i] - a[b] - b*x[i]))

minimum = min(L[b])
M = ascending([b where abs(L[b] - minimum) <= 1e-12])
require len(M) >= 1
lad_slope = ordinary_median(M)

lad_slope > 0 => BUY XTIUSD
lad_slope < 0 => SELL XTIUSD
lad_slope = 0 or invalid => FLAT
```

Require the latest close in each required month, strict chronological order,
positive finite closes, positive month-index denominators, exact candidate,
residual, and objective counts, exact median indexes, chronological loss
summation, fixed tie guard, ordinary median convention, and finite results.
There is no endpoint agreement, magnitude threshold, alternate solver, fitted
slope bound, or fallback signal.

Consume the current `yyyymm` attempt before every fallible gate. Open at most
one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop and no target.
Close at the first later broker month; forty days is stale repair only. Both
news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,658 registry rows, 1,311 cards, and 45 current
Wiki nodes with no exact or fuzzy match. Evidence:
`artifacts/qm5_wti_lad_tr_preallocation_dedup_20260825.json`.

Theil-Sen takes a global median of 78 slopes. Repeated median takes thirteen
pivot-specific inner medians and one outer median. OLS minimizes squared loss
and applies an `R^2` gate. This card profiles a median intercept for every
candidate and minimizes absolute vertical error. On the fixed valid log-price
vector `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
negative `-0.002` while Theil-Sen, repeated median, OLS, and endpoint slope
are positive, so the rules are not parameter aliases.

The existing XAU/XAG quantile-regression EA fits three 504-observation cross-
metal relationships and trades two-leg envelope reversion; this card fits one
thirteen-point time slope and trades direct WTI continuation. Adjacent-return
robust location, weighted return, sign vote, rank, and path-efficiency systems
use different objects or aggregation.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41159` via the atomic `farmctl reserve-ea-ids` path;
- slug: `wti-lad-tr`;
- strategy ID: `MOP-KOENKER-BASSETT-WTI-LAD-TREND-2026_S01`;
- intended slot 0: `XTIUSD.DWX`, magic `411590000`;
- expected cadence: approximately ten to twelve positions per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection;
- fail on current-month leakage, missing/duplicate month, nonlatest or stale
  close, wrong log coordinate, pair membership, denominator, candidate count,
  residual median, objective, equality guard, minimizer, side, attempt, risk
  mode, hard stop, exit, or determinism; and
- no post-result change to sample, estimator, direction, carrier, equality
  guard, risk, stop, hold, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the locked D1 setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
