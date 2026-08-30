# G0 Decision — QM5_41230 WTI Same-Calendar Five-Sample Midhinge

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_midhinge5_source_approval.md` and the
complete candidate packet committed at `b5879eb6b`.

Approved card:
`strategy-seeds/cards/approved/QM5_41230_wti-samecal-midhinge5_card.md`.

## Identity

- EA ID: `QM5_41230`, pending atomic deterministic registry verification
- slug: `wti-samecal-midhinge5`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-MIDHINGE5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412300000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  the exact prior five matching-calendar-month WTI returns, sort them, average
  only fixed lower hinge `x[1]` and upper hinge `x[3]`, follow that midpoint's
  sign, and renew next month

## Gate Findings

- R1 `PASS_WITH_HINGE_ONLY_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. Official NIST material supplies quartile,
  middle-50%, and robust-location context. The trading conjunction remains
  untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, ascending sort, hinge indexes, median/extreme exclusion, divisor,
  epsilon, side, attempt, risk, stop, spread, and lifecycle are mechanical and
  locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered 2017-2025 XTI D1 history and native MT5 state provide every
  runtime field. Warm-up, label, roll, financing, gap, and CFD-basis risks
  remain binding Q02 items.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, averaging, comparisons, and V5 execution plumbing only; no trained
  signal, prohibited runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_midhinge5_preallocation_dedup_20260830.json`,
SHA-256
`73AE30B9E4B499FC0D09175B2AC3EF8E95025B27C6620A2FB4203EFE32576802`,
found no exact identity across 4,729 registry identities, 1,367 cards, and 45
Strategy Wiki nodes. Its one fuzzy result is the expected raw-mean family
neighbor `QM5_20099_wti-samecal`.

- On sorted `[-6,-4,-3,+5,+5.5]`, this card buys from midhinge `+0.5`;
  full mean, median, middle-three trim, endpoint Winsor, shortest-half, and
  trimean siblings are all negative and sell.
- On sorted `[-6,-5,+2,+3,+12]`, this card sells from midhinge `-1`, while
  full mean `+1.2`, median `+2`, and trimean `+0.5` make their siblings buy.
- `QM5_41055`, `QM5_20099`, `QM5_41199`, `QM5_41201`, `QM5_41202`, and
  `QM5_41204` use an ordinary median, raw mean, equal-weight trim, inclusive
  pair averages, endpoint replacement, or fitted Huber location.
- `QM5_41227` preserves chronological year order, `QM5_41228` selects a
  data-dependent narrowest interval, and `QM5_41229` gives its median half of
  the final weight. This card always reads only sorted indexes `1` and `3`,
  each at one-half.
- `QM5_20283_wti-trimean-mom` uses twelve adjacent recent months and six
  even-sample order statistics, not five observations of the same named
  calendar month across separate years.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FIXED_MIDHINGE_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic registry
and magic verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412300000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- ascending sort of exactly five returns, `Q1=x[1]`, `Q3=x[3]`, and exact
  `(Q1 + Q3) / 2` arithmetic with no numeric use of `x[0]`, `x[2]`, or `x[4]`;
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

No raw mean, ordinary median, equal-weight middle-three trim, endpoint
Winsorization, trimean, pairwise pseudomedian, iterative robust location,
data-dependent shortest interval, signed-rank or confidence score, recency
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
wrong sort/hinges/divisor, accidental median inclusion, current-month leakage,
wrong side, repeated entry, missing stop, wrong lifecycle, nondeterminism,
invalid risk mode, or insufficient history. Q09 alone may establish realized
portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
