# G0 Decision — QM5_41232 WTI Same-Calendar Five-Sample MAD Cap

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_madcap5_source_approval.md` and the
complete candidate packet committed at
`d3636e867bc9ca768377dbcecae18b03a88c49be`.

Approved card:
`strategy-seeds/cards/approved/QM5_41232_wti-samecal-madcap5_card.md`.

## Identity

- EA ID: `QM5_41232`, pending atomic deterministic registry verification
- slug: `wti-samecal-madcap5`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-MADCAP5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412320000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  the exact prior five matching-calendar-month WTI returns, compute their odd
  median and raw MAD, freeze inclusive bounds at three raw MADs around the
  median, clip all five original returns, follow their equal-weight capped
  mean sign, and renew next month

## Gate Findings

- R1 `PASS_WITH_ROBUST_LOCATION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. A governed complete method packet fixes the
  MAD-cap arithmetic. The five-sample trading conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, median/MAD indexes, raw scale, cap multiplier, inclusive clipping,
  five-term divisor, epsilon, side, attempt, risk, stop, spread, and lifecycle
  are mechanical and locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered XTI D1 history and native MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding Q02
  items.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, absolute deviations, clipping, comparisons, and V5 execution
  plumbing only; no trained signal, prohibited runtime feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_madcap5_preallocation_dedup_20260830.json`,
SHA-256
`8CCFC5CC92A0CAAE750997FC3DE0E1F2C103085666F5CB8115F8069155163F50`,
found no exact identity across 4,731 registry identities, 1,369 cards, and 45
Strategy Wiki nodes. Its one fuzzy result is the expected raw-mean family
neighbor `QM5_20099_wti-samecal`.

- On sorted `[-0.20,-0.05,+0.01,+0.03,+0.19]`, this card buys from capped
  location `+0.002`; raw mean, middle-three trim, endpoint Winsor, midhinge,
  shortest-three, inclusive-pair pseudomedian, and fixed bisquare siblings
  sell, while the trimean is flat.
- On sorted `[-0.15,-0.03,0,+0.03,+0.04]`, this card sells from `-0.01`;
  median, trim, Winsor, trimean, midhinge, and pseudomedian siblings are flat,
  while the shortest-three and bisquare siblings buy. Sign reflection reverses
  both mappings.
- The existing same-calendar mean, median, trim, fixed endpoint Winsor,
  pseudomedian, chronological-block, shortest-interval, trimean, midhinge, and
  bisquare EAs use different functionals. None derives adaptive symmetric
  bounds from raw MAD and then retains all five clipped returns equally.
- `QM5_20282_wti-madcap-mom` consumes twelve adjacent recent months. This
  candidate consumes one named calendar month across five exact years; it is
  a seasonal information object rather than a contiguous-horizon port.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_RAW_MAD_CAPPED_EQUAL_WEIGHT_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic registry
and magic verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412320000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- odd median index `2`, raw-MAD index `2`, no scale normalizer, frozen bounds
  `median +/- 3*MAD`, inclusive clipping of every original return, and exact
  five-term equal-weight divisor;
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

No raw mean, ordinary median, fixed trim, endpoint order-statistic
Winsorization, trimean, midhinge, pairwise pseudomedian, shortest interval,
Huber location, bisquare location, fitted or mutable cap, scale normalizer,
observation deletion, data-dependent divisor, signed-rank or confidence score,
recency weight, regime gate, current-month price, fixed-month direction,
recent trend, curve, storage, inventory, event, volume, optimizer output,
trained signal, external runtime input, retry, scale-in, grid, martingale,
pyramid, or after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only if the exact-path
tester count and whole-host CPU are below the governed ceilings. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong return orientation, median/MAD defect, normalized or mutable scale,
wrong bounds, exclusive clipping, dropped observation, wrong divisor,
current-month leakage, wrong side, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history. Q09
alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
