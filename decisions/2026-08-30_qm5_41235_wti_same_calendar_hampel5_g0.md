# G0 Decision — QM5_41235 WTI Same-Calendar Five-Sample Hampel

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_hampel5_source_approval.md` at commit
`b95b732c9` and the complete candidate packet committed at `e582e23ff`.

Approved card:
`strategy-seeds/cards/approved/QM5_41235_wti-samecal-hampel5_card.md`.

## Identity

- EA ID: `QM5_41235`, atomically reserved at commit `7fd7424cb`
- slug: `wti-samecal-hampel5`
- strategy ID: `KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026_S01`
- source ID: `KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412350000`
- mechanic: each genuine normalized broker-month transition, reconstruct the
  exact prior five matching-calendar-month WTI returns, freeze a rescaled raw
  MAD, execute exactly 32 Hampel `2/4/8` redescending updates from the median,
  follow the fitted location sign, and renew next month

## Gate Findings

- R1 `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. A canonical robust-statistics reference and
  author-maintained CRAN documentation/source fix the Hampel arithmetic. The
  five-sample trading conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, median/MAD indexes, frozen scale, `2/4/8` boundaries and inclusions,
  piecewise weights, update count, epsilon, side, attempt, risk, stop, spread,
  and lifecycle are mechanical and locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered XTI D1 history and native MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding Q02
  items.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, absolute deviations, fixed piecewise reweighting, comparisons, and
  V5 execution plumbing only; no trained signal, prohibited runtime feed,
  grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_hampel5_preallocation_dedup_20260830.json`,
SHA-256
`21A13A996AC51D7DF59C019A5333463D71A6F9FE68CFE7CADB8AD517088E6AD9`,
found no exact identity across 4,734 registry identities, 1,372 cards, and 45
Strategy Wiki nodes. Expected same-calendar fuzzy matches were manually
resolved.

- On sorted `[-0.050,-0.005,+0.002,+0.005,+0.080]`, this card sells from
  final Hampel location approximately `-0.00580512`.
- Raw mean, median, five-sample bisquare, Gastwirth, Harrell-Davis, trim,
  Winsor, and trimean siblings buy the same fixture; the midhinge is flat.
- Sign reflection produces the opposite mapping.
- The ten-year Huber neighbor never fully rejects a finite tail. The
  five-year bisquare neighbor uses a smooth squared compact-support curve,
  not Hampel's fixed unit, plateau-decay, linear-redescending, and zero
  regions at `2/4/8`.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_HAMPEL_248_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412350000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- odd median index `2`, raw-MAD index `2`, frozen scale `1.4826*MAD`, exact
  Hampel constants `a=2`, `b=4`, `c=8`, locked boundary inclusions, positive
  total weight, and exactly 32 updates over the original five returns;
- final location above `+1e-12` mapped to buy, below `-1e-12` mapped to sell,
  and the inclusive tie band consumed flat;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in one D1
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  malformed-position repair, next-month renewal, and a 40-day survivor guard;
  and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No raw mean, median, trim, Winsorization, trimean, midhinge, pseudomedian,
shortest interval, Huber, bisquare, MAD cap, Gastwirth, Harrell-Davis, fitted
or mutable scale, alternate Hampel constants, early stop, alternate start,
local-minimum search, signed-rank or confidence score, current-month price,
fixed-month direction, recent trend, curve, storage, inventory, event, volume,
optimizer output, trained signal, external runtime input, retry, scale-in,
grid, martingale, pyramid, or after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only if the exact-path
tester count and whole-host CPU are below the governed ceilings. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong return orientation, median/MAD/scale defect, mutable scale, wrong
`2/4/8` boundary, wrong weight, wrong update count, zero-weight fallback,
current-month leakage, wrong side, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history. Q09
alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
