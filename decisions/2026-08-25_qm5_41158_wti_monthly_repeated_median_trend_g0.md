# QM5_41158 WTI Monthly Repeated-Median Trend — G0 Decision

Date: 2026-08-25

Authority: current explicit OWNER commodity/energy portfolio mission delivered
to Codex on branch `agents/board-advisor`.

## Decision

Set `g0_status: APPROVED` for one bounded Strategy Card and non-live V5 build:
`QM5_41158_wti-repmedian-tr`. At the start of each broker month, the candidate
selects thirteen consecutive completed WTI month-end closes, calculates the
exact median slope around each of thirteen endpoint pivots, takes the median
of those pivot medians, and follows its strict sign for one broker month.

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
  official Oxford Academic record for Siegel (1982), *Biometrika* 69(1),
  242-244, DOI `10.1093/biomet/69.1.242`. The exact nested estimator-trading
  conjunction is an explicitly untested QM translation.
- R2: `PASS`. Symbol, clock, thirteen consecutive month keys, latest-close
  selection, log orientation, pivot membership, forward slope orientation,
  counts, inner median indexes 5/6, outer median index 6, direction, attempt,
  fixed risk, stop, spread, and exit are fully mechanical.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 state supply all runtime inputs. Q02 owns actual
  history sufficiency, fills, and costs.
- R4: `PASS`. The signal uses deterministic timestamps, logarithms,
  arithmetic, sorting, and comparisons only. ATR is risk-only. No trained
  logic, banned signal indicator, optimizer output, external feed, grid,
  martingale, scale-in, or pyramid exists.

## Source And Claim Boundary

Approved source packet:
`strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md`, SHA-256
`199D39CB5ECAFC7B57F19BA7932DBEF6558529DD68AE00B66AD4531C7FA48E91`.
Its durable approval is
`decisions/2026-08-25_wti_monthly_repeated_median_trend_source_approval.md`.

No source return, alpha, probability, trade density, risk, cost, continuous-
CFD equivalence, estimator superiority, or portfolio correlation transfers.
The repeated-median arithmetic, WTI CFD mapping, fixed-dollar risk, hard stop,
spread cap, and lifecycle are falsifiable implementation hypotheses.

## Locked Statistical Contract

For thirteen consecutive completed broker-month-end WTI closes, oldest to
newest:

```text
y[i] = ln(C[i]), i=0..12

for i = 0..12:
  for each j != i:
    lo = min(i,j)
    hi = max(i,j)
    b[i,j] = (y[hi] - y[lo]) / (hi - lo)
  require exactly 12 finite slopes for pivot i
  p = ascending(b[i,*])
  pivot_median[i] = (p[5] + p[6]) / 2

require exactly 13 finite pivot medians
m = ascending(pivot_median[0..12])
repeated_median = m[6]

repeated_median > 0 => BUY XTIUSD
repeated_median < 0 => SELL XTIUSD
repeated_median = 0 or invalid => FLAT
```

Require the latest close in each required month, strict chronological order,
positive finite closes, positive month-index denominators, exact slope and
pivot counts, exact median indexes, and finite results. There is no global
slope median, endpoint agreement, magnitude threshold, or alternate signal.

Consume the current `yyyymm` attempt before every fallible gate. Open at most
one position under `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, with a frozen `3.5*ATR(20,D1)` hard stop and no target.
Close at the first later broker month; forty days is stale repair only. Both
news axes and Friday close remain OFF.

## Non-Duplicate Decision

The canonical checker scanned 4,657 registry rows, 1,309 cards, and 45 current
Wiki nodes. It returned one expected fuzzy neighbor,
`QM5_20271_wti-theilsen-tr`, at score `0.6153846153846154`. Evidence:
`artifacts/qm5_wti_repmedian_tr_preallocation_dedup_20260825.json`.

Theil-Sen takes one global median over all 78 unique slopes. This candidate
takes thirteen pivot-specific inner medians and one outer median. A fixed
valid log-price vector makes the existing Theil-Sen statistic positive
(`+0.00155555555555556`) and this repeated median negative (`-0.0045`), so the
rules take opposite positions and are not parameter aliases. OLS, ordinal
rank, endpoint, adjacent-return robust-location, weighted-return, sign-vote,
and path-efficiency families use different objects or aggregation.

Verdict:
`CLEAN_AFTER_THEILSEN_FUZZY_MATCH_AND_SIGN_DIVERGENCE_REVIEW`.

## Allocation And Kill Boundary

- allocated EA ID: `QM5_41158` via the atomic `farmctl reserve-ea-ids` path;
- slug: `wti-repmedian-tr`;
- strategy ID: `MOP-SIEGEL-WTI-REPMEDIAN-TREND-2026_S01`;
- intended slot 0: `XTIUSD.DWX`, magic `411580000`;
- expected cadence: approximately ten to twelve positions per full post-
  warm-up year; Q02 must prove at least five per scored full year;
- retire on zero trades, below-floor density, nonpositive governed economics,
  or later portfolio-correlation rejection;
- fail on current-month leakage, missing/duplicate month, nonlatest or stale
  close, wrong log orientation, pivot membership, slope orientation,
  denominator, count, median, side, attempt, risk mode, hard stop, exit, or
  determinism; and
- no post-result change to sample, estimator, direction, carrier, risk, stop,
  hold, or retry contract is authorized.

## Safety Boundary

This decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 must
use the locked D1 setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. If the governed queue or fresh CPU guard refuses work,
record the stop and do not bypass it.
