# G0 Decision — QM5_41239 WTI Same-Calendar Soft-L1 Location

Date: 2026-08-31

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-31_wti_same_calendar_soft_l1_5_source_approval.md` at
commit `4d4c7ad1e` and the complete candidate packet committed at
`c1ec6d725`.

Approved card:
`strategy-seeds/cards/approved/QM5_41239_wti-samecal-softl1-5_card.md`.

## Identity

- EA ID: `QM5_41239`, atomically reserved at commit `967f71652`
- slug: `wti-samecal-softl1-5`
- strategy ID: `KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026_S01`
- source ID: `KELOHARJU-SCIPY-WTI-SAMECAL-SOFTL1-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412390000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  exact prior-five-year matching-calendar-month WTI returns, initialize at
  their odd median, freeze `1.4826*MAD`, execute 32 soft-L1 derivative-weight
  updates, follow the final location sign, and renew next month

## Gate Findings

- R1 `PASS_WITH_SOFT_L1_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. A previously approved complete official
  SciPy page fixes the soft-L1 loss and scale convention. The derivative-
  weight trading conjunction remains untested.
- R2 `PASS`: month clock, uniform D1-label normalization, exact `Y-5..Y-1`
  endpoints, five-return requirement, median, MAD, frozen scale, square-root
  weight, 32 updates, epsilon, side, attempt, risk, stop, spread, and
  lifecycle are mechanical and locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered WTI D1 history and native MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding
  Q02 items.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, absolute
  deviations, squares, square roots, finite arithmetic, and V5 execution
  plumbing only; no trained signal, prohibited runtime feed, grid,
  martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_softl1_5_preallocation_dedup_20260831.json`,
SHA-256
`0ECF970B9E8EB577F9EE375CF8D8E8881BA1DE6141C6E7B8F9667C45C01FD006`,
found no exact identity across 4,738 registry identities, 1,376 cards, and 45
Strategy Wiki nodes. Expected same-calendar and robust-location fuzzy matches
were manually resolved.

- On `[-0.120,-0.075,-0.020,+0.115,+0.120]`, the frozen-scale soft-L1 path
  finishes near `+0.001324252685` and buys.
- The otherwise matched Cauchy path finishes near `-0.004100768370`, the
  arctangent path near `-0.004348219120`, and the median is `-0.020`; all sell.
- On `[-0.120,-0.115,-0.110,+0.155,+0.200]`, soft-L1 sells near
  `-0.100961055448` while the raw mean buys at `+0.002`.
- Soft-L1's `1/sqrt(1+u^2)` tail differs mechanically and directionally from
  Cauchy, arctangent, Huber, bisquare, Hampel, and raw-mean neighbors.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_SOFT_L1_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412390000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- odd median index two, raw MAD index two, frozen `1.4826*MAD`, median start,
  and exactly 32 updates over original chronological returns;
- exact `u=(r-mu)/scale`, `radicand=1+u*u`, and
  `w=1/sqrt(radicand)` with finite arithmetic and no early convergence,
  alternate start, refit, fallback, or optimizer;
- final location above `+1e-12` mapped to buy, below `-1e-12` mapped to sell,
  and the inclusive band consumed flat;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in one D1
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  malformed-position repair, next-month renewal, and a 40-day survivor guard;
  and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No raw mean, plain median, Cauchy, arctangent, Huber, Hampel, bisquare, trim,
Winsorization, capping, order-statistic replacement, selected return deletion,
magnitude sizing, current-month price, fixed-month direction, recent trend,
curve, storage, inventory, event, volume, optimizer output, trained signal,
external runtime input, retry, scale-in, grid, martingale, pyramid, or
after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only while the fresh
whole-host CPU window remains strictly below the 97% ceiling. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong return orientation, median, MAD, scale, weight, update count, epsilon,
current-month leakage, wrong side, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history. Q09
alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
