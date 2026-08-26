# QM5_41160 XAU/XAG Monthly LAD Reversion — G0 Decision

Date: 2026-08-26

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41160_xauxag-mlad-rv`. At the first synchronized executable tick of each
broker month, the candidate selects thirteen consecutive synchronized
completed month-end gold/silver close pairs, fits the exact
least-absolute-deviation time slope of the gold-minus-silver log-ratio path,
and fades its sign with an equal-target-notional XAU/XAG package for one
broker month.

The candidate may proceed through card lint, governed magic allocation,
resolver regeneration, source build, deterministic reference tests, strict
compile/Q01, build review, and one logical `RISK_FIXED` Q02 enqueue if the
fresh host/tester CPU guard permits. Approval does not pre-judge economics,
neutrality, decorrelation, certification, or portfolio admission.

## Gate Findings

- R1: `PASS_WITH_ESTIMATOR_TRANSLATION_RISK`. The approved packet preserves
  Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, official CME gold/silver spread lineage,
  and complete governed exact median-regression arithmetic. The paired LAD
  carrier and contrarian next-month direction are explicitly untested QM
  translations.
- R2: `PASS`. Symbols, clock, synchronization, thirteen consecutive month
  keys, latest pair selection, chronological ratios, all 78 candidate slopes,
  residual-median intercept, absolute objective, equality guard, final
  median, sides, one-attempt state, equal-notional aggregate risk, stops,
  atomicity, and exit are fully mechanical.
- R3: `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus native MT5 state supply all
  runtime inputs. Q02 owns actual history sufficiency, fills, and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms, absolute
  loss, arithmetic, sorting, and comparisons only. ATR is risk-only. No
  trained logic, banned signal indicator, optimizer output, external feed,
  grid, martingale, scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026/source.md`,
SHA-256
`CA90E88A038EE778D50361A6BE8BEDBD32D2AB8ED963D388AC8DDDC329BC38D5`.
Its durable approval is
`decisions/2026-08-26_xauxag_monthly_lad_reversion_source_approval.md`, commit
`c0e49c012`; the bounded packet is commit `3af469c19`.

No source return, alpha, probability, trade density, risk, cost, hedge ratio,
neutrality, continuous-CFD equivalence, or portfolio correlation transfers.
The paired LAD slope, contrarian direction, CFD mapping, fixed-dollar risk,
stops, spread caps, and lifecycle are falsifiable implementation hypotheses.

## Locked Statistical Contract

For thirteen synchronized consecutive completed broker-month-end pairs,
oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), x[i] = i, i=0..12

candidate b[i,j] = (s[j] - s[i]) / (j - i), 0 <= i < j <= 12
require exactly 78 candidates

for every b:
  residual[i] = s[i] - b*x[i]
  a = ascending(residual)[6]
  loss(b) = sum(i=0..12) abs(s[i] - a - b*x[i])

minimum = min(loss[0..77])
minimizers = every b with abs(loss(b) - minimum) <= 1e-12
lad_slope = ordinary_median(ascending(minimizers))

lad_slope > 0 => SELL XAU / BUY XAG
lad_slope < 0 => BUY XAU / SELL XAG
lad_slope = 0 or invalid => FLAT
```

Require the latest exactly timestamp-matched close pair in each required
month, strict chronological order, positive finite closes, finite ratios,
slopes, residuals, intercepts, and objectives, exact candidate count 78, and
at least one finite minimizer. The `1e-12` guard is a fixed floating-point tie
convention, not a performance parameter. Raw endpoint displacement and the
Theil-Sen median are diagnostic/reference values only and never gate the
signal.

Consume the current `yyyymm` attempt before every fallible gate. Open one
opposite-side package under aggregate `RISK_FIXED=1000`, equal target absolute
USD notionals, maximum 20% realized mismatch, frozen per-leg
`3.5*ATR(20,D1)` stops, and no targets. Close at the first later broker month;
forty days is stale repair only. Both news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,659 registry rows, 1,313 cards, and 45
current Wiki nodes and returned no exact or fuzzy match. Evidence:
`artifacts/qm5_xauxag_mlad_rv_preallocation_dedup_20260826.json`, SHA-256
`D425B6D0E7E4CFA8F99BFD240D7AC6BF2A5352387AA0E0FE62D959B3D2425D0B`.

Manual review distinguishes the card from the closest implementations:

- `QM5_41157_xauxag-mtheilsen-rv` takes the global median of the 78 temporal
  slopes and never profiles an intercept or minimizes absolute loss.
- On valid log-ratio levels
  `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002`, while Theil-Sen is `+0.00303030303030303`; with the locked fade
  direction, they open opposite packages.
- `QM5_41159_wti-lad-tr` applies LAD to outright WTI, follows its sign, and
  owns one energy leg. This card applies LAD to a synchronized paired-metal
  relative path, fades its sign, and owns an atomic two-leg package.
- `QM5_13205_xau-xag-qc` fits three 504-pair cross-sectional conditional
  regressions and trades envelope tails; this card fits one thirteen-point
  time slope and has no conditional beta or envelope.
- fixed z-score, OLS, CADF, MAD, quantile-tail, sign, path, and flow baskets
  use other state objects or estimators.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41160`;
- slug: `xauxag-mlad-rv`;
- strategy ID:
  `SCHWEIKERT-KOENKER-BASSETT-CME-XAUXAG-MLAD-RV-2026_S01`;
- intended slot 0: `XAUUSD.DWX`, magic `411600000`;
- intended slot 1: `XAGUSD.DWX`, magic `411600001`;
- expected cadence: approximately ten to twelve packages per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection;
- fail on current-month leakage, missing/duplicate month, nonlatest pair,
  wrong ratio orientation, candidate omission/duplication, wrong residual
  median, loss, minimizer, side, attempt, basket, risk mode, hard stop, exit,
  or determinism; and
- no post-result change to sample, estimator, direction, carrier, risk, stop,
  hold, equality guard, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the logical basket preset with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
