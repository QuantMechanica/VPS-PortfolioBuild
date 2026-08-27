---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026_S01
variant_id: VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026_S01
source_id: VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026
ea_id: QM5_41188
slug: xtixng-mrepmedian-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41188_xtixng-mrepmedian-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41188_xtixng_monthly_repeated_median_reversion_g0.md
source_approval: decisions/2026-08-27_xtixng_monthly_repeated_median_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Andrew F. Siegel"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; Andrew F. Siegel"
source_citation: "Villar and Joutz (2006), U.S. EIA, The Relationship Between Crude Oil and Natural Gas Prices; Ramberg and Parsons (2012), The Energy Journal 33(2), 13-35, DOI 10.5547/01956574.33.2.2; Siegel (1982), Biometrika 69(1), 242-244, DOI 10.1093/biomet/69.1.242."
source_citations:
  - type: government_research_report
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete 43-page read preserved in strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A_official
    role: physical_economic_oil_gas_linkage_and_model_instability
  - type: peer_reviewed_relationship_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete author-copy read preserved in the governed parent packet"
    quality_tier: A
    role: weak_time_varying_oil_gas_relation_and_adverse_evidence
  - type: peer_reviewed_statistical_method_record
    citation: "Siegel, A. F. (1982). Robust Regression Using Repeated Medians. Biometrika 69(1), 242-244."
    location: "DOI 10.1093/biomet/69.1.242; complete official Oxford Academic bibliographic and abstract record preserved in strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md"
    quality_tier: A_record
    role: repeated_median_nested_robust_regression_lineage_only
  - type: governed_composite_source
    citation: "QuantMechanica bounded XTI/XNG monthly repeated-median ratio-slope reversion extraction."
    location: "strategy-seeds/sources/VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_synchronization_direction_risk_atomicity_and_lifecycle
strategy_mechanic: synchronized-thirteen-completed-month-end-oil-minus-gas-log-ratio-siegel-repeated-median-of-thirteen-pivot-specific-twelve-slope-medians-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/repeated-median-ratio-slope-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-end-ratio-repeated-median-slope]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, relative-value, market-neutral-style, structural-reversion, repeated-median, robust-slope, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, oil_gas_relative_value]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41188_XTI_XNG_MREPMEDIAN_RV_D1
symbol: QM5_41188_XTI_XNG_MREPMEDIAN_RV_D1
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411880000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 10-12 completed XTI/XNG packages per full post-warm-up year after thirteen synchronized completed month ends and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ESTIMATOR_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete government and peer-reviewed oil/gas relationship evidence with adverse regime findings plus an official peer-reviewed repeated-median method record; the exact contrarian ratio basket is an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, ratio orientation, pivot groups, forward slopes, both median stages, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX and XNGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, financing, and continuous-CFD basis risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, finite arithmetic, ATR risk controls, and execution state; no trained signal, prohibited indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; exact repeated-median pivot arithmetic; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month oil/gas ratio repeated-median reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, consecutive months, oil-minus-gas orientation, thirteen pivot groups, twelve forward slopes per pivot, inner median indexes 5/6, outer index 6, contrarian sides, one attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_oil_minus_gas_ratio_orientation, exact_thirteen_pivots, exact_twelve_slopes_per_pivot, forward_slope_orientation, inner_even_median_indexes_5_6, outer_odd_median_index_6, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41188_xtixng_monthly_repeated_median_reversion_g0.md: R1 PASS with explicit estimator/carrier translation risk using complete government and peer-reviewed oil/gas evidence plus official repeated-median lineage; R2 PASS locks synchronized endpoints, pivot groups, slopes, both median stages, sides, attempt, aggregate risk, stops, and repair; R3 PASS registered native XTI/XNG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical exact/fuzzy dedup is clean and manual review separates outright-WTI, precious-metal, ECM, z-score, and other XTI/XNG statistical families."
---

# QM5_41188 XTI/XNG Thirteen-Month Repeated-Median Ratio Reversion

## Hypothesis

Oil and natural gas are linked through substitution, co-production, drilling,
finance, and LNG, but the relationship is weak, unstable, and periodically
decoupled. This card asks whether a broad thirteen-month displacement in the
synchronized oil-minus-gas log ratio, summarized by an exact repeated-median
slope, subsequently reverts. It fits no equilibrium coefficient, center,
scale, or convergence speed and never scales risk by signal magnitude.

Opposite equal-target-notional legs are designed to reduce common outright
energy direction and produce a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026/source.md`,
SHA-256
`BC85645551B176DC372326985AC783071F6E8AAF958F2ACB73A4D8894404B5DD`,
authorized by
`decisions/2026-08-27_xtixng_monthly_repeated_median_reversion_source_approval.md`
at commit `6c221e724` and extracted at commit `7e4e37acd` before card review.

Villar/Joutz and Ramberg/Parsons supply a related but state-dependent oil/gas
hypothesis plus binding adverse evidence. Siegel supplies repeated-median
robust-regression lineage. None tests this exact paired monthly ratio fade,
Darwinex continuous CFDs, equal-notional fixed-dollar ATR risk, or the QM book.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, robustness improvement, CFD
equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed checker scanned 4,687 registry identities,
1,338 card files, and 45 current Strategy Wiki nodes and returned `CLEAN`.
Evidence is
`artifacts/qm5_xtixng_mrepmedian_rv_preallocation_dedup_20260827.json`,
SHA-256
`AD7CC67FF1F2F7D816624193F7F6B1DB68DAFDF3E26C9EB5FF4F7BCE9081B5AC`.

Manual family review fixes the mechanical boundary:

- `QM5_41164_xauxag-mrepmedian-rv` applies the same estimator to a
  gold/silver path and owns only precious-metal legs. This card owns an
  economically distinct oil/gas path and only energy legs.
- `QM5_41158_wti-repmedian-tr` applies the estimator to outright WTI, follows
  its sign, and owns one leg. This card applies it to a synchronized ratio,
  fades the sign, and owns an atomic equal-notional basket.
- Pettitt, Mann–Whitney, Spearman, and median-runs XTI/XNG cards use change-
  point, fixed-block ordinal-win, time-rank, and dichotomized-transition state
  functions rather than nested pivot-slope medians.
- `QM5_20237_xtixng-ecm-rv` fits a rolling trend-augmented OLS residual and
  convergence exit. This card fits no coefficient, intercept, center, scale,
  residual, or half-life.
- `QM5_12578_eia-oilgas-ratio` standardizes a fixed log-price ratio. This card
  uses only the sign of a nested-median ratio slope.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither this mechanic nor lifecycle.

Verdict:
`CLEAN_XTIXNG_MONTHLY_SIEGEL_REPEATED_MEDIAN_RATIO_SLOPE_REVERSION_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: `XTIUSD.DWX`; companion/traded slot 1: `XNGUSD.DWX`.
- Logical tester symbol: `QM5_41188_XTI_XNG_MREPMEDIAN_RV_D1` on XTI host.
- Timeframe: D1; intended magics `411880000` and `411880001`.
- Decision: first synchronized executable D1 tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected cadence: approximately ten to twelve packages per full post-warm-
  up year; retire below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, symbol metadata,
  position, deal, broker calendar, and terminal-persistent attempt state only.

## Formula

At the start of month `t`, let `L[0]..L[12]` be synchronized completed-month
oil-minus-gas log ratios from months `t-13..t-1`, oldest to newest:

```text
L[i] = ln(XTI_close[i]) - ln(XNG_close[i])

for i = 0..12:
  slopes_i = []
  for j = 0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    slopes_i.append((L[hi] - L[lo]) / (hi - lo))
  require len(slopes_i) == 12
  ordered = ascending(slopes_i)
  pivot_median[i] = (ordered[5] + ordered[6]) / 2

repeated_median = ascending(pivot_median[0..12])[6]
```

Positive repeated median means SELL XTI / BUY XNG. Negative means BUY XTI /
SELL XNG. Exact zero or invalid state consumes the month flat. Magnitude never
scales risk.

## Rules

These are the complete authorized baseline. There is no parameter sweep,
pooled-slope fallback, fitted intercept, loss objective, endpoint agreement,
OLS, z-score, volatility signal, seasonal filter, external series, or prior-
result gate.

## 4. Entry Rules

1. Require exact EA ID `41188`, host `XTIUSD.DWX`, companion `XNGUSD.DWX`, D1,
   slots 0/1, and every baseline input locked to its declared value.
2. Process lifecycle repair before entry-only gates. Evaluate only at a
   genuine broker-month transition no later than 180 elapsed minutes after
   the raw host D1 bar open.
3. Persist current `yyyymm` as consumed before history, signal, news, spread,
   quote, ATR, sizing, margin, or order checks. No flat, rejected, failed,
   stopped, partial, or blocked outcome retries that month.
4. Reject owned exposure or any same-month entry deal for either magic.
5. Reconstruct exactly thirteen consecutive completed month-end pairs from
   bounded D1 buffers. In each month require the latest exactly timestamp-
   matched close pair; reject missing, duplicate, unmatched, current-month,
   nonchronological, or more-than-ten-day-stale newest pairs.
6. Keep pairs oldest to newest. Require positive finite closes and exactly
   thirteen finite oil-minus-gas natural-log ratios.
7. For each of thirteen pivots, enumerate exactly twelve slopes to every other
   endpoint. Orient each from earlier to later and divide by its positive
   integer month-index distance.
8. Sort each pivot's twelve slopes and average zero-based indexes 5 and 6.
   Require thirteen finite pivot medians, sort them, and take index 6. Fade
   the strict sign; exact zero consumes the month flat.
9. Require both spreads in bounds, executable quotes, completed
   `ATR(20,D1)`, valid symbol metadata, fixed-risk sizing, and realized target
   absolute-notional mismatch no greater than 20%.
10. Split aggregate fixed stop-risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no targets.
11. Submit XTI first and XNG second. Keep only one correctly directed,
    correctly registered, stop-protected position in each slot; otherwise
    flatten every owned leg immediately.

## 5. Exit Rules

1. Close both legs on the first processed tick in every later broker month
   before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close every owned leg immediately if the package is orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, wrong-direction, missing a stop, or
   outside the 20% notional-mismatch tolerance.
4. Broker hard stops and framework kill switch remain authoritative.
5. Friday close is disabled because the approved hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, timeframe, EA ID, slots, fixed-risk,
  news/Friday contract, or locked strategy inputs.
- Reject consumed attempt, owned exposure, same-month entry history, malformed
  synchronization, nonconsecutive months, current-month leakage, stale newest
  pair, nonpositive/nonfinite close, invalid ratio, wrong pivot or slope count,
  invalid denominator or median, exact-zero statistic, excessive spread,
  invalid quote, unavailable ATR, invalid stop/volume, or notional mismatch.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  runs before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, forecast, trained output, optimizer result, portfolio
  state, live manifest, or prior pipeline result.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package and
  one consumed attempt per broker month.
- Preserve original hard stops; close before monthly renewal or after forty
  days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- Lifecycle repair flattens every owned leg before any new entry logic when
  package validity fails.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xng_symbol` | XNGUSD.DWX | [XNGUSD.DWX] | exact companion and traded slot 1 |
| `strategy_month_end_count` | 13 | [13] | synchronized completed-month ratio observations and pivots |
| `strategy_history_bars_d1` | 900 | [900] | bounded pair reconstruction |
| `strategy_entry_window_minutes` | 180 | [180] | maximum elapsed time after raw new-month host bar open |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest synchronized endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator per leg |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | realized package-balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_xti_max_spread_points` | 1500 | [1500] | XTI entry spread ceiling |
| `strategy_xng_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Every value is a locked singleton. Changing the carrier, endpoint count,
pivot membership, median convention, direction, clock, risk, stop, balance,
hold, spread, order sequence, or retry policy requires a new card and full
pipeline run.

## Author Claims

Villar/Joutz and Ramberg/Parsons document a weak, state-dependent oil/gas
relationship and adverse evidence against a simple constant tie. Siegel
documents repeated-median statistical lineage. They do not claim that this
rule works, that the statistic is superior, that continuous CFDs reproduce
their data, or that the package diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Risk is high: both legs
can gap, the oil/gas relationship can structurally break, volume rounding can
create imbalance, spreads and financing can dominate a low-frequency edge,
and atomic repair can realize one-sided loss. Equal target notionals are a
market-neutral-style construction, not proof of market or portfolio
neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full post-
  warm-up year.
- Fail on wrong synchronization, month order, current-month leakage, stale
  endpoint, ratio orientation, pivot membership, forward slope direction,
  per-pivot count other than twelve, wrong inner indexes, pivot count other
  than thirteen, wrong outer index, wrong sides, retry, non-atomic package,
  risk-mode breach, stop defect, hold beyond forty days, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, statistic, direction, carrier,
  risk, stop, balance tolerance, hold, spread cap, retry policy, or order
  sequence.

## Strategy Allowability Check

- [x] R1: PASS with estimator/carrier translation risk. Complete government
  and peer-reviewed oil/gas evidence plus an official peer-reviewed method
  record; no method performance is imported.
- [x] R2: PASS. Fixed endpoints, synchronization, pivots, slopes, both median
  stages, direction, attempt, aggregate risk, atomicity, and exits.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XTI
  and XNG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic logarithms, pairwise arithmetic, sorting,
  calendar, and ATR risk arithmetic; no trained model, banned signal
  indicator, external feed, grid, or martingale.
- [x] Dedup: canonical exact/fuzzy scan is clean; manual review separates the
  same-estimator metal and outright-WTI carriers plus all existing XTI/XNG
  state functions.

## Framework Alignment

- no_trade: exact XTI/XNG/D1/EA/slots, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized endpoint reconstruction,
  exact nested medians, spread/quote/ATR/stop checks, equal-notional sizing,
  and atomic two-order package validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five packages per full post-warm-up
year, or nonpositive governed economics. Any current-month leakage, missing or
duplicate month, nonlatest pair, unmatched timestamp, wrong ratio, missing or
duplicated pivot slope, wrong median, side, retry, package, risk, stop, or
determinism is an implementation failure, not a tunable result.

Any change to carrier, observation count, synchronization, pivot grouping,
slope orientation, median convention, direction, stop, spread caps, atomic
sequence, attempt lifecycle, symbol, timeframe, news/Friday mode, or risk mode
requires a new binary and full pipeline requalification. Realized
diversification may only be assessed at unchanged Q09; correlation failure
receives no waiver here.

## Safety Boundary

This card authorizes only governed magic allocation, one branch build, strict
compile/Q01, three D1 `RISK_FIXED` backtest setfiles (two registered legs and
one logical basket), and one paced non-live logical Q02 enqueue if CPU capacity
permits. It does not authorize a manual backtest; live, demo, shadow, stress,
or optimization setfile; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate mutation; portfolio admission; component-leg Q02 row; or
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial XTI/XNG repeated-median ratio-reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED; R1-R4 PASS | `decisions/2026-08-27_qm5_41188_xtixng_monthly_repeated_median_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
