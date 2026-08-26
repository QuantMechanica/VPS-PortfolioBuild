---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026_S01
variant_id: SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026_S01
source_id: SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026
ea_id: QM5_41166
slug: xauxag-mrobust3-agree-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41166_xauxag-mrobust3-agree-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41166_xauxag_monthly_robust_three_consensus_reversion_g0.md
source_approval: decisions/2026-08-26_xauxag_monthly_robust_three_consensus_reversion_source_approval.md
source_author: "Karsten Schweikert; Roger Koenker; Gilbert Bassett Jr.; Andrew F. Siegel; CME Group"
source_authors: "Karsten Schweikert; Roger Koenker; Gilbert Bassett Jr.; Andrew F. Siegel; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Siegel (1982), Biometrika 69(1), 242-244, DOI 10.1093/biomet/69.1.242; official CME Group gold/silver ratio-spread lineage; governed exact Theil-Sen and Koenker-Bassett LAD arithmetic."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete governed packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation_check_loss_lineage_and_adverse_evidence
  - type: peer_reviewed_statistical_method_record
    citation: "Siegel, A. F. (1982). Robust Regression Using Repeated Medians. Biometrika 69(1), 242-244."
    location: "DOI 10.1093/biomet/69.1.242; official Oxford Academic record preserved in strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md"
    quality_tier: A
    role: nested_repeated_median_regression_lineage
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "complete governed lineage in strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_driver_difference
  - type: governed_method_precedent
    citation: "QuantMechanica bounded thirteen-completed-month XAU/XAG Theil-Sen, LAD, and repeated-median source packets."
    location: "strategy-seeds/sources/SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_three_estimator_arithmetic_synchronization_ratio_orientation_risk_and_lifecycle
strategy_mechanic: synchronized-thirteen-completed-month-end-gold-minus-silver-log-ratio-theilsen-lad-repeated-median-unanimous-strict-sign-consensus-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/robust-slope-consensus]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-end-ratio-robust-three-consensus]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, robust-consensus, theil-sen, least-absolute-deviation, repeated-median, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1
symbol: QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411660000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-12 completed XAU/XAG packages per full post-warm-up year after thirteen-month formation, exact synchronization, strict estimator agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ENSEMBLE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a thirteen-completed-month gold/silver robust-consensus reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify synchronization, ratio orientation, all 78 pair slopes, exact Theil-Sen, every LAD residual profile/objective/tie, every repeated-median pivot group, strict unanimous signs, contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, exact_78_pair_slopes, theilsen_indexes_38_39, lad_median_residual_intercept, lad_absolute_loss_objective, equality_guard_1e_12, exact_thirteen_repeated_median_pivots, exact_twelve_slopes_per_pivot, strict_three_way_sign_agreement, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41166_xauxag_monthly_robust_three_consensus_reversion_g0.md: R1 PASS with explicit ensemble-translation risk using peer-reviewed gold/silver relation, official exchange carrier, complete-read peer-reviewed median-regression lineage, and peer-reviewed repeated-median lineage; R2 PASS locks synchronized endpoints, all three estimators, unanimous signs, attempt, aggregate risk, stops, atomicity, and repair; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup found the expected WTI-consensus fuzzy neighbor, manually cleared by carrier/direction/lifecycle differences and two fixed estimator-disagreement vectors."
---

# QM5_41166 XAU/XAG Thirteen-Month Robust-Three Consensus Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A relative move whose
direction depends on one robust estimator can be geometry-sensitive. This
card fades the gold-minus-silver ratio only when exact Theil-Sen, LAD, and
Siegel repeated-median slopes over the same thirteen synchronized completed
month ends have one unanimous strict sign. It tests whether broadly
estimator-stable relative displacement reverts without fitting to PnL or
scaling risk by signal magnitude.

Opposite equal-target-notional legs are designed to reduce common outright-
metal direction and form a market-neutral-style stream different from the
certified directional XAU, SP500, NDX, and XNG book. They do not prove dollar,
beta, volatility, factor, market, or portfolio neutrality. Q02 owns density
and baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-THEILSEN-KOENKER-SIEGEL-CME-XAUXAG-MROBUST3-AGREE-RV-2026/source.md`,
SHA-256
`3CB443F1A19E89E39F755B5A94C5E1BE65509E0184FC5F59A9A1EA0DAA5468FD`,
authorized by
`decisions/2026-08-26_xauxag_monthly_robust_three_consensus_reversion_source_approval.md`
and committed at `8978302cb` before card extraction.

Schweikert supplies a related but state-dependent gold/silver hypothesis and
binding adverse evidence. The governed CME record supplies the intermarket
carrier and distinct metal drivers. The three governed method packets supply
complete exact Theil-Sen, LAD, and repeated-median arithmetic. None tests
their unanimous paired monthly ratio fade, Darwinex continuous CFDs,
equal-notional fixed-dollar ATR risk, or the QM book.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, estimator superiority, CFD
equivalence, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,665 registry
identities, 1,316 cards, and 45 Strategy Wiki nodes. It found no exact match
and one expected fuzzy match to `QM5_41165_wti-mrobust3-agree-tr` at score
`0.7142857142857143`. The receipt is
`artifacts/qm5_xauxag_mrobust3_agree_rv_preallocation_dedup_20260826.json`,
SHA-256
`2B9557DF89DA97C26E08BFF67DDAAD42A93C7D8E931CF6BEFBC3DDCAC7C5C6BB`.

Manual review finds a new conjunction and carrier:

- `QM5_41157`, `QM5_41160`, and `QM5_41164` trade Theil-Sen, LAD, and
  repeated median separately. This card computes all three complete
  estimators and trades only their strict intersection.
- On `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, the estimators
  are `+0.00155555555555556`, `+0.00375`, and `-0.0045`; all constituents
  trade while this card is flat.
- On `[0,.02,0,0,-.06,-.09,-.05,-.05,.03,.06,-.02,-.03,.05]`, LAD is
  `-0.002` while Theil-Sen and repeated median are positive; this card is
  again flat.
- Positive and negative exact linear paths produce unanimous signs and
  executable opposite basket directions.
- `QM5_41165` uses outright WTI log prices, follows the sign, and owns one
  crude-oil leg. This card uses a synchronized gold-minus-silver path, fades
  the sign, and owns an atomic equal-notional two-leg package.
- Ratio z-score, OLS, CADF, variance-ratio, return-sign, path, flow,
  volatility, and calendar systems estimate different state objects.

Verdict: `CLEAN_AFTER_EXPECTED_WTI_CONSENSUS_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41166_XAU_XAG_MROBUST3_AGREE_RV_D1` on the XAU
  host.
- Timeframe: D1; intended magics `411660000` and `411660001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends;
  current month excluded.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: five to twelve packages per full post-warm-up
  year; retire below five.

## Formula

At the start of month `t`, let `s[0]..s[12]` be synchronized completed-month
gold-minus-silver log ratios from months `t-13..t-1`, oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])

B = sorted((s[j]-s[i])/(j-i) for every 0 <= i < j <= 12)
require len(B) == 78
theilsen = (B[38] + B[39]) / 2

for candidate b in the 78 unsorted pair slopes:
  A = sorted(s[i] - b*i for i=0..12)
  a = A[6]
  loss[b] = sum(abs(s[i] - a - b*i) for i=0..12 in chronological order)
M = sorted(b for every candidate with abs(loss[b]-min(loss)) <= 1e-12)
lad = ordinary median(M)

for pivot i=0..12:
  P = twelve forward-oriented slopes joining i to every other endpoint
  pivot_median[i] = (sorted(P)[5] + sorted(P)[6]) / 2
repeated_median = sorted(pivot_median)[6]

all three > 0 => SELL XAU, BUY XAG
all three < 0 => BUY XAU, SELL XAG
otherwise     => FLAT
```

All ratios, slopes, residuals, objectives, medians, and intermediate sums
must be finite. Slope magnitude, LAD loss, intercept, minimizer count, and
consensus strength never change risk.

## Rules

These are the complete authorized baseline:

- `ea_id=41166`, exact XAU/XAG symbols, D1, slots 0/1, magics `411660000` /
  `411660001`.
- Consume the normalized broker month before every fallible entry gate.
- Use exactly thirteen immediately prior consecutive completed month keys and
  the latest exactly timestamp-matched pair in each. The newest pair must be
  no more than ten calendar days stale.
- Compute every complete estimator. No fallback, majority vote, weighting,
  magnitude threshold, fitted scale, OLS, endpoint, z-score, volatility,
  seasonal, external, or prior-result gate is allowed.
- Only one unanimous strict sign can open a contrarian package.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, host, companion, D1 period, slots, risk mode,
   framework inputs, and all locked strategy inputs.
2. Process package repair and prior-month/stale exits before entry-only gates.
3. Require a genuine new broker month no later than 180 elapsed minutes after
   the raw host D1 bar open.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No flat, rejected, partial, failed,
   stopped, or restarted outcome retries that month.
5. Reconstruct thirteen consecutive completed synchronized month-end pairs;
   reject missing, duplicate, unmatched, current-month, nonchronological,
   nonpositive, nonfinite, or stale data.
6. Compute thirteen log ratios, all 78 pair slopes, and exact Theil-Sen.
7. Profile all 78 LAD candidates using thirteen residuals, sorted index 6
   intercept, chronological absolute loss, exact `1e-12` tie set, and the
   ordinary median of minimizing slopes.
8. Compute thirteen repeated-median pivot groups with exactly twelve
   forward-oriented slopes per group, inner indexes 5/6, and outer index 6.
9. Require all three slopes strictly positive or all strictly negative. Any
   zero or disagreement consumes the month flat.
10. Require both spreads in bounds, executable quotes, completed-bar
    `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
    notional mismatch no greater than 20%.
11. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no
    targets.
12. Submit XAU first and XAG second. Keep only one correctly directed,
    correctly registered, stop-protected position per slot; otherwise flatten
    every owned leg immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month before
   considering replacement risk, even if direction is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg immediately if the package is orphaned, duplicated,
   same-side, wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or
   outside the 20% notional mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbols, period, EA ID, slots, fixed-risk,
  news/Friday, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history,
  malformed synchronization, invalid month selection, any invalid estimator,
  nonunanimous sign, excessive spread, invalid quote, unavailable ATR,
  invalid stop/volume, or notional mismatch.
- Terminal global state plus deal history prevent restart retries. Tester
  initialization clears a future/prior-run marker so historical runs remain
  deterministic.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, forecast, trained output, optimizer result, or
  portfolio state.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve original hard stops; close both legs before monthly renewal or
  after forty elapsed calendar days.
- Run malformed-package repair before entry-only gates on every tick and
  flatten every owned leg when package validity fails.
- Restart recovery combines the terminal-persistent month marker with owned
  positions and same-month deal history; no restart can create a second
  attempt.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xag_symbol` | XAGUSD.DWX | [XAGUSD.DWX] | exact companion and slot 1 |
| `strategy_month_end_count` | 13 | [13] | synchronized ratio observations |
| `strategy_history_bars_d1` | 500 | [500] | bounded pair reconstruction |
| `strategy_entry_window_minutes` | 180 | [180] | new-month grace |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest endpoint age ceiling |
| `strategy_loss_tie_tolerance` | 1e-12 | [1e-12] | LAD equality convention |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | package balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | stale guard |
| `strategy_xau_max_spread_points` | 1500 | [1500] | XAU spread ceiling |
| `strategy_xag_max_spread_points` | 500 | [500] | XAG spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Every value is a locked singleton. Changing carrier, sample, estimator,
consensus, direction, clock, risk, stop, balance, hold, spread, order sequence,
or retry policy requires a new card and full pipeline run.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Each leg receives half
the stop-risk budget before notional equalization. Both legs can gap, a
relative trend can persist, volume rounding creates imbalance, spread and
financing can dominate a low-frequency edge, atomic repair can realize
one-sided loss, and the basket can overlap the certified XAU sleeve. Equal
target notionals are market-neutral-style construction, not proof of market
or portfolio neutrality.

## Failure Modes And Kill Criteria

- Retire on zero trades, fewer than five completed packages in any full post-
  warm-up year, nonpositive governed economics, or downstream gate failure.
- Fail on current-month leakage, missing/duplicate month keys, nonlatest or
  unmatched pairs, wrong ratio orientation, stale endpoint, nonchronological
  data, pair count other than 78, wrong Theil-Sen indexes, residual count
  other than 13, wrong LAD intercept/objective/tie/median, pivot count other
  than 13, pivot-slope count other than 12, wrong nested-median indexes,
  skipped estimator, nonunanimous trade, wrong side, retry, non-atomic
  package, risk-mode breach, stop defect, missed exit, or nondeterminism.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, estimator, tie convention,
  consensus, direction, carrier, risk, stop, balance, hold, spread, retry, or
  order sequence.

## Strategy Allowability Check

- [x] R1: PASS with ensemble-translation risk. Peer-reviewed gold/silver and
  statistical-method lineage plus official exchange carrier evidence; no
  method performance is imported.
- [x] R2: PASS. Synchronized endpoints, all three estimators, strict
  consensus, direction, attempt, aggregate risk, atomicity, and exits are
  fixed.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XAU
  and XAG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic logarithms, sorting, absolute arithmetic,
  calendar, and ATR risk arithmetic; no trained model, banned signal
  indicator, external feed, grid, or martingale.
- [x] Dedup: one expected WTI-consensus fuzzy neighbor is cleared by carrier,
  direction, lifecycle, and fixed disagreement-vector evidence.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized endpoint reconstruction,
  all three exact estimators, strict consensus, spread/quote/ATR/stop checks,
  equal-notional sizing, and atomic package validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Validation Plan

1. Schema-lint canonical and EA card copies.
2. Independently reproduce all pair slopes, Theil-Sen indexes, every LAD
   residual median/objective/tie, every repeated-median pivot group, and
   strict three-way signs.
3. Prove both disagreement vectors consume flat and exact positive/negative
   lines open the correct contrarian packages.
4. Validate synchronization, thirteen consecutive month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, label
   conventions, grace, consume-first attempt order, and lifecycle repair.
5. Require strict zero-error/zero-warning compile, build guardrails, exact
   symbol scope, active registry identity, two active magic rows, and source-
   fresh EX5.
6. Enqueue exactly one logical-basket D1 Q02 row only if the fresh paced-fleet
   CPU/queue ceiling permits. Enqueue does not launch a manual tester.

## Safety Boundary

This card authorizes governed magic allocation, one branch build, strict
compile/Q01, three D1 `RISK_FIXED` backtest setfiles (two registered legs and
one logical basket), and one paced non-live logical Q02 enqueue if CPU
capacity permits. It does not authorize a manual backtest; live, demo, shadow,
stress, or optimization setfile; AutoTrading; `T_Live`; deploy or live
manifest; portfolio-gate mutation; portfolio admission; threshold change; or
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-26 | initial XAU/XAG robust-three consensus ratio-reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-26 | APPROVED; R1-R4 PASS | `decisions/2026-08-26_qm5_41166_xauxag_monthly_robust_three_consensus_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
