---
card_schema_version: 2
type: strategy
strategy_id: KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026_S01
variant_id: KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026_S01
source_id: KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026
ea_id: QM5_41206
slug: xauxag-samecal-huber10
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41206_xauxag-samecal-huber10_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41206_xauxag_same_calendar_huber10_g0.md
source_approval: decisions/2026-08-29_xauxag_same_calendar_huber10_source_approval.md
source_author: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; Peter J. Huber"
source_authors: "Matti Keloharju; Juhani T. Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis; Peter J. Huber"
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Return Seasonalities, Journal of Finance 71(4), 1557-1590, DOI 10.1111/jofi.12398; Fuertes, Miffre, and Rallis (2010), Tactical Allocation in Commodity Futures Markets, Journal of Banking & Finance 34(10), 2530-2548, DOI 10.1016/j.jbankfin.2010.04.009; Huber (1964), Robust Estimation of a Location Parameter, Annals of Mathematical Statistics 35(1), 73-101, DOI 10.1214/aoms/1177703732."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "DOI 10.1111/jofi.12398; complete-read packet strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: same_calendar_month_commodity_return_information_and_history_floor
  - type: peer_reviewed_trading_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "DOI 10.1016/j.jbankfin.2010.04.009; complete-read packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: xau_xag_cross_sectional_commodity_carrier_and_monthly_hold
  - type: peer_reviewed_statistics_paper
    citation: "Huber, P. J. (1964). Robust Estimation of a Location Parameter. The Annals of Mathematical Statistics 35(1), 73-101."
    location: "DOI 10.1214/aoms/1177703732; exact governed arithmetic bound through strategy-seeds/sources/MOP-WTI-HUBER-2026/source.md with no WTI carrier claim transferred"
    quality_tier: A
    role: bounded_influence_location_lineage_only
  - type: governed_composite_source
    citation: "QuantMechanica bounded paired XAU/XAG exact-ten-year same-calendar fixed-step Huber extraction."
    location: "strategy-seeds/sources/KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026/source.md"
    quality_tier: internal_governed
    role: exact_synchronized_calendar_endpoints_relative_returns_scale_iterations_risk_atomicity_and_lifecycle
strategy_mechanic: synchronized-exact-prior-ten-year-same-calendar-month-xau-minus-xag-relative-log-returns-even-median-mad-fixed-scale-thirty-two-update-huber-location-sign-monthly-two-leg-basket-renewal
sources:
  - "[[sources/KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/robust-return-location]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/huber-m-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, calendar-seasonality, same-calendar-month, robust-location, bounded-influence, relative-value, market-neutral-style, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 412060000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year; invalid synchronized history, nonpositive MAD/scale, invalid iteration state, or an inclusive sign-band result consumes the month flat."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_ESTIMATOR_PAIR_AND_CFD_TRANSLATION_RISK
r1_reasoning: "Complete peer-reviewed trading lineages support same-calendar commodity information and the governed XAU/XAG carrier; peer-reviewed statistical lineage plus a governed packet fixes bounded-location arithmetic. The exact paired CFD conjunction remains untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoint identity, exact Y-1..Y-10 sample, relative-return orientation, even median/MAD, frozen scale, tuning, 32 updates, sign band, pair side, consumed attempt, aggregate fixed risk, atomicity, stops, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_qualification: LONG_WARMUP_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronized warm-up, labels, rolls, financing, legging, and futures/CFD basis remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, absolute deviations, fixed arithmetic, ATR risk controls, and execution state; no trained signal, banned signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: exact prior 10 same-calendar years and all 10 synchronized pairs required; even median and even raw MAD; scale 1.4826*MAD; tuning 1.5; frozen scale; exactly 32 reweight updates; sign epsilon 1e-12; 3000 D1 history bars per leg; ATR(20)*3.5 per-leg stops; 40-day stale exit; XAU/XAG spread ceilings 1500/3000 points; one shared RISK_FIXED budget."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a paired XAU/XAG same-calendar Huber relative-value sleeve outside the directional XAU/SP500/NDX/XNG book. Verify synchronized exact-year completed endpoints, relative-return orientation, even median/MAD, frozen scale, exact weights and 32 updates, sign side, consumed month, aggregate fixed risk, atomic opposite legs, frozen stops, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, exact_prior_year_same_calendar_months, synchronized_cross_leg_endpoints, completed_month_endpoints, no_current_month_price, paired_relative_return_orientation, exact_ten_pair_sample, even_median, even_mad, frozen_huber_scale, huber_weight_equation, exactly_thirty_two_updates, sign_epsilon, paired_long_short_side, monthly_attempt_state, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, friday_close_disabled, next_month_exit, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29 and decisions/2026-08-29_qm5_41206_xauxag_same_calendar_huber10_g0.md: R1 passes with complete peer-reviewed same-calendar and XAU/XAG trading lineages plus bounded-location statistical lineage; R2 locks calendar, synchronization, exact sample, relative returns, median/MAD, scale, weights, updates, pair side, attempt, risk, atomicity, stops, and lifecycle; R3 uses registered native XAU/XAG D1 with warm-up/synchronization/CFD risk; R4 is deterministic native arithmetic only. Canonical dedup found the expected mean, signed-rank, and single-energy Huber neighbors; manual review plus a fixed disagreement fixture resolves them."
---

# QM5_41206 XAU/XAG Ten-Year Same-Calendar Huber Relative Seasonality

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. Those relative pressures
may recur in the same calendar month. A raw historical mean is vulnerable to
one shock year; this card estimates the central direction of the exact ten
prior synchronized XAU-minus-XAG returns with a fixed-scale bounded-influence
Huber location and follows that sign for one month.

Opposite metal legs target relative seasonal exposure while reducing common
outright-metal direction. They do not prove dollar, beta, volatility, factor,
market, or portfolio neutrality. Q02 owns activity and economics; unchanged
Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The approved bounded packet is
`strategy-seeds/sources/KELOHARJU-HUBER-XAUXAG-SAMECAL10-2026/source.md`,
SHA-256
`1979F66E61B1CA514BD2E89EF75912C4550ABEECEC0C5A98D9D7C476997A22A9`,
authorized by
`decisions/2026-08-29_xauxag_same_calendar_huber10_source_approval.md` at
commit `342e07a71` before extraction.

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar commodity
information and a history floor. Fuertes, Miffre, and Rallis supply the
governed XAU/XAG cross-sectional carrier and monthly hold. Huber supplies the
bounded-influence location family; the governed Huber packet fixes the exact
iteration arithmetic. No source tests this exact paired CFD basket.

No source return, alpha, probability, significance, density, profit factor,
drawdown, cost, hedge ratio, CFD equivalence, decorrelation, or portfolio
statistic transfers.

## Source-Defined Rules

- Same-calendar commodity returns are the source information object and
  positions renew monthly.
- XAU and XAG form a governed opposite-direction cross-sectional commodity
  carrier with a one-month hold translation.
- Huber supplies bounded-influence location lineage. The exact sample, scale,
  tuning, weight equation, update count, CFD endpoints, and execution rules
  are transparent locked QM choices.

## QM Interpretations

- Exact years `Y-1..Y-10`, all-ten requirement, uniform D1-label convention,
  and strict synchronized completed-month endpoints are pre-result CFD
  translation choices.
- The even median/MAD, `1.4826` normalizer, `1.5` tuning multiplier, frozen
  scale, 32 updates, and `1e-12` sign band are the governed estimator
  contract; they are not fitted to this candidate's results.
- Equal fixed-risk halves, ATR stops, spread caps, attempt ledger, atomicity,
  and survivor repair are execution plumbing rather than sourced alpha.
- The two CFDs are not futures and the package is not presumed hedged or
  decorrelated.

## Non-Duplicate Decision

The fail-closed checker scanned 4,705 registry identities, 1,351 card files,
and 45 Strategy Wiki nodes. It found no exact identity and surfaced four
expected fuzzy neighbors. Receipt:
`artifacts/qm5_xauxag_samecal_huber10_preallocation_dedup_20260829.json`,
SHA-256
`5EF82AF457CF175BE027E302B1824621876059C6BFB11FC0EC4FA2646D078EC6`.

- `QM5_20186` takes the arithmetic mean of paired same-calendar returns and
  has no scale or iterative influence weights.
- `QM5_41203` takes a centered signed absolute-rank score, discards metric
  distance, and has no location iteration.
- `QM5_41204` and `QM5_41205` apply the same statistic to standalone WTI and
  XNG. This card observes synchronized cross-metal differences and owns an
  atomic two-leg package.
- Existing ratio/residual/recent-window/channel/session baskets observe
  different information objects.

For relative-return fixture
`[.0188,-.0148,.0122,.0021,-.0084,-.0013,.0012,.0006,.0058,-.0160]`,
the Huber location is approximately `-0.0003122567` and sells XAU / buys XAG;
the raw mean is positive and the centered strict signed-rank score is `+3`,
so both neighbors buy XAU / sell XAG.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_EXACT_TEN_YEAR_SAMECAL_FIXED_SCALE_HUBER_RELATIVE_LOCATION_MONTHLY_BASKET`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_41206_XAU_XAG_SAMECAL_HUBER10_D1`.
- Host/slot 0: exact `XAUUSD.DWX`, D1, intended magic `412060000`.
- Companion/slot 1: exact `XAGUSD.DWX`, D1, intended magic `412060001`.
- Decision: first executable host D1 tick after a genuine broker-month
  boundary.
- Formation: exact target month in every exact year `Y-1..Y-10`; all ten
  synchronized paired observations required.
- Hold: next broker-month boundary; 40 elapsed days is stale repair.
- Expected pre-result cadence: ten to twelve packages/year after warm-up;
  Q02 retires below five in any full post-warm-up year.

## Formula

For target month `M` in historical year `H`:

```text
r_xau(H,M) = ln(xau_month_end_close / xau_prior_month_end_close)
r_xag(H,M) = ln(xag_month_end_close / xag_prior_month_end_close)
d(H,M)     = r_xau(H,M) - r_xag(H,M)
```

For the exact ten `d` observations:

```text
s       = sort_ascending(d)
median  = (s[4] + s[5]) / 2
dev[i]  = abs(d[i] - median)
a       = sort_ascending(dev)
MAD     = (a[4] + a[5]) / 2
scale   = 1.4826 * MAD
delta   = 1.5 * scale

mu[0] = median
for j = 0..31:
  residual = abs(d[i] - mu[j])
  weight   = 1 if residual <= delta else delta / residual
  mu[j+1]  = sum(weight*d) / sum(weight)

mu[32] > +1e-12 => BUY XAU, SELL XAG
mu[32] < -1e-12 => SELL XAU, BUY XAG
otherwise       => FLAT
```

The scale freezes before iteration and all 32 updates run. Every endpoint,
return, deviation, scale, weight, denominator, and iterate must be finite;
MAD, scale, delta, weights, and denominator must be strictly positive.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
execution contract. No result-dependent rescue or implicit fallback exists.

## 4. Entry Rules

1. Evaluate strategy state only after a new host D1 bar and only at a genuine
   broker-month transition.
2. Reconcile owned slot-0 and slot-1 positions first. Any orphan, duplicate,
   same-direction package, wrong symbol/magic, or missing stop is malformed
   and must be flattened before a new decision.
3. Persist the current `yyyymm` in terminal-global state before any fallible
   signal, spread, quote, stop, volume, or order gate. The month never retries.
4. Require exact host `XAUUSD.DWX`, period D1, and exact configured companion
   `XAGUSD.DWX`; select both symbols.
5. Use one uniform native or `+1` D1-label convention for both legs and all
   historical years. Require ten exact synchronized same-calendar pairs from
   `Y-1..Y-10`, matching prior and target endpoint timestamps and a confirming
   following bar. Never use current-month prices or substitute a year.
6. Form `d=r_xau-r_xag` and compute the exact Huber contract above. Invalid
   state or `abs(mu[32])<=1e-12` consumes the month flat.
7. Require positive finite Bid/Ask and positive spread no higher than 1,500
   XAU points and 3,000 XAG points.
8. Compute frozen completed-D1 ATR(20) stops for each leg. Split the one
   aggregate `RISK_FIXED` budget into equal fixed-risk halves and size each
   leg through the framework risk sizer; never size from signal magnitude.
9. Positive location opens BUY XAU then SELL XAG; negative location opens
   SELL XAU then BUY XAG. Both stops are attached on entry and neither leg has
   a target.
10. If the second order fails or final composition is not exactly one
    opposite-direction leg per registered magic, immediately flatten every
    owned leg. No same-month repair entry is allowed.

## 5. Exit Rules

1. Close both owned legs on the first executable tick after broker `yyyymm`
   differs from the package entry month.
2. Close all survivors after 40 elapsed calendar days; this is repair only,
   not an alternate holding-period signal.
3. A per-leg broker hard stop may close one leg. Management must flatten the
   remaining orphan immediately.
4. Framework kill switch or terminal close-only state outranks strategy entry
   and closes through framework services.
5. No profit target, trailing stop, indicator exit, Friday close, scale-out,
   reversal-in-place, or same-month re-entry is authorized.

## 6. Filters (No-Trade Module)

- Framework kill-switch and operational guards remain active.
- Both news axes and legacy news mode are OFF; no external event data is read.
- Framework Friday close is OFF for the source-aligned monthly hold.
- Reject wrong host/period/companion, unavailable symbols, mixed D1-label
  conventions, incomplete or unsynchronized endpoints, missing exact years,
  nonfinite arithmetic, nonpositive MAD/scale/weights/denominator, invalid
  quotes/spreads/stops/lots, malformed owned state, or already-consumed month.
- No trend, oscillator, ratio-z, residual, volatility, calendar-subset,
  inventory, curve, volume, or discretionary filter is authorized.

## 7. Trade Management Rules

- Every tick begins with framework MAE tracking before any guard can return.
- Closed-bar history reconstruction and Huber arithmetic run only on the
  genuine new-month path; ordinary per-tick management reads cached package
  state and native position/quote metadata only.
- Own positions solely by exact EA ID, magic, and symbol. Never manage another
  EA's or manual trade.
- One slot-0 XAU position and one slot-1 XAG position is the only valid open
  state; they must have opposite directions and positive hard stops.
- Any orphan, duplicate, wrong-direction, wrong-symbol, or stopless state is
  flattened immediately. Never add, pyramid, grid, average, or recreate a leg.
- Persist the consumed-month ledger in a terminal global variable so restart
  cannot generate a second attempt.

## Parameters To Test

Only the locked Q02 baseline exists:

| Parameter | Locked value |
|---|---:|
| companion | `XAGUSD.DWX` |
| exact history years | 10 |
| required paired observations | 10 |
| sign epsilon | `1e-12` inclusive |
| MAD normalizer | `1.4826` |
| Huber tuning | `1.5` |
| Huber iterations | 32 |
| D1 history buffer per leg | 3000 bars |
| hard stop | `3.5 * ATR(20,D1)` per leg |
| stale survivor repair | 40 elapsed days |
| XAU/XAG spread ceilings | 1500 / 3000 points |
| aggregate fixed risk | 1000, split 50/50 by stop risk |

No sweep, alternate sample, fallback center, early convergence, side flip,
threshold rescue, or optimization is authorized.

## Risk

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split the aggregate budget into exactly two `RISK_FIXED=500` stop-risk
  budgets, one per leg. This is shared package risk, not 1000 per leg.
- Each leg attaches a frozen `3.5*ATR(20,D1)` hard stop at entry; no target.
- If either lot or stop is invalid, stand down before leg 1. If leg 2 fails,
  flatten leg 1 immediately.
- Worst-case asynchronous gaps and legging can exceed the nominal package
  risk; Q02 owns realized costs and drawdown.
- No live risk mode or live artifact is authorized.

## Data Requirements

- Registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 OHLC/timestamps with enough
  history for the exact ten prior target months plus confirming following
  bars.
- Native broker time, quotes, points, tick values/sizes, volume constraints,
  positions, deals, terminal global variables, and framework services.
- No external file, API, event, curve, inventory, weather, COT, volume, open
  interest, futures chain, trained output, or optimizer artifact.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, sizing, magic resolution, order services, MAE
  tracking, and owned-position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch / close-only instruction.
2. Malformed, stopless, orphaned, duplicate, or same-direction package repair.
3. Broker hard stop followed by immediate surviving-leg cleanup.
4. New broker month exit.
5. Forty-day stale survivor repair.
6. New entry only when flat and the current month was not already consumed.

## Runtime Data Dependencies

All signal inputs are deterministic transformations of completed native MT5
D1 prices and timestamps. ATR is risk plumbing only. No runtime dependency
can update or fit the signal from realized PnL.

## Reputable-Source Gate Findings

- R1: `PASS_WITH_COMPOSITE_ESTIMATOR_PAIR_AND_CFD_TRANSLATION_RISK`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`.
- R4: `PASS`; structural arithmetic only and no prohibited trained signal or
  external runtime feed.

## Framework Alignment

- No-Trade: exact host/slot/input, synchronization, endpoint, exact-year,
  arithmetic, spread, quote, stop, lot, package, and consumed-month guards.
- Trade Entry: paired same-calendar Huber side, opposite legs, shared fixed
  risk, and frozen stops.
- Trade Management: later-month, 40-day stale, orphan, direction, magic,
  duplicate, and stop repair before entry gates.
- Trade Close: framework basket close, per-leg broker stops, and kill switch.

## Kill Criteria

Retire or fail the unchanged candidate on any of:

- zero Q02 packages or fewer than five completed packages in any full
  post-warm-up year;
- nonpositive governed Q02 economics;
- wrong calendar month, endpoint, following-bar confirmation, synchronization,
  exact-year sample, return orientation, median, MAD, scale, weight, update,
  sign band, side, or month-attempt behavior;
- orphaned, duplicated, same-direction, stopless, wrong-magic, or cross-EA
  position handling;
- aggregate fixed-risk, stop, lifecycle, or determinism defect; or
- downstream portfolio-correlation rejection.

No result-dependent sample, estimator, tuning, iteration, side, risk, stop,
hold, spread, or gate change may rescue this identity.

## Falsification And Requalification

A failure is evidence against this exact identity. A mechanically different
estimator, sample, direction, carrier, stop, or lifecycle requires a new card,
new dedup decision, and new identity; it is not a patch to this card.

## Validation Plan

1. Reference-test calendar normalization, exact-year lookup, endpoint
   confirmation, cross-leg timestamp synchronization, and relative-return
   orientation.
2. Reference-test even median/MAD, frozen scale, weights, exactly 32 updates,
   invalid states, epsilon band, and the locked mean/signed-rank disagreement
   vector.
3. Static-test attempt persistence, opposite sides, half-risk sizing,
   atomicity, stop presence, next-month/stale exits, and no current-month data.
4. Lint card, G0 decision, execution contract, spec, symbol scope, magics,
   resolver, setfile, array bounds, performance, and MAE hook.
5. Compile only through the governed `COMPILE_EA` worker path and require zero
   compiler errors/warnings plus strict build PASS.
6. If CPU is below the explicit ceiling, record the successful build to
   create exactly one logical-basket Q02 item. Do not enqueue component legs.

## Version History

| Version | Date | Change | Authority |
|---|---|---|---|
| v1 | 2026-08-29 | Initial exact-ten-year XAU/XAG same-calendar Huber basket card | OWNER commodity/energy portfolio mission |

## Pipeline Phase Status

- Q00 source: APPROVED and committed before extraction.
- G0 card: APPROVED for branch-only build/Q01/Q02 scope.
- Q01: NOT BUILT at card approval.
- Q02: NOT ENQUEUED pending source-fresh governed compile and capacity check.
- Q03+: deterministic pipeline only after Q02 evidence.

## Safety Boundary

Authorized: deterministic identity/magic allocation, one branch-only V5
source build, one exact D1 `RISK_FIXED` logical-basket setfile, strict Q01
validation, governed compile, and one paced Q02 enqueue below the CPU ceiling.

Forbidden: manual tester runs; component-leg Q02 rows; live/demo/shadow/
stress/optimization setfiles; terminal control; AutoTrading; `T_Live`; deploy
or live manifests; portfolio-gate changes; portfolio admission; correlation
waivers; or certification claims.
