# G0 Decision — QM5_41227 WTI Same-Calendar Rolling Two-Year Block Median

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_block_median_source_approval.md` at
current commit `f0d70fd60`.

Approved card:
`strategy-seeds/cards/approved/QM5_41227_wti-samecal-blockmed_card.md`.

## Identity

- EA ID: `QM5_41227`, allocated atomically by the deterministic registry
- slug: `wti-samecal-blockmed`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-BLOCKMED-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412270000`
- mechanic: each genuine normalized broker-month transition, reconstruct the
  exact prior five matching-calendar-month WTI returns, form four overlapping
  adjacent two-year means, take their even median, follow its sign, and renew
  next month

## Gate Findings

- R1 `PASS_WITH_BLOCK_AGGREGATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. The rolling-block statistic and narrow CFD
  carrier are disclosed untested translations.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, four rolling pairs, divisors, sort target, even-median indexes,
  epsilon, side, attempt, risk, stop, spread, and lifecycle are mechanical and
  locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered 2017-2025 XTI D1 history and native MT5 state provide every
  runtime field. Warm-up, label, roll, financing, gap, and CFD-basis risks
  remain binding Q02 items.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, comparisons, and V5 execution plumbing only; no trained signal,
  prohibited runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_blockmed_preallocation_dedup_20260830.json`,
SHA-256
`25B7F707486998A95E9909EABA1D88DF42587F8439541E43080A1573EBE3C871`,
found no exact identity across 4,726 registry identities, 1,364 cards, and 45
Strategy Wiki nodes. Its one fuzzy result is the expected raw-mean family
neighbor `QM5_20099_wti-samecal`.

- On `[-0.10,-0.10,+0.001,+0.10,+0.001]`, this card buys from a
  `+0.0005` rolling-mean median while 20099 sells from a `-0.0198` raw mean.
- On `[-0.10,-0.10,+0.001,+0.001,+0.001]`, this card sells from a
  `-0.02425` rolling-mean median while `QM5_41055_wti-medcal` buys from a
  `+0.001` individual-return median.
- `QM5_20287_wti-blockmed-mom` uses twelve consecutive recent months and four
  non-overlapping three-month blocks; this card uses one named month across
  five years and four overlapping two-year means.
- Trimmed, winsorized, pseudomedian, Huber, signed-rank, t-score, sign-score,
  exponential-weight, and regime-shift siblings use different functionals or
  participation gates.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FOUR_ROLLING_TWO_YEAR_MEAN_EVEN_MEDIAN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412270000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- four adjacent rolling pair means `(r0+r1)/2` through `(r3+r4)/2`, sorting
  only those means, and even median `(s1+s2)/2`;
- location above `+1e-12` mapped to buy, below `-1e-12` mapped to sell, and
  the inclusive tie band consumed flat;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in one D1
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  malformed-position repair, next-month renewal, and a 40-day survivor guard;
  and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No full-sample mean or individual-return median fallback, trimming,
winsorization, pseudomedian, iterative robust location, sign vote, recency
weight, regime gate, current-month price, fixed-month direction, recent trend,
curve, storage, inventory, event, volume, optimizer output, trained signal,
external runtime input, retry, scale-in, grid, martingale, pyramid, or
after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only if the exact-path
tester count and whole-host CPU are below the governed ceilings. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong rolling pairs/divisors/median, current-month leakage, wrong side,
repeated entry, missing stop, wrong lifecycle, nondeterminism, invalid risk
mode, or insufficient history. Q09 alone may establish realized portfolio
correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
