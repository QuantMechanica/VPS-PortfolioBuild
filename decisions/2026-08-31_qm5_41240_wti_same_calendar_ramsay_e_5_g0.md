# G0 Decision — QM5_41240 WTI Same-Calendar Ramsay-E Location

Date: 2026-08-31

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-31_wti_same_calendar_ramsay_e_5_source_approval.md` at
commit `903edb7f5` and the complete candidate packet committed at
`b3866e218`.

Approved card:
`strategy-seeds/cards/approved/QM5_41240_wti-samecal-ramsaye5_card.md`.

## Identity

- EA ID: `QM5_41240`, atomically reserved at commit `ce2f0390e`
- slug: `wti-samecal-ramsaye5`
- strategy ID: `KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026_S01`
- source ID: `KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412400000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  exact prior-five-year matching-calendar-month WTI returns, initialize at
  their odd median, freeze `1.4826*MAD`, execute 32 Ramsay-E exponential-
  weight updates with `a=0.3`, follow the final location sign, and renew next
  month

## Gate Findings

- R1 `PASS_WITH_RAMSAY_E_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. Official statsmodels source fixes the
  Ramsay-E definition and default `a=0.3`. The fitted five-return trading
  conjunction remains untested.
- R2 `PASS`: month clock, uniform D1-label normalization, exact `Y-5..Y-1`
  endpoints, five-return requirement, median, MAD, frozen scale, exponential
  weight, 32 updates, epsilon, side, attempt, risk, stop, spread, and
  lifecycle are mechanical and locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered WTI D1 history and native MT5 state provide every runtime field.
  Warm-up, label, roll, financing, gap, and CFD-basis risks remain binding.
- R4 `PASS`: deterministic timestamps, logarithms, sorting, absolute
  deviations, exponentials, finite arithmetic, and V5 execution plumbing
  only; no trained signal, prohibited runtime feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_ramsaye5_preallocation_dedup_20260831.json`,
SHA-256
`9F3FAEC5AE93C269494C4787DBFD87EF3E6B19D9926C7925DAD302E3CDF2459E`,
found no exact identity across 4,739 registry identities, 1,377 cards, and 45
Strategy Wiki nodes. Expected same-calendar and robust-location fuzzy matches
were manually resolved.

- On `[-0.135,-0.010,-0.005,+0.005,+0.050]`, Ramsay-E finishes near
  `+0.000567268656` and buys, while matched soft-L1, Cauchy, arctangent, raw
  mean, and median all sell.
- On `[-0.130,-0.025,+0.005,+0.020,+0.190]`, Ramsay-E finishes near
  `-0.000066275832` and sells, while soft-L1, arctangent, raw mean, and raw
  median buy.
- Ramsay-E's `exp(-0.3*abs(u))` is neither the rational tail of Cauchy,
  arctangent, or soft-L1 nor the unit/piecewise/compact-support curve of
  Huber, Hampel, or bisquare.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_FROZEN_SCALE_RAMSAY_E_EXPONENTIAL_LOCATION_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412400000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- odd median index two, raw MAD index two, frozen `1.4826*MAD`, median start,
  and exactly 32 updates over original chronological returns;
- exact `u=(r-mu)/scale` and `w=exp(-0.3*abs(u))` with finite arithmetic and
  no early convergence, alternate start, refit, fallback, optimizer, or
  silent zero-weight deletion;
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

No mean, plain median, soft-L1, Cauchy, arctangent, Huber, Hampel, bisquare,
trim, Winsorization, capping, order-statistic replacement, selected return
deletion, magnitude sizing, current-month price, fixed-month direction,
recent trend, curve, storage, inventory, event, volume, optimizer output,
trained signal, external runtime input, retry, scale-in, grid, martingale,
pyramid, or after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only while the fresh
whole-host CPU window remains strictly below the 97% ceiling. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong return orientation, median, MAD, scale, `a`, exponential weight, update
count, epsilon, current-month leakage, wrong side, repeated entry, missing
stop, wrong lifecycle, nondeterminism, invalid risk mode, or insufficient
history. Q09 alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
