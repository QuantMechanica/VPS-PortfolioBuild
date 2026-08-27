---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026_S01
variant_id: VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026_S01
source_id: VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026
ea_id: QM5_41178
slug: xtixng-mwilcoxon-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41178_xtixng-mwilcoxon-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41178_xtixng_monthly_mann_whitney_location_shift_reversion_g0.md
source_approval: decisions/2026-08-27_xtixng_monthly_mann_whitney_location_shift_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; H. B. Mann; D. R. Whitney; R Core Team"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; H. B. Mann; D. R. Whitney; R Core Team"
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; Mann and Whitney (1947), On a Test of Whether one of Two Random Variables is Stochastically Larger than the Other, Annals of Mathematical Statistics 18(1), DOI 10.1214/aoms/1177730491; R Core Team stats::wilcox.test source and manual."
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
  - type: peer_reviewed_statistical_method_record
    citation: "Mann, H. B. and Whitney, D. R. (1947). On a Test of Whether one of Two Random Variables is Stochastically Larger than the Other. The Annals of Mathematical Statistics 18(1), 50-60."
    location: "DOI 10.1214/aoms/1177730491; metadata record; body not claimed completely read"
    quality_tier: A_record_only
    role: two_sample_ordinal_location_statistic_lineage
  - type: public_method_implementation
    citation: "R Core Team, stats::wilcox.test source and manual."
    location: "public wch/r-source mirror commit 7344a2d9d96b3c2b997535d3abc8c3a44af16e82; complete relevant files in governed parent receipt"
    quality_tier: A_method_implementation
    role: exact_two_sample_rank_sum_and_pair_count_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded XTI/XNG twelve-month fixed-block Mann-Whitney ratio location-shift reversion packet."
    location: "strategy-seeds/sources/VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_threshold_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xtixng-twelve-synchronized-completed-month-end-oil-minus-gas-log-ratio-fixed-six-older-six-newer-strict-no-tie-mann-whitney-u-location-shift-threshold-24-12-contrarian-equal-notional-basket
sources:
  - "[[sources/VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/nonparametric-two-sample-location]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/mann-whitney-u-pair-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, market-neutral-style, relative-value, structural-reversion, mann-whitney-location-shift, fixed-block-rank-comparison, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, oil_gas_relative_value]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41178_XTI_XNG_MWILCOXON_RV_D1
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411780000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 4-8 completed XTI/XNG packages per full post-warm-up year after twelve synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 4
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RELATION_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete government and peer-reviewed oil/gas relationship evidence including adverse findings, named original Mann-Whitney record, and complete pinned R Core method files; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, fixed blocks, strict ties, pair-count and rank-sum identities, integer thresholds, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX and XNGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 12 synchronized endpoints; fixed 6/6 blocks; inclusive U boundaries 12/24; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
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
review_focus: "Falsify a twelve-completed-month oil/gas fixed-block Mann-Whitney location-shift reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, fixed six/six membership, strict tie rejection, all 36 comparisons, U/rank-sum identities, inclusive 12/24 contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, twelve_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, strict_no_tie_ratios, fixed_six_by_six_blocks, all_36_cross_block_comparisons, complementary_u_identity, newer_rank_sum_identity, inclusive_u_thresholds_12_24, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41178_xtixng_monthly_mann_whitney_location_shift_reversion_g0.md: R1 PASS with complete government and peer-reviewed oil/gas evidence, named Mann-Whitney record, and complete pinned R Core method files; R2 PASS locks synchronized endpoints, fixed blocks, ties, U identities, thresholds, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XTI/XNG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup found no exact match; two declared fuzzy neighbors were manually adjudicated clean because one changes the carrier/source and the other changes the statistic and fixed-split state object."
---

# QM5_41178 XTI/XNG Twelve-Month Mann-Whitney Location-Shift Reversion

## Hypothesis

Crude oil and natural gas are linked through substitution, co-production,
drilling inputs, finance, and some LNG contracts, while regional gas
fundamentals can materially decouple them. Instead of assuming a stable ratio
center or fitting a hedge coefficient, this card asks whether the most recent
six synchronized month-end oil-minus-gas log ratios are ordinally displaced
from the prior six. It fades only a sufficiently separated two-sample
location shift.

Opposite equal-target-notional legs are designed to reduce common outright
energy direction and form a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026/source.md`,
SHA-256 `60522B7713DA763799783D2B5C8289A8A3E156C6CDA3C2BE5DC529D315097BCE`,
authorized by
`decisions/2026-08-27_xtixng_monthly_mann_whitney_location_shift_reversion_source_approval.md`
and committed as `74c7b7f41` before card extraction.

Villar-Joutz and Ramberg-Parsons supply the weak, time-varying oil/gas
relationship and binding adverse evidence. Mann and Whitney supply named
peer-reviewed method lineage; the complete pinned R Core files define the
operative rank-sum and favorable-pair-count identity. The original 1947
article body is not represented as completely read. None tests this
synchronized XTI/XNG threshold, contrarian package, continuous CFDs, or
fixed-dollar execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, statistical
significance, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,677 registry
identities, 1,328 cards, and 45 Strategy Wiki nodes. It found no exact match
and returned two declared fuzzy neighbors for manual review. The receipt is
`artifacts/qm5_xtixng_mwilcoxon_rv_preallocation_dedup_20260827.json`,
SHA-256 `F675A8FA910297733C86749A823355560FE9DBB9E858D7D7C5B5D1BC8B00911B`.

Research/QB review fixes a new statistic/carrier conjunction:

- `QM5_41177_xauxag-mwilcoxon-shift-rv` uses the same fixed-block statistic
  on a gold/silver ratio. This card uses separately sourced oil/gas relation
  evidence, XTI/XNG execution, and energy basis/atomicity risks.
- `QM5_41175_xtixng-mpettitt-rv` shares the carrier but ranks thirteen ratios,
  searches all split locations, and requires one central maximum. This card
  uses twelve ratios, one prespecified split, only 36 cross-block comparisons,
  and inclusive fixed U boundaries. It never searches or maximizes.
- `QM5_20237_xtixng-ecm-rv` fits a 252-D1 trend-augmented OLS residual and
  z-score. This card performs no regression, estimates no beta, and consumes
  twelve monthly endpoints.
- Ratio z-score, return-spread, channel, momentum, carry, calendar, tail,
  volatility, and factor-rank cards observe different state objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback, not monthly paired-energy ordinal reversion.

For a thirteen-ratio rank path, this card uses the latest twelve values. Path
`[11,13,2,4,6,1,3,10,5,7,8,9,12]` gives short-ratio at `U_new=29`, while
Pettitt is flat because its unique maximum is at edge split `K=2`. Path
`[1,8,3,5,7,11,9,4,2,12,13,6,10]` is flat here at `U_new=20` while Pettitt
qualifies from its unique central maximum. Path
`[11,10,9,8,3,2,1,13,4,5,6,12,7]` qualifies short-ratio at the inclusive
`U_new=24` boundary while Pettitt takes the opposite side from its unique
`K=4` maximum.

Verdict:
`CLEAN_AFTER_DECLARED_FUZZY_REVIEW_XTIXNG_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_RATIO_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XTIUSD.DWX`; companion/traded slot 1: exact
  `XNGUSD.DWX`.
- Logical tester symbol: `QM5_41178_XTI_XNG_MWILCOXON_RV_D1` on the XTI host.
- Timeframe: D1; intended magics `411780000` and `411780001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: twelve consecutive synchronized completed broker-month ends;
  current month excluded; one fixed older/newer split.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: four to eight packages per full post-warm-up
  year; retire below four.

## Formula

For chronological synchronized completed-month close pairs `i=0..11`:

```text
s[i] = ln(XTI_close[i]) - ln(XNG_close[i])
require every s[i] pairwise distinct

O = s[0..5]
N = s[6..11]
U_new = count(N[j] > O[i]) over every i=0..5 and j=0..5
U_old = count(O[i] > N[j]) over the same pairs
W_new = sum(strict combined ranks of N)

require U_new + U_old = 36
require W_new - 21 = U_new

SELL XTI / BUY XNG iff U_new >= 24
BUY XTI / SELL XNG iff U_new <= 12
FLAT otherwise
```

Exact ties consume the month flat. Boundaries are inclusive. There is no
average-rank handling, p-value, variable split, maximum search, fitted center
or scale, endpoint fallback, or signal-strength sizing.

Exact enumeration of the 924 possible six-rank assignments gives 182 in each
tail and a combined qualification rate of `0.3939393939393939`, or about
4.7273 monthly decisions per year under random ordering only. This is not an
independence, significance, frequency, or profitability claim.

## Rules

- `ea_id=41178`, exact XTI/XNG symbols, D1, slots 0/1, magics `411780000` /
  `411780001`.
- Consume normalized broker month before every fallible entry gate.
- Use exactly twelve immediately prior consecutive completed month keys and
  the latest exactly timestamp-matched pair in each. The newest pair must be
  no more than ten calendar days stale.
- Split once after observation six, prove all pair-count/rank-sum invariants,
  and use only inclusive thresholds 12/24. No alternate split, tie deletion,
  fitted statistic, magnitude weight, or fallback is permitted.
- High `U_new` maps to short ratio; low `U_new` maps to long ratio. An
  interior value consumes the month flat.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, host, companion, D1 period, slots, risk mode,
   framework inputs, and all locked strategy inputs.
2. Process package repair and prior-month/stale exits before entry-only gates.
3. Require a genuine new broker month no later than 180 elapsed minutes after
   raw host D1 bar open.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No flat, rejected, partial, failed,
   stopped, or restarted outcome retries that month.
5. Reject owned exposure or same-magic entry deals already recorded in the
   current broker month.
6. Reconstruct twelve consecutive completed synchronized month-end pairs;
   reject missing, duplicate, unmatched, current-month, nonchronological,
   nonpositive, nonfinite, or stale data.
7. Compute twelve log ratios and reject any exact tie. Split fixed blocks,
   count all 36 cross-block comparisons, compute newer combined-rank sum, and
   reject any range, complement, or rank-sum identity failure.
8. Require `U_new>=24` or `U_new<=12` and map to exact contrarian package
   sides. Interior values consume the month flat.
9. Require both spreads in bounds, executable quotes, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
   notional mismatch no greater than 20%.
10. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no targets.
11. Submit XTI first and XNG second. Keep only one correctly directed,
    correctly registered, stop-protected position per slot; otherwise flatten
    every owned leg immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month before
   considering replacement risk, even if signal direction is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg immediately if the package is orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or
   outside the 20% notional mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, period, EA ID, slots, fixed-risk,
  news/Friday, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history, malformed
  synchronization, invalid month selection, ratio tie, invalid block/U
  invariant, interior signal, excessive spread, invalid quote, unavailable
  ATR, invalid stop/volume, or notional mismatch.
- Terminal global state plus deal history prevent restart retries. Tester
  initialization clears only a future/prior-run marker so historical runs
  remain deterministic.
- Runtime may not read futures-chain, inventory, volume, open-interest, file,
  API, forecast, trained-output, optimizer-result, or portfolio state.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve original hard stops; close both legs before monthly renewal or
  after forty elapsed calendar days.
- Run malformed-package repair before entry-only gates on every tick and
  flatten every owned leg when package validity fails.
- Restart recovery combines terminal-persistent month marker with owned
  positions and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xng_symbol` | XNGUSD.DWX | [XNGUSD.DWX] | exact companion and slot 1 |
| `strategy_endpoint_count` | 12 | [12] | synchronized ratio observations |
| `strategy_block_size` | 6 | [6] | fixed older and newer block size |
| `strategy_u_lower` | 12 | [12] | inclusive long-ratio boundary |
| `strategy_u_upper` | 24 | [24] | inclusive short-ratio boundary |
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

Every value is a locked singleton. Changing carrier, sample, split, tie rule,
threshold, direction, clock, risk, stop, balance, hold, spread, order sequence,
or retry policy requires a new card and full pipeline run.

## Source-Defined Rules And QM Interpretations

Villar-Joutz and Ramberg-Parsons supply the state-dependent weak oil/gas
relationship and adverse evidence. Mann, Whitney, and the pinned R Core files
supply the two-sample rank-sum and favorable-pair-count identity. QM fixes
synchronized month endpoints, the no-tie rule, fixed split, integer
boundaries, contrarian direction, continuous-CFD calendar, consumed attempt,
equal-notional fixed risk, spread caps, hard stops, atomicity, rollover, and
stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` and `XNGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and a terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Each leg receives half
the stop-risk budget before notional equalization. Both legs can gap, the weak
oil/gas relation can decouple, volume rounding creates imbalance, spread and
financing can dominate a low-frequency edge, and atomic repair can realize a
one-sided loss. Equal target notionals are market-neutral-style construction,
not proof of market or portfolio neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_RELATION_METHOD_AND_CARRIER_TRANSLATION_RISK | Complete government and peer-reviewed oil/gas evidence with adverse findings, named original Mann-Whitney record, and complete pinned R Core method files; exact trading rule untested. |
| R2 | PASS | Clock, synchronization, ratio order, fixed blocks, ties, U/rank-sum invariants, boundaries, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XTI/XNG D1 routes supply every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, prohibited external runtime feed, grid, or martingale. |

## Failure Modes And Kill Criteria

- Retire on zero trades, fewer than four completed packages in any full post-
  warm-up year, nonpositive governed economics, or downstream gate failure.
- Fail on current-month leakage, missing/duplicate month keys, nonlatest or
  unmatched pairs, wrong ratio orientation, stale endpoint,
  nonchronological data, endpoint count other than 12, accepted ratio tie,
  wrong split, missing cross-block comparison, invalid U complement or rank-
  sum identity, wrong threshold inclusion, or wrong package sides.
- Fail on same-month retry, non-atomic package, notional imbalance, missing
  hard stop, wrong risk mode, wrong spread ceiling, late entry, missed month-
  boundary exit, or nondeterminism.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, split, threshold, direction,
  carrier, risk, stop, balance, hold, spread, retry, or order sequence.

## Strategy Allowability Check

- [x] R1: PASS with relation/method/carrier translation risk. Complete
  government and peer-reviewed oil/gas evidence plus statistical-method
  lineage; no performance is imported.
- [x] R2: PASS. Synchronized endpoints, fixed blocks, strict ties, exact U
  identities, contrarian direction, attempt, aggregate risk, atomicity, and
  exits are fixed.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XTI
  and XNG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic timestamps, logarithms, comparisons, integer
  arithmetic, calendar, and ATR risk; no trained model or external feed.
- [x] Dedup: no exact match; declared fuzzy neighbors manually adjudicated by
  statistic, carrier/source, fixtures, and lifecycle.

## Framework Alignment

- no_trade: exact XTI/XNG/D1/EA/slots, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized endpoint reconstruction,
  fixed six/six blocks, all 36 comparisons, U/rank-sum identities, inclusive
  boundaries, contrarian sides, spread/quote/ATR/stop checks, equal-notional
  sizing, and atomic validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Validation Plan

1. Schema-lint canonical and EA card copies.
2. Independently reproduce all 924 block assignments, exact tail counts,
   inclusive thresholds, U complement, rank-sum identity, ties, symmetry,
   fixed nonduplicate paths, and exact contrarian sides.
3. Validate synchronization, twelve consecutive month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, logical label,
   grace, consume-first attempt order, and lifecycle repair.
4. Require strict zero-error/zero-warning compile, build guardrails, exact
   symbol scope, active registry identity, two active magic rows, and source-
   fresh EX5.
5. Enqueue exactly one logical-basket D1 Q02 row only if the fresh paced-fleet
   CPU/queue ceiling permits. Enqueue does not launch a manual tester.
6. Retire below the four-per-year floor or on nonpositive governed economics.

## Safety Boundary

This card authorizes governed magic allocation, one branch build, strict
compile/Q01, three D1 `RISK_FIXED` backtest setfiles (two registered legs and
one logical basket), and one paced non-live logical Q02 enqueue if CPU capacity
permits. It does not authorize a manual backtest; live, demo, shadow, stress,
or optimization setfile; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate mutation; portfolio admission; threshold change; correlation
waiver; or terminal process control.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial XTI/XNG fixed-block Mann-Whitney location-shift reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED; R1-R4 PASS | `decisions/2026-08-27_qm5_41178_xtixng_monthly_mann_whitney_location_shift_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
