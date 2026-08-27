---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-NIST-XTIXNG-MEDRUN-RV-2026_S01
variant_id: VILLAR-NIST-XTIXNG-MEDRUN-RV-2026_S01
source_id: VILLAR-NIST-XTIXNG-MEDRUN-RV-2026
ea_id: QM5_41186
slug: xtixng-median-runs-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41186_xtixng-median-runs-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41186_xtixng_monthly_median_runs_reversion_g0.md
source_approval: decisions/2026-08-27_xtixng_monthly_median_runs_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; NIST/SEMATECH"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; NIST/SEMATECH"
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; NIST/SEMATECH e-Handbook of Statistical Methods section 1.3.5.13, Runs Test for Detecting Non-randomness."
source_citations:
  - type: government_relationship_report
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete report and hashes under strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A_official
    role: time_varying_oil_gas_relation_and_error_correction_context
  - type: peer_reviewed_relationship_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete author copy and adverse findings in governed parent packet"
    quality_tier: A
    role: weak_shifting_oil_gas_tie_and_adverse_evidence
  - type: official_statistical_method
    citation: "NIST/SEMATECH e-Handbook of Statistical Methods, section 1.3.5.13, Runs Test for Detecting Non-randomness."
    location: "complete page and retrieval receipt under strategy-seeds/sources/MOP-NIST-WTI-MEDRUN-TREND-2026/"
    quality_tier: A_official
    role: median_dichotomy_run_definition_and_expected_count
  - type: governed_composite_source
    citation: "QuantMechanica bounded XTI/XNG monthly median-runs ratio-reversion packet."
    location: "strategy-seeds/sources/VILLAR-NIST-XTIXNG-MEDRUN-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_threshold_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xtixng-thirteen-synchronized-completed-month-end-oil-minus-gas-log-ratio-median-dichotomy-run-count-le7-newest-regime-contrarian-equal-notional-basket
sources:
  - "[[sources/VILLAR-NIST-XTIXNG-MEDRUN-RV-2026]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/median-dichotomy-runs]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/median-regime-run-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, market-neutral-style, relative-value, structural-reversion, median-runs, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, oil_gas_relative_value]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41186_XTI_XNG_MEDRUN_RV_D1
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411860000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-8 completed XTI/XNG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete government and peer-reviewed oil/gas relationship evidence including adverse regime findings plus a complete official NIST runs-method page; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, ratio orientation, strict ranks, median omission, six/six balance, run count, inclusive boundary, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX and XNGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict ranks, signs, counts, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; inclusive maximum 7 runs; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month oil/gas median-runs ratio-reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, strict rank permutation, median omission, six/six balance, inclusive R<=7, contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, strict_no_tie_rank_permutation, unique_median_omission, six_six_balance, full_run_count, inclusive_run_threshold_7, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41186_xtixng_monthly_median_runs_reversion_g0.md: R1 PASS with complete government and peer-reviewed oil/gas evidence plus a complete official NIST method page; R2 PASS locks synchronized endpoints, ranks, median omission, balance, run count, boundary, sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XTI/XNG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN; median-dichotomy chronology separates all existing XTI/XNG change-point, split-sample, rank-association, return-spread, and fitted-residual baskets."
---

# QM5_41186 XTI/XNG Monthly Median-Runs Ratio Reversion

## Hypothesis

Crude oil and natural gas share substitution, co-production, drilling,
financing, and some LNG linkages, while regional gas fundamentals repeatedly
separate them. A permanently fixed ratio assumes too much, and a continuously
fitted residual imports model-form risk. This card instead asks whether
thirteen synchronized completed monthly oil-minus-gas log ratios have formed
few enough regimes around their own median to identify a persistent relative
state, then fades the newest state for one broker month.

Opposite equal-target-notional legs are designed to reduce outright energy
direction and form a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/VILLAR-NIST-XTIXNG-MEDRUN-RV-2026/source.md`, SHA-256
`477EBD53C6EE74BCD2986FA0469C3431BEBA750AA2EAA5609DCDF3506AB76FF3`,
authorized before extraction by
`decisions/2026-08-27_xtixng_monthly_median_runs_reversion_source_approval.md`.

Villar-Joutz and Ramberg-Parsons supply the weak, time-varying oil/gas
relationship and adverse evidence against a universal ratio. NIST supplies
the chronological median-dichotomy run definition and expected-run formula.
None tests this ratio state, inclusive boundary, contrarian package,
continuous CFDs, or execution contract.

No source return, alpha, coefficient, probability, p-value, significance,
density, profit factor, drawdown, cost, hedge ratio, neutrality, CFD
equivalence, decorrelation, or portfolio statistic is imported.

## Non-Duplicate Decision

The fail-closed checker returned CLEAN across 4,685 registry identities,
1,336 cards, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_xtixng_median_runs_rv_preallocation_dedup_20260827.json`.

- `QM5_41182` applies median runs to one WTI price path and continues the
  newest outright regime; this card fades a synchronized two-leg ratio state.
- `QM5_41175` searches all possible Pettitt change points.
- `QM5_41178` sums fixed-block Mann-Whitney ordinal wins.
- `QM5_41179` counts six Cox-Stuart early/late pair signs.
- `QM5_41180` measures Spearman displacement from calendar rank.
- `QM5_20237` fits a trend-augmented oil/gas OLS residual and convergence exit.
- Fixed-ratio, return-spread, channel, momentum, carry, calendar, volatility,
  and factor-rank energy baskets transform different state.
- `QM5_12567` is a long-only short-horizon XNG cumulative-RSI2 pullback.

None dichotomizes thirteen synchronized monthly ratio endpoints around their
unique median, counts every resulting chronological run, and fades the newest
ratio regime at inclusive `R<=7`. Verdict:
`CLEAN_XTIXNG_MONTHLY_MEDIAN_DICHOTOMY_RUNCOUNT_LE7_NEWEST_RATIO_REGIME_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XTIUSD.DWX`; companion/traded slot 1: exact
  `XNGUSD.DWX`.
- Logical tester symbol: `QM5_41186_XTI_XNG_MEDRUN_RV_D1` on the XTI host.
- Timeframe: D1; intended magics `411860000` and `411860001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: latest synchronized completed endpoint from each of exactly
  thirteen immediately prior consecutive broker months.
- Hold: next broker-month boundary; forty days is stale repair.
- Expected pre-result cadence: five to eight packages/year; Q02 retires below
  five in any full post-warm-up year.

## Formula

For chronological synchronized completed monthly pairs `i=0..12`:

```text
L[i] = ln(XTI_close[i]) - ln(XNG_close[i])
rank[i] = strict ascending rank of L[i] in 1..13

B = chronological ranks below 7 mapped to -1 and above 7 mapped to +1
    while the unique median rank 7 is omitted

require len(B)=12, count(-1)=6, count(+1)=6
R = 1 + sum(B[k] != B[k-1]), k=1..11

SELL XTI / BUY XNG iff R <= 7 and rank[12] > 7
BUY XTI / SELL XNG iff R <= 7 and rank[12] < 7
FLAT                    iff R > 7 or rank[12] = 7
```

The median does not receive a side. After omission, its chronological
neighbors become adjacent. Exact equality at seven runs qualifies. There is
no p-value, fitted coefficient, fitted center, slope, magnitude weight,
fallback direction, or signal-strength sizing.

## Rules

- Exact EA ID, symbols, D1, slots, magics, risk/news/Friday contract, and
  every locked input are mandatory.
- Consume the broker month before every fallible entry gate.
- Use only completed exact-timestamp-matched monthly endpoints; current-month
  data never enters the signal.
- Reject wrong counts, missing months, stale or mismatched endpoints,
  nonpositive prices, nonfinite or tied ratios, invalid ranks, wrong median
  omission, wrong balance, invalid run count, or side mismatch.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require EA ID 41186, exact host and companion, D1, slots 0/1, active
   magics `411860000`/`411860001`, fixed-risk framework inputs, and every
   singleton strategy input.
2. Process malformed-package repair and prior-month/stale exits before any
   entry-only gate.
3. Require a genuine new broker month within 180 minutes of raw host D1 bar
   open; persist `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or orders. Never retry that month.
4. Reject owned exposure or same-magic current-month entry deals.
5. From bounded D1 histories, reconstruct exactly thirteen immediately prior
   consecutive completed broker months. For each month select the newest
   exact-timestamp-matched XTI/XNG close pair. Require strict chronology,
   positive finite prices, exact month coverage, and endpoint age no more
   than ten calendar days.
6. Form thirteen finite oil-minus-gas log ratios, reject all ties, assign a
   strict rank permutation 1..13, omit rank seven, prove six low and six high
   states, and count every chronological run.
7. Require `2<=R<=7` and a nonmedian newest ratio. Map a high newest ratio to
   SELL XTI / BUY XNG and a low newest ratio to BUY XTI / SELL XNG. A weak or
   invalid state consumes the month flat.
8. Require XTI/XNG spreads no greater than 1,500/3,000 points, valid
   executable quotes, completed `ATR(20,D1)` for both legs, and valid contract
   metadata.
9. Split one aggregate `RISK_FIXED=1000` stop budget equally. Jointly round
   down lots to target equal absolute USD notionals while keeping combined
   frozen `3.5*ATR` stop risk within budget and notional mismatch within 20%.
10. Open XTI first and XNG second. Keep the package only if exactly one valid,
    stopped, correctly directed position exists in each slot. On any order or
    final validation failure, flatten every owned leg immediately.

## 5. Exit Rules

1. Close both legs on the first observed tick whose broker `yyyymm` is later
   than the package entry month.
2. Close both legs after forty elapsed calendar days as stale repair.
3. Immediately close all owned legs when the package is orphaned, duplicated,
   same-side, wrong-symbol/magic, missing a hard stop, nonfinite, or outside
   the 20% notional mismatch ceiling.
4. Broker hard stops and the framework kill switch remain authoritative.
5. There is no ratio convergence recheck, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, discretionary exit, or Friday
   flatten.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host/timeframe/ID/slots/magics, risk mode,
  news/Friday modes, or locked strategy inputs.
- Reject a consumed month, late monthly tick, owned exposure, same-month deal,
  missing or stale history, wrong month/pair count, timestamp mismatch,
  nonpositive close, tied/nonfinite ratio, invalid rank permutation, wrong
  median omission or six/six balance, invalid/excessive run count, median
  newest point, excessive spread, invalid quote, missing ATR, invalid stop,
  contract defect, or invalid sizing solution.
- Lifecycle exits and package repair run before entry-only filters.
- Runtime may not read an external file/API, futures chain, paper estimate,
  optimizer output, trained artifact, prior result, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one complete two-leg package and one consumed attempt per
  broker month.
- Preserve original broker hard stops and lots; never modify either after
  entry.
- On trade-state change or each new completed host D1 bar, repair malformed
  exposure and enforce month/stale exits before checking new entry state.
- Restart recovery combines a persistent month marker with owned position and
  deal history. Tester initialization clears only a marker dated after the
  restarted test clock.
- No randomness, adaptive parameter fit, external state, partial close,
  scale-in, grid, martingale, or pyramiding is allowed.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled for the multi-session paired hold.
- Stress rejection: zero for Q02 baseline.
- Framework kill switch and server-side hard stops: authoritative.

## Exit Precedence

1. Framework kill switch and each server-side hard stop.
2. Malformed, orphaned, duplicated, wrong-side, wrong-symbol/magic, stopless,
   or notional-invalid package repair.
3. Broker-month transition.
4. Forty-calendar-day stale repair.
5. No Friday, news, target, trail, break-even, partial, convergence, or
   discretionary exit.

## Runtime Data Dependencies

- Exact chart route `XTIUSD.DWX`, D1; synchronized companion
  `XNGUSD.DWX`, D1.
- Native completed D1 times/closes, completed `ATR(20,D1)`, bid/ask, spreads,
  contract/volume metadata, broker calendar, positions, deals, and one
  terminal-persistent month marker.
- No external file, API, futures curve, inventory series, macro series,
  analyst input, optimizer output, trained artifact, or portfolio state.

## Parameters To Test

Q02 uses only locked defaults; this table does not authorize rescue tuning.

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xng_symbol` | XNGUSD.DWX | [XNGUSD.DWX] | exact companion and slot 1 |
| `strategy_endpoint_count` | 13 | [13] | synchronized monthly ratio observations |
| `strategy_max_runs` | 7 | [7] | inclusive median-regime run boundary |
| `strategy_history_bars_d1` | 900 | [900] | bounded pair reconstruction |
| `strategy_entry_window_minutes` | 180 | [180] | new-month grace |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | package balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | stale guard |
| `strategy_xti_max_spread_points` | 1500 | [1500] | XTI spread ceiling |
| `strategy_xng_max_spread_points` | 3000 | [3000] | XNG spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Changing any formation, run, direction, clock, risk, stop, balance, hold,
spread, order-sequence, or lifecycle value requires a new strategy identity.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for one aggregate package. Each leg receives half of the
stop-risk budget before equal-notional adjustment. Both legs can gap, the weak
source tie can structurally break, XNG is materially more volatile, lot
granularity creates imbalance, spread and financing can overwhelm a low-
frequency edge, and atomic repair can realize one-sided loss. Equal target
notionals are construction targets, not proof of neutrality.

## Reputable-Source Criteria And Allowability

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete official/peer-reviewed oil-gas research with adverse evidence plus complete NIST runs method; exact trading conjunction untested. |
| R2 | PASS | Exact clock, synchronization, ratios, ranks, median omission, balance, run count, direction, attempt, risk, atomicity, and lifecycle fixed. |
| R3 | PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK | Registered XTI/XNG D1 routes and native MT5 state supply all runtime fields. |
| R4 | PASS | Fixed deterministic arithmetic and state only, without trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Framework Alignment

- no_trade: exact host/timeframe/ID/slots, locked inputs, risk/news/Friday
  contract, month/attempt, history, synchronization, ratios, ranks, median,
  balance, run count, direction, spreads, quotes, ATR, stops, sizing, and
  package guards.
- trade_entry: persistent attempt, exact contrarian sides, equal-notional
  shared risk, frozen hard stops, and second-leg rollback.
- trade_management: month/stale exit and malformed-package repair before
  every new entry decision.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Deterministic Validation Fixtures

The build must include a standalone reference test that proves:

1. Monotone ratios `[1..13]` omit rank seven, produce two runs, and map newest
   high to SELL XTI / BUY XNG.
2. Reflected monotone ratios `[13..1]` produce two runs and map newest low to
   BUY XTI / SELL XNG.
3. A strict rank path with exactly seven runs qualifies; one with eight runs
   remains flat.
4. A newest median remains flat even when the remaining path has at most seven
   runs.
5. Any tied ratio, wrong endpoint count, invalid rank permutation, wrong
   median omission, wrong six/six balance, or run count outside 2..12 fails.
6. Exact enumeration of the 12,012 median-position/binary-order
   representations yields 6,744 qualifiers split 3,372/3,372 by side.
7. At least one fixed fixture separates this rule from Spearman,
   Mann-Whitney, Cox-Stuart, and outright WTI median-runs behavior.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five completed packages in any full
post-warm-up year, or nonpositive governed economics. Any wrong month count or
timestamp, current-month leak, ratio inversion, tie acceptance, rank defect,
median bridge, balance defect, run-count error, wrong threshold/direction,
same-month retry, malformed package retention, aggregate-risk breach, or
nondeterminism is an implementation failure rather than a tunable result.

Changing the carrier, ratio orientation, clock, endpoint count, rank/tie rule,
median treatment, run definition, boundary, sides, stops, risk split,
mismatch limit, lifecycle, symbols, timeframe, news/Friday mode, or risk mode
requires a new identity and full pipeline qualification. Realized
diversification is assessed only at unchanged Q09.

## Safety Boundary

This card authorizes deterministic allocation, one branch-only build, strict
compile/Q01, three backtest-only `RISK_FIXED` setfiles (logical and two
component warm-up routes), and one paced logical-basket Q02 enqueue if CPU
capacity permits. It does not authorize a manual backtest; live, demo,
shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy or
live manifest; portfolio-gate mutation; portfolio admission; correlation
waiver; terminal control; or component-leg Q02 rows.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial XTI/XNG monthly median-runs ratio-reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED; R1-R4 PASS with named risks | source approval, governed packet, clean dedup receipt, deterministic allocation, and G0 decision |
| Q01 Build Validation | - | NOT BUILT | no compile claim |
| Q02 Baseline Screening | - | NOT ENQUEUED | Q01 and capacity gates pending |
