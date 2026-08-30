# G0 Decision - QM5_41234 WTI Same-Calendar Harrell-Davis Median

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_harrell_davis5_source_approval.md`
at commit `3c278ece5` and the governed extraction at commit `061a204d3`.

Approved card:
`strategy-seeds/cards/approved/QM5_41234_wti-samecal-hd5_card.md`.

## Identity

- EA ID: `QM5_41234`, to be reserved atomically by the deterministic registry
  before build
- slug: `wti-samecal-hd5`
- strategy ID: `KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026_S01`
- source ID: `KELOHARJU-HARRELL-DAVIS-WTI-SAMECAL-HD5-2026`
- host/slot 0: exact `XTIUSD.DWX`, D1, intended magic `412340000`
- mechanic: each genuine broker-month transition, compute the fixed
  five-observation Harrell-Davis median estimate of exact-prior-year WTI
  returns for that same calendar month, follow its strict sign, and renew
  next month

## Gate Findings

- R1 `PASS_WITH_QUANTILE_ESTIMATOR_AND_SINGLE_CFD_TRANSLATION_RISK`:
  two named-author, DOI-bearing, peer-reviewed trading lineages are completely
  reviewed. A peer-reviewed *Biometrika* citation and originating author's
  maintained implementation fix the estimator. The exact five-sample WTI CFD
  conjunction is disclosed as untested.
- R2 `PASS`: month clock, uniform label normalization, exact endpoints,
  exact five-year sample, ascending order, beta(3,3) weights, rational and
  decimal invariant, epsilon band, side, attempt, fixed risk, spread, stop,
  and lifecycle are mechanical and locked.
- R3 `PASS_WITH_FIVE_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native WTI D1 history and MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, fixed weighted
  sums, comparisons, and V5 execution plumbing only; no trained signal,
  prohibited runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_hd5_preallocation_dedup_20260830.json`, SHA-256
`08046E588E84E3AE010A4C3CA5F32F68CA1097D961731C5AD5401366D81E35A9`,
found no exact identity across 4,733 registry identities, 1,371 cards, and 45
Strategy Wiki nodes. Thirteen fuzzy same-calendar family matches were
manually resolved.

- `[-0.30,-0.30,+0.05,+0.25,+0.25]` makes this card buy at
  `+0.002384`; the raw and Winsor means sell, the trimmed mean is flat, and
  the midhinge sells.
- `[-0.30,-0.20,-0.05,+0.30,+0.30]` makes this card buy at
  `+0.007696`; the ordinary median and Gastwirth location sell and the
  trimean is flat.
- `[-0.30,-0.30,+0.05,+0.20,+0.20]` makes this card sell at
  `-0.013488`; the ordinary median and Gastwirth location buy.
- Existing mean, median, trimmed, Winsorized, pseudomedian, shortest-half,
  block-median, Huber, trimean, midhinge, bisquare, MAD-cap, t-score,
  sign-score, exponential-weight, and Gastwirth cards use different sample
  maps, gates, iterations, or weights.

Verdict:
`CLEAN_AND_SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_HARRELL_DAVIS_MEDIAN_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412340000`;
- native or one uniform `+1` energy-label normalization, with normalized
  current host D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, confirming
  following bars, positive finite closes, and no current-month data;
- all five returns mandatory and sorted ascending;
- fixed Harrell-Davis median weights
  `[181,811,1141,811,181]/3125`, independently checked against decimal
  weights `[0.05792,0.25952,0.36512,0.25952,0.05792]` within `1e-12`;
- location above `+1e-12` mapped to buy WTI, below `-1e-12` mapped to sell,
  and the inclusive tie band consumed flat;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` in one D1 backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point entry
  spread ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  next-month renewal, and a 40-day stale guard; and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No current-month OHLC, missing-year substitution, shorter sample, alternate
quantile, runtime beta function, fitted weight, raw mean, median, trim,
Winsor, pseudomedian, shortest interval, block median, Huber, trimean,
midhinge, bisquare, MAD-cap, Gastwirth, t-score, sign-score, curve, storage,
inventory, event, volume, optimizer output, trained signal, external runtime
input, retry, scale-in, grid, martingale, pyramid, or after-result rescue is
approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one
`RISK_FIXED` D1 backtest setfile, strict Q01, and one paced target-only Q02
enqueue only if the exact-path tester count and host CPU are below the
governed ceilings. It does not authorize a manual tester dispatch or tester
control.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero positions, fewer than five/year,
nonpositive governed economics, wrong endpoints, missing exact years, wrong
weights or invariant, current-month leakage, wrong side, repeated entry,
missing stop, wrong lifecycle, nondeterminism, invalid risk mode, or
insufficient history. Q09 alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
