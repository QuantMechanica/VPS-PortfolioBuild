---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026_S01
variant_id: SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026_S01
source_id: SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026
ea_id: QM5_41181
slug: xauxag-mkendall-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41181_xauxag-mkendall-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41181_xauxag_monthly_mann_kendall_rank_reversion_g0.md
source_approval: decisions/2026-08-27_xauxag_monthly_mann_kendall_rank_reversion_source_approval.md
source_author: "Karsten Schweikert; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_authors: "Karsten Schweikert; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_citation: "Schweikert (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; official CME Group Gold & Silver Ratio Spread research; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; governed pairwise-rank arithmetic packet."
source_citations:
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed parent packet"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence
  - type: official_exchange_carrier_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "official CME Group research preserved in governed parent packet"
    quality_tier: A_official
    role: intermarket_ratio_carrier_and_distinct_metal_drivers
  - type: peer_reviewed_structural_precedent
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read governed parent and pairwise-rank extraction"
    quality_tier: A
    role: monthly_commodity_path_persistence_and_rank_arithmetic_precedent_only
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG thirteen-month all-pairs ratio-rank reversion packet."
    location: "strategy-seeds/sources/SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_score_threshold_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-end-gold-minus-silver-log-ratio-all-seventy-eight-older-newer-pair-sign-score-absolute-14-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-pairwise-rank-trend]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/mann-kendall-pairwise-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, pairwise-rank-score, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41181_XAU_XAG_MKENDALL_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411810000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 5-8 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_STATISTIC_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Peer-reviewed gold/silver relationship evidence, official exchange carrier research, and complete governed pairwise-rank arithmetic; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, all 78 comparisons, integer score, threshold, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, comparisons, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; inclusive absolute integer score 14; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month gold/silver all-pairs ordinal ratio-reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify synchronization, ratio orientation, 78 comparisons, score count/range/parity, inclusive abs(S)>=14 contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, exact_seventy_eight_pair_count, no_tie_pair_score, score_range_parity, integer_score_threshold_14, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41181_xauxag_monthly_mann_kendall_rank_reversion_g0.md: R1 PASS with peer-reviewed gold/silver evidence, official exchange carrier research, and complete governed rank arithmetic; R2 PASS locks synchronized endpoints, all 78 comparisons, integer score, threshold, contrarian sides, attempt, risk, atomicity, and lifecycle; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. The canonical checker found no exact identity and one expected Spearman fuzzy neighbor; fixed rank fixtures resolve the functions as distinct, while carrier/direction/lifecycle separate WTI/XNG rank builds."
---

# QM5_41181 XAU/XAG Thirteen-Month Pairwise-Rank Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A single ratio endpoint
can be dominated by one move, while a z-score fits a center and scale. This
card instead asks whether newer completed monthly gold-minus-silver ratios
rank above or below older ratios across enough of all 78 pairs, then fades
that ordinal displacement.

Opposite equal-target-notional legs reduce some common outright-metal
direction and form a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove neutrality or
decorrelation. Q02 owns density/economics and unchanged Q09 owns overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026/source.md`,
SHA-256 `7C8612A5D47D24D25349521C7A8FEA00651735A3E6BD00B9A28D9AE75290C117`,
authorized by
`decisions/2026-08-27_xauxag_monthly_mann_kendall_rank_reversion_source_approval.md`
and finalized as `e44cdaa93` before card extraction.

Schweikert supplies related but state-dependent gold/silver evidence and
binding adverse evidence. CME supplies the intermarket carrier and distinct
metal drivers. The governed rank packet supplies exact all-pair arithmetic;
its outright WTI continuation result does not transfer. None tests this
threshold, contrarian package, continuous CFDs, or fixed-dollar contract.

No source return, alpha, probability, p-value, significance, density, profit
factor, drawdown, transaction cost, hedge ratio, neutrality, CFD
equivalence, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

The fail-closed checker scanned 4,680 registry identities, 1,331 cards, and
45 Strategy Wiki nodes. It found no exact match and surfaced only expected
fuzzy neighbor `QM5_41174_xauxag-mspearman-rv`. Receipt:
`artifacts/qm5_xauxag_mkendall_rv_preallocation_dedup_20260827.json`.

Manual review fixes distinct functions:

- `QM5_41174` squares time-rank displacement; this card gives every one of
  78 older/newer pairs exactly one sign vote.
- `[9,8,7,2,6,4,1,10,3,12,5,13,11]` is Spearman-only (`T=118`, `S=12`).
- `[1,6,13,3,7,4,12,8,10,5,9,2,11]` is this-rule-only (`S=14`, `T=80`).
- `QM5_20264` and `QM5_20267` follow the same arithmetic family on one
  outright WTI or XNG position. This card fades a synchronized two-metal
  ratio and owns an atomic equal-notional package.
- Z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint, fixed-pair,
  split-block, change-point, slope, and consensus baskets use other states.
- Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ALL78_PAIR_RANK_S14_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41181_XAU_XAG_MKENDALL_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `411810000` and `411810001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends.
- Hold: next broker-month boundary; forty days is stale repair.
- Expected pre-result cadence: five to eight packages/year; Q02 retires
  below five in any full post-warm-up year.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
r[i] = ln(XAU_close[i]) - ln(XAG_close[i])
require every r[i] pairwise distinct

S = sum(sign(r[j] - r[i])) for every 0 <= i < j <= 12
require exactly 78 comparisons, -78 <= S <= 78, and even S

SELL XAU / BUY XAG iff S >= 14
BUY XAU / SELL XAG iff S <= -14
FLAT otherwise
```

This is no-tie `tau=S/78`, used only as an ordinal dominance score. There is
no p-value or significance claim. Exact enumeration gives qualification
rate `0.4353804483839206` across all 13! rank paths (about 5.22/year under
random ordering only), a density fact rather than a market probability.

## Rules

- Exact EA ID, symbols, D1, slots, magics, risk/news/Friday contract, and all
  locked inputs are mandatory.
- Consume the broker month before every fallible entry gate.
- Use exactly thirteen immediately prior consecutive synchronized month
  keys and the latest exactly matched pair in each; current month excluded.
- Reject any exact ratio tie, wrong pair count, odd/out-of-range score, or
  threshold/side mismatch. Interior scores consume flat.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact ID, host, companion, D1 period, slots, fixed-risk framework
   inputs, and every singleton strategy input.
2. Process package repair and prior-month/stale exits before entry gates.
3. Require a genuine new broker month within 180 minutes of raw host bar
   open; persist `yyyymm` before history, signal, spread, quote, ATR, sizing,
   margin, or orders. Never retry that month.
4. Reject owned exposure or same-magic current-month entry deals.
5. Reconstruct thirteen consecutive completed synchronized month-end pairs;
   reject missing, duplicate, unmatched, current, nonchronological,
   nonpositive, nonfinite, or more-than-ten-day-stale newest data.
6. Compute thirteen log ratios and all 78 chronological comparisons. Reject
   an exact tie or invalid count/range/parity.
7. Require `S>=14` or `S<=-14`, mapping to exact contrarian package sides.
   An interior score consumes the month flat.
8. Require both spreads in bounds, executable quotes, completed-bar
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and target absolute-
   notional mismatch no greater than 20%.
9. Split aggregate stop risk equally, reduce only to equalize target
   notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and no targets.
10. Submit XAU first and XAG second. Keep only one correctly directed,
    registered, stop-protected position per slot; otherwise flatten all
    owned legs immediately.

## 5. Exit Rules

1. Framework kill switch and broker hard stops remain authoritative.
2. Close both legs on the first processed tick in a later broker month
   before considering replacement risk, even if the signal is unchanged.
3. Close after forty elapsed calendar days as stale repair.
4. Close every owned leg if the package is orphaned, duplicated, same-side,
   wrong-symbol, wrong-magic, wrong-direction, stopless, stale, or outside
   the 20% notional-mismatch tolerance.
5. No intramonth flip, target, trail, break-even, partial close, Friday
   close, news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbols, period, EA ID, slots, fixed-risk,
  news/Friday, or locked-input contract.
- Reject consumed attempt, owned exposure, same-month entry history,
  malformed synchronization, invalid month selection, ratio tie, invalid
  pair count/score invariant, interior score, excessive spread, invalid
  quote, unavailable ATR, invalid stop/volume, or notional mismatch.
- Runtime may not read futures-chain, volume, open-interest, file, API,
  forecast, trained-output, optimizer-result, or portfolio state.

## 7. Trade Management Rules

- Maintain either zero exposure or one valid opposite-side two-leg package
  and one consumed attempt per broker month.
- Preserve hard stops; close before monthly renewal or after forty days.
- Run malformed-package repair before entry gates on every tick.
- Restart recovery combines terminal-persistent month state with positions
  and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_xag_symbol` | XAGUSD.DWX | [XAGUSD.DWX] | exact companion and slot 1 |
| `strategy_endpoint_count` | 13 | [13] | synchronized ratio observations |
| `strategy_score_threshold` | 14 | [14] | inclusive absolute pair score |
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
| `strategy_deviation_points` | 20 | [20] | order deviation |

Every value is a locked singleton. Changing carrier, sample, score,
threshold, direction, clock, risk, stop, balance, hold, spread, order
sequence, or retry policy requires a new card and full pipeline run.

## Runtime Data Dependencies

Exact XAU/XAG native D1 timestamps and closes, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and one terminal-
persistent attempt marker. No external runtime dataset exists.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Each leg receives half
the stop-risk allowance before notional equalization. Both legs can gap,
the gold/silver relation can shift or break, silver volatility can dominate,
volume rounding creates imbalance, and spread/financing can overwhelm the
edge. Equal notionals are market-neutral-style, not proof of neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_STATISTIC_AND_CARRIER_TRANSLATION_RISK | Peer-reviewed relationship evidence, official exchange carrier research, complete governed rank arithmetic; conjunction untested. |
| R2 | PASS | Clock, synchronization, score, threshold, sides, attempt, risk, atomicity, lifecycle fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input. |
| R4 | PASS | Deterministic native arithmetic/state only; no trained method or external feed. |

## Failure Modes And Kill Criteria

- Retire on zero trades, fewer than five completed packages in any full
  post-warm-up year, nonpositive governed economics, or downstream failure.
- Fail on current-month leakage, missing/duplicate month keys, unmatched or
  stale pairs, wrong ratio orientation, nonchronology, accepted tie, pair
  count other than 78, odd/out-of-range score, wrong threshold/sides, retry,
  non-atomic package, notional imbalance, missing stop, wrong risk mode,
  missed month exit, or nondeterminism.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, score, threshold, direction,
  carrier, risk, stop, balance, hold, spread, retry, or order sequence.

## Strategy Allowability Check

- [x] R1: PASS with statistic/carrier translation risk.
- [x] R2: PASS. Endpoints, all-pair score, threshold, direction, attempt,
  aggregate risk, atomicity, and exits are fixed.
- [x] R3: PASS with synchronization/continuous-CFD basis risk.
- [x] R4: PASS. Deterministic prices, comparisons, integers, calendar, ATR,
  and execution; no trained model or external runtime feed.
- [x] Dedup: no exact identity; the expected Spearman fuzzy match is
  functionally resolved by fixed rank fixtures.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, risk/news/Friday gates.
- trade_entry: durable attempt, synchronized endpoints, all 78 comparisons,
  score invariants, threshold/sides, spread/ATR/stop checks, equal-notional
  sizing, and atomic submission.
- trade_management: package repair, prior-month exit, stale exit.
- trade_close: framework close helper per leg, hard stops, kill switch.

## Validation Plan

1. Schema-lint canonical and EA card copies.
2. Independently reproduce pair count, score range/parity, threshold sides,
   exact 13! density, monotone paths, flat interior, and separating fixtures.
3. Validate synchronization, consecutive months, year rollover, latest-pair
   selection, exclusion, staleness, grace, consume-first order, lifecycle.
4. Require zero-error/zero-warning compile, guardrails, exact symbol scope,
   active identity, two active magic rows, and source-fresh EX5.
5. Enqueue exactly one logical-basket D1 Q02 row only if the fresh CPU
   ceiling permits. Enqueue does not launch a manual tester.

## Safety Boundary

This card authorizes governed magic allocation, one branch build, strict
compile/Q01, three D1 `RISK_FIXED` backtest setfiles (two registered legs and
one logical basket), and one paced non-live logical Q02 enqueue below the CPU
ceiling. It does not authorize a manual backtest; live/demo/shadow/stress/
optimization setfile; AutoTrading; `T_Live`; deploy or live manifest;
portfolio-gate mutation; portfolio admission; threshold change; correlation
waiver; terminal control; or a second queue row.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial XAU/XAG pairwise-rank ratio-reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED; R1-R4 PASS | `decisions/2026-08-27_qm5_41181_xauxag_monthly_mann_kendall_rank_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
