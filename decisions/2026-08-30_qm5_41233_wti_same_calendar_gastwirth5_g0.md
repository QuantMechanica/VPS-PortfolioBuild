# G0 Decision - QM5_41233 WTI Same-Calendar Five-Sample Gastwirth Location

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy portfolio mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_gastwirth5_source_approval.md` and the
complete candidate packet committed as `9608e3422`.

Approved card:
`strategy-seeds/cards/approved/QM5_41233_wti-samecal-gast5_card.md`, SHA-256
`3D5EC40AC101DD1A4C7354D056558F3048E16158E00160B3FEFACE1B32577098`.

## Identity

- EA ID: `QM5_41233`, atomically reserved by `farmctl reserve-ea-ids`
- slug: `wti-samecal-gast5`
- strategy ID: `KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026_S01`
- source ID: `KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412330000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  the exact prior five matching-calendar-month WTI returns, compute GNU GSL
  linear quantiles at one-third, one-half, and two-thirds, combine them with
  Gastwirth weights `0.3/0.4/0.3`, follow the strict location sign, and renew
  next month

The registry identity is exact: `41233,wti-samecal-gast5,
KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026_S01`.

## Source And Gate Findings

- R1 `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. Gastwirth (1966) supplies named robust-
  procedure lineage and official GNU Scientific Library documentation fixes
  the numerical estimator. The five-sample trading conjunction is untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, ascending sort, GSL quantile interpolation, `0.3/0.4/0.3` weights,
  simplified invariant, epsilon, side, attempt, risk, stop, spread, and
  lifecycle are mechanical and locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered XTI D1 history and native MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding Q02
  items.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, fixed linear
  interpolation, weighted sums, comparisons, and V5 execution plumbing only;
  no trained signal, prohibited runtime feed, grid, martingale, scale-in, or
  pyramid.

The source packet is
`strategy-seeds/sources/KELOHARJU-GASTWIRTH-GSL-WTI-SAMECAL-GAST5-2026/source.md`,
SHA-256
`D5A6186CDD5944B62B7B364F6A6C326888ED5F8BC3B3EE3F9007C0B408B28692`.
The source approval was committed first as `04322a80a`; no source result,
WTI-only alpha, cost, CFD equivalence, or portfolio correlation transfers.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_gast5_preallocation_dedup_20260830.json`, SHA-256
`C9ADEE43102AC02EDE2BFCD5891EA639A115D59658DF730B9F1A899F0B120F17`,
found no exact identity across 4,732 registry identities, 1,370 cards, and 45
Strategy Wiki nodes. Its one fuzzy result is the expected raw-mean family
neighbor `QM5_20099_wti-samecal`.

- On sorted `[-0.30,-0.28,+0.02,+0.24,+0.26]`, this card buys from
  Gastwirth location `+0.004`; raw mean, middle-three trim, and inactive
  MAD-cap siblings sell, while the trimean is flat.
- On sorted `[-0.20,-0.15,+0.04,+0.05,+0.06]`, this card buys from `+0.004`;
  equal-weight trim, trimean, midhinge, and endpoint Winsor siblings sell.
- On sorted `[-0.25,-0.20,+0.01,+0.04,+0.05]`, this card sells from
  `-0.026`, while the ordinary median buys. Sign reflection reverses every
  strict mapping.
- Existing same-calendar mean, median, trim, endpoint Winsor, pseudomedian,
  block median, shortest interval, trimean, midhinge, Huber, bisquare, and
  MAD-cap EAs use different functionals. None uses GSL one-third/half/two-
  third interpolation and the resulting fixed `0.2/0.6/0.2` central weights.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_GSL_GASTWIRTH_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412330000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- ascending order and exact GSL interpolation at `1/3`, `1/2`, and `2/3`;
- Gastwirth aggregation `0.3*Q(1/3)+0.4*Q(1/2)+0.3*Q(2/3)`, independently
  checked against `0.2*s[1]+0.6*s[2]+0.2*s[3]` within `1e-12`;
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

No alternate quantile type, raw mean, ordinary median, fixed trim, endpoint
Winsorization, trimean, midhinge, pairwise pseudomedian, shortest interval,
block median, Huber location, bisquare location, MAD-capped mean, fitted or
mutable weight, scale normalizer, observation substitution, signed-rank or
confidence score, recency weight, regime gate, current-month price,
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
wrong return orientation, quantile defect, wrong weights, invariant failure,
current-month leakage, wrong side, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history. Q09
alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
