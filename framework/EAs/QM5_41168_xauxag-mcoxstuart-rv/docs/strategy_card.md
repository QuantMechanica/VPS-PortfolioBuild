---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026_S01
variant_id: SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026_S01
source_id: SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026
ea_id: QM5_41168
slug: xauxag-mcoxstuart-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41168_xauxag-mcoxstuart-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41168_xauxag_monthly_cox_stuart_paired_sign_reversion_g0.md
source_approval: decisions/2026-08-26_xauxag_monthly_cox_stuart_paired_sign_reversion_source_approval.md
source_author: "Karsten Schweikert; D. R. Cox; Alan Stuart; CME Group"
source_authors: "Karsten Schweikert; D. R. Cox; Alan Stuart; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Cox and Stuart (1955), Biometrika 42(1-2), 80-95, DOI 10.1093/biomet/42.1-2.80; NIST Dataplot Cox Stuart Test; official CME Group Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed complete-read lineage under strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "complete governed lineage under strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_distinct_metal_drivers
  - type: peer_reviewed_statistical_method_record
    citation: "Cox, D. R., and Stuart, A. (1955). Some Quick Sign Tests for Trend in Location and Dispersion. Biometrika 42(1-2), 80-95."
    location: "DOI 10.1093/biomet/42.1-2.80; official publisher record; body paywalled and not claimed completely read"
    quality_tier: A_record_only
    role: paired_sign_trend_lineage
  - type: official_statistical_implementation_reference
    citation: "NIST Dataplot, Cox Stuart Test."
    location: "complete official method record preserved in strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md"
    quality_tier: official_method_documentation
    role: exact_even_sample_pairing_and_sign_count
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG fourteen-month Cox-Stuart paired-sign source packet."
    location: "strategy-seeds/sources/SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_threshold_synchronization_contrarian_sides_risk_and_lifecycle
strategy_mechanic: synchronized-fourteen-completed-month-end-gold-minus-silver-log-ratio-cox-stuart-seven-lag-seven-paired-sign-five-of-seven-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/nonparametric-paired-sign-trend]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-end-log-ratio]]"
  - "[[indicators/cox-stuart-paired-sign-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, cox-stuart, paired-sign, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41168_XAU_XAG_MCOXSTUART_RV_D1
symbol: QM5_41168_XAU_XAG_MCOXSTUART_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411680000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed XAU/XAG packages per full post-warm-up year after fourteen synchronized completed month ends and a strict 5-of-7 paired-sign direction; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a fourteen-completed-month gold/silver paired-sign reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, seven lag-seven pairs, strict tie rejection, five-sign contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, fourteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, exact_seven_lag_seven_pairs, strict_no_tie_rule, five_of_seven_contrarian_direction, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41168_xauxag_monthly_cox_stuart_paired_sign_reversion_g0.md: R1 PASS with peer-reviewed gold/silver relationship evidence, official exchange carrier research, official Cox-Stuart record, and complete NIST pairing description; R2 PASS locks synchronized endpoints, seven fixed pairs, ties, 5-of-7 contrarian sides, attempt, aggregate risk, stops, atomicity, and repair; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN and two fixed rank vectors separate the statistic from endpoint, Mann-Kendall, quarterly-vote, and robust-slope neighbors."
---

# QM5_41168 XAU/XAG Fourteen-Month Cox-Stuart Paired-Sign Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A single ratio endpoint
can be dominated by one move, while a slope or all-pairs rank statistic gives
many overlapping comparisons a vote. This card instead asks whether at least
five of seven fixed, disjoint older/newer month-end ratio pairs point in one
direction, then fades that relative displacement. The statistic discards
magnitude after each comparison.

Opposite equal-target-notional legs are designed to reduce common outright-
metal direction and form a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026/source.md`,
SHA-256 `3A33AE04B3326D763E0E851DFA66049B367D216D645E1E32FD1411B2E92759EB`,
authorized by
`decisions/2026-08-26_xauxag_monthly_cox_stuart_paired_sign_reversion_source_approval.md`
and committed at `d5e5a0c79` before card extraction.

Schweikert supplies a related but state-dependent gold/silver hypothesis and
binding adverse evidence. CME supplies the intermarket carrier and distinct
metal drivers. Cox and Stuart supply peer-reviewed paired-sign trend lineage;
the complete official NIST record supplies exact even-sample half-to-half
pairing. The original Cox-Stuart body is paywalled and is not represented as
completely read. None tests this synchronized XAU/XAG 5-of-7 contrarian
package, continuous CFDs, or fixed-dollar execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, statistical
significance, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,667 registry
identities, 1,318 cards, and 45 Strategy Wiki nodes. It found no exact or
fuzzy match. The receipt is
`artifacts/qm5_xauxag_mcoxstuart_rv_preallocation_dedup_20260826.json`,
SHA-256 `B89423A13EFCE50F40FE8977561924FADA69281C8ACAFB475AEC6B8D701BE594`.

Manual review fixes a new statistic and carrier conjunction:

- `QM5_41167_wti-coxstuart-tr` uses the same fixed comparisons on one
  outright WTI series, follows the sign, and owns one position. This card
  constructs a synchronized gold-minus-silver ratio, fades the sign, and owns
  an atomic equal-notional package.
- `QM5_41157`, `QM5_41160`, `QM5_41164`, and `QM5_41166` retain ratio-path
  magnitude through robust-slope geometry. This card discards magnitude after
  seven disjoint comparisons and fits no slope.
- Endpoint, Mann-Kendall, quarterly-vote, within-month-half, sign-breadth,
  path, sequence, location, OLS, CADF, quantile, MAD, and z-score cards observe
  different state objects.
- On `[0,8,3,7,10,2,4,6,13,11,12,9,5,1]*0.01` log-ratio ranks, this card
  shorts the ratio at 5/7 while the latest-thirteen Mann-Kendall score is `2`,
  the twelve-month endpoint falls, and quarterly blocks split 2/2.
- On `[12,4,0,3,7,8,13,2,5,1,9,6,10,11]*0.01`, this card is flat at 4/3
  while the latest-thirteen Mann-Kendall score is `30`, the twelve-month
  endpoint rises, and three quarterly blocks rise.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not monthly paired-metal sign reversion.

Verdict:
`CLEAN_XAUXAG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41168_XAU_XAG_MCOXSTUART_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `411680000` and `411680001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: fourteen consecutive synchronized completed broker-month ends;
  current month excluded.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: five to eight packages per full post-warm-up
  year; retire below five.

## Formula

For chronological synchronized completed-month close pairs `i=0..13`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])

for i = 0..6:
  d[i] = s[i+7] - s[i]
  require finite(d[i]) and d[i] != 0

positive = count(d[i] > 0)
negative = count(d[i] < 0)
require positive + negative == 7

SELL XAU / BUY XAG iff positive >= 5
BUY XAU / SELL XAG iff negative >= 5
FLAT otherwise
```

Every endpoint appears in exactly one comparison and every pair spans seven
month indexes. Difference magnitude, winning count beyond five, and any
derived probability never change risk.

The 5-of-7 boundary is fixed before market testing. Under a fair independent-
sign thought experiment only, 58/128 sign vectors qualify, or 45.3125%, for
5.4375 expected monthly decisions/year. This is not an independence,
frequency, significance, or profitability claim.

## Rules

- `ea_id=41168`, exact XAU/XAG symbols, D1, slots 0/1, magics `411680000` /
  `411680001`.
- Consume the normalized broker month before every fallible entry gate.
- Use exactly fourteen immediately prior consecutive completed month keys and
  the latest exactly timestamp-matched pair in each. The newest pair must be
  no more than ten calendar days stale.
- Compute exactly pairs `(0,7)` through `(6,13)`. No alternate pairing,
  skipped pair, tie deletion, dynamic threshold, magnitude weight, fitted
  center, or fallback signal is permitted.
- At least five positive signs map to short ratio; at least five negative
  signs map to long ratio. A tie anywhere or 4/3 split is flat.
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
5. Reject owned exposure or same-magic entry deals already recorded in the
   current broker month.
6. Reconstruct fourteen consecutive completed synchronized month-end pairs;
   reject missing, duplicate, unmatched, current-month, nonchronological,
   nonpositive, nonfinite, or stale data.
7. Compute fourteen log ratios and exactly seven fixed paired differences.
   Reject any zero, nonfinite value, wrong count, wrong index, or endpoint
   reuse.
8. Require at least five strict signs in one direction and map the result to
   the exact contrarian package sides. A 4/3 split consumes the month flat.
9. Require both spreads in bounds, executable quotes, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
   notional mismatch no greater than 20%.
10. Split aggregate stop risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no targets.
11. Submit XAU first and XAG second. Keep only one correctly directed,
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
- Reject consumed attempt, owned exposure, same-month entry history, malformed
  synchronization, invalid month selection, invalid pair, tie, 4/3 split,
  excessive spread, invalid quote, unavailable ATR, invalid stop/volume, or
  notional mismatch.
- Terminal global state plus deal history prevent restart retries. Tester
  initialization clears only a future/prior-run marker so historical runs
  remain deterministic.
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
| `strategy_endpoint_count` | 14 | [14] | synchronized ratio observations |
| `strategy_pair_count` | 7 | [7] | fixed half-sample pairs |
| `strategy_signs_required` | 5 | [5] | strict directional count |
| `strategy_history_bars_d1` | 900 | [900] | bounded pair reconstruction |
| `strategy_entry_window_minutes` | 180 | [180] | new-month grace |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | package balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | stale guard |
| `strategy_xau_max_spread_points` | 1500 | [1500] | XAU spread ceiling |
| `strategy_xag_max_spread_points` | 500 | [500] | XAG spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Every value is a locked singleton. Changing carrier, sample, pairing,
threshold, direction, clock, risk, stop, balance, hold, spread, order sequence,
or retry policy requires a new card and full pipeline run.

## Source-Defined Rules And QM Interpretations

Schweikert and CME supply the state-dependent gold/silver relation and
intermarket carrier. Cox-Stuart and NIST supply ordered half-sample pairing
and sign-count lineage. QM fixes fourteen synchronized endpoints, the 5-of-7
density boundary, contrarian direction, continuous-CFD calendar, consumed
attempt, equal-notional fixed risk, spread caps, hard stops, atomicity,
rollover, and stale repair.

## Runtime Data Dependencies

Exact `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and a terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Each leg receives half
the stop-risk budget before notional equalization. Both legs can gap, a
relative trend can persist, volume rounding creates imbalance, spread and
financing can dominate a low-frequency edge, atomic repair can realize one-
sided loss, and the basket can overlap the directional XAU sleeve. Equal
target notionals are market-neutral-style construction, not proof of market
or portfolio neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Peer-reviewed gold/silver evidence, official exchange carrier research, official peer-reviewed Cox-Stuart record, and complete NIST pairing documentation; exact trading rule untested. |
| R2 | PASS | Clock, synchronization, ratio order, seven pairs, ties, count, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external feed, grid, or martingale. |

## Failure Modes And Kill Criteria

- Retire on zero trades, fewer than five completed packages in any full post-
  warm-up year, nonpositive governed economics, or downstream gate failure.
- Fail on current-month leakage, missing/duplicate month keys, nonlatest or
  unmatched pairs, wrong ratio orientation, stale endpoint, nonchronological
  data, endpoint count other than 14, pair count other than 7, wrong pair
  indexes, endpoint reuse, nonfinite log ratio/difference, accepted tie, wrong
  sign count, entry on a 4/3 split, or wrong package sides.
- Fail on same-month retry, non-atomic package, notional imbalance, missing
  hard stop, wrong risk mode, wrong spread ceiling, late entry, missed month-
  boundary exit, or nondeterminism.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, pairing, threshold, direction,
  carrier, risk, stop, balance, hold, spread, retry, or order sequence.

## Strategy Allowability Check

- [x] R1: PASS with method/carrier translation risk. Peer-reviewed
  gold/silver and statistical-method lineage plus official exchange carrier
  evidence; no performance is imported.
- [x] R2: PASS. Synchronized endpoints, seven pairs, strict count,
  contrarian direction, attempt, aggregate risk, atomicity, and exits are
  fixed.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XAU
  and XAG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic timestamps, logarithms, comparisons, calendar,
  and ATR risk arithmetic; no trained model, banned signal indicator,
  external feed, grid, or martingale.
- [x] Dedup: canonical checker CLEAN; carrier/direction/lifecycle and two fixed
  rank-vector counterexamples separate the candidate from nearby families.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized endpoint reconstruction,
  seven exact paired differences, tie rejection, 5-of-7 contrarian sides,
  spread/quote/ATR/stop checks, equal-notional sizing, and atomic package
  validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Validation Plan

1. Schema-lint canonical and EA card copies.
2. Independently reproduce all seven pair indexes, ties, counts, both
   separation vectors, monotone positive/negative paths, and exact contrarian
   sides.
3. Validate synchronization, fourteen consecutive month keys, year rollover,
   latest-pair selection, current-month exclusion, staleness, label
   conventions, grace, consume-first attempt order, and lifecycle repair.
4. Require strict zero-error/zero-warning compile, build guardrails, exact
   symbol scope, active registry identity, two active magic rows, and source-
   fresh EX5.
5. Enqueue exactly one logical-basket D1 Q02 row only if the fresh paced-fleet
   CPU/queue ceiling permits. Enqueue does not launch a manual tester.
6. Retire below the five-per-year floor or on nonpositive governed economics.

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
| v1 | 2026-08-26 | initial XAU/XAG Cox-Stuart paired-sign ratio-reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-26 | APPROVED; R1-R4 PASS | `decisions/2026-08-26_qm5_41168_xauxag_monthly_cox_stuart_paired_sign_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
