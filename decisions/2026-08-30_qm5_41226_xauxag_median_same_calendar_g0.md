# G0 Decision — QM5_41226 XAU/XAG Median Same-Calendar Relative Seasonality

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_xauxag_median_same_calendar_source_approval.md` at
commit `01dd23e25`.

Approved card:
`strategy-seeds/cards/approved/QM5_41226_xauxag-medcal_card.md`.

## Identity

- EA ID: `QM5_41226`, allocated atomically by the deterministic registry
- slug: `xauxag-medcal`
- strategy ID: `KELOHARJU-XAUXAG-MEDCAL-2026_S01`
- source ID: `KELOHARJU-FMR-XAUXAG-SAMECAL-2026`
- host/slot 0: exact `XAUUSD.DWX`, D1, intended magic `412260000`
- companion/slot 1: exact `XAGUSD.DWX`, D1, intended magic `412260001`
- mechanic: each genuine broker-month transition, compute the ordinary sample
  median of five to ten synchronized exact-prior-year XAU-minus-XAG completed
  returns for that same calendar month, follow its sign with opposite metal
  legs, and renew next month

## Gate Findings

- R1 `PASS_WITH_ROBUST_LOCATION_SMALL_SAMPLE_AND_CFD_TRANSLATION_RISK`:
  named-author, DOI-bearing, peer-reviewed same-calendar commodity and
  XAU/XAG carrier lineages are completely reviewed in governed packets. The
  ordinary median and narrow CFD conjunction are disclosed untested QM
  translations.
- R2 `PASS`: month clock, uniform label normalization, synchronized endpoints,
  exact-year bound, sample floor/cap, odd/even median, epsilon band, side,
  attempt, shared risk, spread caps, stops, atomicity, and lifecycle are
  mechanical and locked.
- R3 `PASS_WITH_LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native XAU/XAG D1 histories and MT5 state provide every runtime
  field. Warm-up, label, synchronization, roll, financing, legging, and CFD
  basis remain binding Q02 risks.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, comparisons, and
  V5 execution plumbing only; no trained signal, prohibited runtime feed,
  grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_xauxag_medcal_preallocation_dedup_20260830.json`, SHA-256
`3989F7EBA257EF1FEAD63D8A4ABCE61FDE6AA6F6B61BB8DFEC9067B5011024EB`, found
no exact or above-threshold fuzzy identity across 4,725 registry identities,
1,363 cards, and 45 Strategy Wiki nodes.

- `QM5_20186_xauxag-samecal` uses the arithmetic mean and takes the opposite
  side for `[+0.01,+0.01,+0.01,+0.01,-0.20]`.
- `QM5_41206_xauxag-samecal-huber10` requires ten observations, a positive
  scale, and iterative Huber weighting; this card directly selects the center
  of five to ten sorted returns.
- `QM5_41213_xauxag-samecal-signscore` discards magnitude and can abstain for
  `[+0.001,-0.20,-0.20,+0.20,+0.20]` while this card buys XAU.
- `QM5_41210_xauxag-samecal-tstat` standardizes a mean by sample error and is
  nearly flat on that vector.
- `QM5_41203_xauxag-samecal-srank` retains absolute-rank weights.
- Ratio, residual, channel, recent-momentum, session, correlation-break, and
  path-distribution baskets use different information objects.

Verdict:
`CLEAN_AND_SEMANTICALLY_DISTINCT_XAUXAG_SAMECAL_RELATIVE_SAMPLE_MEDIAN_SIGN_MONTHLY_BASKET`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XAUUSD.DWX` D1 slot 0 and `XAGUSD.DWX` D1 slot 1 under registered
  magics `412260000` and `412260001`;
- native same-day or one uniform `+1` metal-label normalization, with the
  normalized current host D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-1..Y-10`, strict adjacent calendar endpoints, confirming
  following bars, timestamp identity between legs, and no current-month data;
- five to ten finite relative returns, ordinary odd/even median, no
  substitution year, weighting, interpolation, iterative location, or
  fallback estimator;
- median above `+1e-12` mapped to buy XAU/sell XAG, below `-1e-12` mapped to
  sell XAU/buy XAG, and the inclusive tie band consumed flat;
- exactly one aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` logical-basket D1 backtest setfile;
- equal fixed-risk halves, frozen `3.5 * ATR(20,D1)` hard stops, no targets,
  and 1,500/3,000-point XAU/XAG entry spread ceilings;
- both current news axes and legacy news OFF, framework Friday close OFF,
  atomic package repair, next-month renewal, and a 40-day stale guard; and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No current-month OHLC/volume, arithmetic-mean/Huber/t-score/signed-rank/
sign-score fallback, favorable-month selection, recent trend, ratio z-score,
OLS/CADF residual, curve, storage, inventory, event, volume, optimizer output,
trained signal, external runtime input, retry, scale-in, grid, martingale,
pyramid, or after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one logical-basket
`RISK_FIXED` backtest setfile, strict Q01, and one paced target-only Q02
enqueue only if the exact-path tester count and host CPU are below the
governed ceilings. It does not authorize a manual tester dispatch or tester
control.

Expected cadence is approximately ten to twelve completed packages per full
post-warm-up year. Q02 must retire on zero packages, fewer than five/year,
nonpositive governed economics, wrong endpoints, cross-leg desynchronization,
current-month leakage, invalid sample or median, wrong side, repeated entry,
orphan persistence, missing stops, wrong lifecycle, nondeterminism, invalid
risk mode, or insufficient history. Q09 alone may establish realized
portfolio correlation.

This decision excludes component-leg Q02 rows; live/demo/shadow/stress/
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate edits; portfolio admission; decorrelation claims; and
correlation waivers.
