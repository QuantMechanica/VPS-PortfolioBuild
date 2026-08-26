---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026_S01
variant_id: SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026_S01
source_id: SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026
ea_id: QM5_41174
slug: xauxag-mspearman-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41174_xauxag-mspearman-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41174_xauxag_monthly_spearman_rank_reversion_g0.md
source_approval: decisions/2026-08-27_xauxag_monthly_spearman_rank_reversion_source_approval.md
source_author: "Karsten Schweikert; C. Spearman; R Core Team; CME Group"
source_authors: "Karsten Schweikert; C. Spearman; R Core Team; CME Group"
source_citation: "Schweikert (2018), Are gold and silver cointegrated?, Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; official CME Group Gold & Silver Ratio Spread research; Spearman (1904), The Proof and Measurement of Association between Two Things, The American Journal of Psychology 15(1), DOI 10.2307/1412159; R Core Team stats::cor source and manual."
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
  - type: peer_reviewed_statistical_method_record
    citation: "Spearman, C. (1904). The Proof and Measurement of Association between Two Things. The American Journal of Psychology 15(1)."
    location: "DOI 10.2307/1412159; metadata record; body not claimed completely read"
    quality_tier: A_record_only
    role: rank_correlation_lineage
  - type: public_method_implementation
    citation: "R Core Team, stats::cor source and manual."
    location: "public wch/r-source mirror commit 7344a2d9d96b3c2b997535d3abc8c3a44af16e82; complete relevant files in governed parent receipt"
    quality_tier: A_method_implementation
    role: exact_rank_transform_then_correlation_definition
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG thirteen-month Spearman ratio-rank reversion packet."
    location: "strategy-seeds/sources/SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_sample_threshold_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xauxag-thirteen-synchronized-completed-month-end-gold-minus-silver-log-ratio-spearman-rank-versus-time-rank-exact-integer-score-absolute-104-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/nonparametric-rank-association]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/synchronized-completed-month-log-ratio]]"
  - "[[indicators/spearman-time-ratio-rank-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, spearman-rank-association, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41174_XAU_XAG_MSPEARMAN_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411740000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 4-7 completed XAU/XAG packages per full post-warm-up year after thirteen synchronized completed month ends; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 4
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK
r1_reasoning: "Peer-reviewed gold/silver relationship evidence, official exchange carrier research, named original Spearman record, and complete pinned R Core method files; the exact contrarian basket remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, synchronized endpoints, strict ranks, displacement score, integer threshold, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization, roll, and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, strict ranks, integer arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 synchronized endpoints; abs integer score 104; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
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
review_focus: "Falsify a thirteen-completed-month gold/silver Spearman time-rank ratio-reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization, ratio orientation, strict rank permutation, D/T identities, abs(T)>=104 contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, strict_no_tie_rank_permutation, spearman_displacement_identity, integer_score_threshold_104, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41174_xauxag_monthly_spearman_rank_reversion_g0.md: R1 PASS with peer-reviewed gold/silver evidence, official exchange carrier research, named Spearman record, and complete pinned R Core method files; R2 PASS locks synchronized endpoints, strict ranks, integer score, threshold, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup was CLEAN and fixed rank fixtures separate the statistic from Mann-Kendall while carrier/direction/lifecycle separate it from the WTI Spearman build."
---

# QM5_41174 XAU/XAG Thirteen-Month Spearman Ratio-Rank Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A single ratio endpoint
can be dominated by one move, while a rolling z-score imposes a fitted center
and scale. This card instead asks whether the strict rank ordering of thirteen
synchronized completed month-end gold-minus-silver log ratios has moved far
enough with calendar order, then fades that relative displacement.

Opposite equal-target-notional legs are designed to reduce common outright-
metal direction and form a market-neutral-style stream different from the
directional XAU, SP500, NDX, and XNG book. They do not prove dollar, beta,
volatility, factor, market, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source ID resolves to
`strategy-seeds/sources/SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026/source.md`,
SHA-256 `FBE965262B3FC03F1EEB3BBDE4151A22A1A81F52DB9220BCBFB4BAB7F4B5CE4E`,
authorized by
`decisions/2026-08-27_xauxag_monthly_spearman_rank_reversion_source_approval.md`
and committed as `6d967cde8` before card extraction.

Schweikert supplies related but state-dependent gold/silver evidence and
binding adverse evidence. CME supplies the intermarket carrier and distinct
metal drivers. Spearman supplies named peer-reviewed rank-correlation
lineage; the complete pinned R Core files define the operative statistic as
ordinary correlation after rank-transforming both inputs. The original 1904
body is not represented as completely read. None tests this synchronized
XAU/XAG threshold, contrarian package, continuous CFDs, or fixed-dollar
execution contract.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, statistical
significance, decorrelation, or portfolio-correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,673 registry
identities, 1,324 cards, and 45 Strategy Wiki nodes. It found no exact or
fuzzy match. The receipt is
`artifacts/qm5_xauxag_mspearman_rv_preallocation_dedup_20260827.json`,
SHA-256 `7C6C2348095D17941118509E84F3E8A5F6C62FCFD684875AC7176397F40469B8`.

Manual review fixes a new statistic and carrier conjunction:

- `QM5_41173_wti-mspearman-tr` follows the same rank score on one outright
  WTI position. This card constructs a synchronized gold-minus-silver ratio,
  fades the score, and owns an atomic equal-notional package.
- `QM5_41168_xauxag-mcoxstuart-rv` compares seven fixed lag-seven pairs among
  fourteen ratios. This card uses thirteen ratios and every exact calendar-
  rank displacement.
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  quarterly-vote, Theil-Sen, LAD, repeated-median, and robust-consensus cards
  observe different state objects.
- `[3,2,10,1,4,12,11,8,7,9,6,5,13]` gives `T=170` and a short-ratio action
  here while the latest-thirteen Mann-Kendall score is flat at `S=20`.
  `[13,1,4,12,5,2,3,6,7,8,9,10,11]` gives `T=98` and flat here while
  Mann-Kendall reaches `S=28`.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a monthly paired-metal rank basket.

Verdict:
`CLEAN_XAUXAG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41174_XAU_XAG_MSPEARMAN_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `411740000` and `411740001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends;
  current month excluded.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected pre-result cadence: four to seven packages per full post-warm-up
  year; retire below four.

## Formula

For chronological synchronized completed-month close pairs `i=0..12`:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])
require every s[i] pairwise distinct

R[i] = strict rank of s[i] from 1 to 13
D = sum((R[i] - (i + 1))^2)
T = 364 - D

require sorted(R) = [1,2,...,13]
require 0 <= D <= 728 and -364 <= T <= 364
require D and T even

SELL XAU / BUY XAG iff T >= 104
BUY XAU / SELL XAG iff T <= -104
FLAT otherwise
```

This is exactly `rho=1-D/364` and `abs(rho)>=2/7`. Exact ties consume the
month flat; there is no average-rank handling or p-value. Score magnitude
beyond the boundary never changes direction or risk.

Exact enumeration of all 13! no-tie paths gives a symmetric two-tail
qualification rate of `0.3436382463986631`, or about 4.1237 monthly decisions
per year under random ordering only. This is not an independence,
significance, frequency, or profitability claim.

## Rules

- `ea_id=41174`, exact XAU/XAG symbols, D1, slots 0/1, magics `411740000` /
  `411740001`.
- Consume normalized broker month before every fallible entry gate.
- Use exactly thirteen immediately prior consecutive completed month keys and
  the latest exactly timestamp-matched pair in each. The newest pair must be
  no more than ten calendar days stale.
- Compute the exact strict-rank permutation and D/T invariants. No tie
  deletion, alternate threshold, magnitude weight, fitted center, fitted
  scale, p-value, endpoint, slope, or fallback signal is permitted.
- Positive qualified score maps to short ratio; negative qualified score maps
  to long ratio. An interior score consumes the month flat.
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
6. Reconstruct thirteen consecutive completed synchronized month-end pairs;
   reject missing, duplicate, unmatched, current-month, nonchronological,
   nonpositive, nonfinite, or stale data.
7. Compute thirteen log ratios and strict ranks. Reject any exact ratio tie,
   non-permutation, odd D/T, out-of-range sum, or identity mismatch.
8. Require `T>=104` or `T<=-104` and map the result to exact contrarian
   package sides. Interior scores consume the month flat.
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
   considering replacement risk, even if the score direction is unchanged.
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
  synchronization, invalid month selection, ratio tie, invalid rank
  permutation or score invariant, interior score, excessive spread, invalid
  quote, unavailable ATR, invalid stop/volume, or notional mismatch.
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
| `strategy_xag_symbol` | XAGUSD.DWX | [XAGUSD.DWX] | exact companion and slot 1 |
| `strategy_endpoint_count` | 13 | [13] | synchronized ratio observations |
| `strategy_score_threshold` | 104 | [104] | inclusive absolute integer boundary |
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

Every value is a locked singleton. Changing carrier, sample, rank handling,
threshold, direction, clock, risk, stop, balance, hold, spread, order
sequence, or retry policy requires a new card and full pipeline run.

## Source-Defined Rules And QM Interpretations

Schweikert and CME supply the state-dependent gold/silver relation and
intermarket carrier. Spearman and the pinned R Core files supply strict-rank
association arithmetic. QM fixes synchronized month endpoints, the no-tie
rule, integer threshold, contrarian direction, continuous-CFD calendar,
consumed attempt, equal-notional fixed risk, spread caps, hard stops,
atomicity, rollover, and stale repair.

## Runtime Data Dependencies

Exact `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and closes, broker
time, symbol metadata, quotes, completed-bar ATR, framework position/deal
state, and a terminal-persistent attempt marker. No external runtime dataset
exists.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Each leg receives half
the stop-risk budget before notional equalization. Both legs can gap, a ratio
trend can persist, volume rounding creates imbalance, spread and financing
can dominate a low-frequency edge, and atomic repair can realize one-sided
loss. Equal target notionals are market-neutral-style construction, not proof
of market or portfolio neutrality.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK | Peer-reviewed gold/silver evidence, official exchange carrier research, named original Spearman record, and complete pinned R Core method files; exact trading rule untested. |
| R2 | PASS | Clock, synchronization, ratio order, ranks, D/T invariants, threshold, contrarian sides, attempt, aggregate risk, atomicity, and lifecycle are fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 routes supply every runtime input; Q02 owns density, cost, and CFD sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, prohibited external runtime feed, grid, or martingale. |

## Failure Modes And Kill Criteria

- Retire on zero trades, fewer than four completed packages in any full post-
  warm-up year, nonpositive governed economics, or downstream gate failure.
- Fail on current-month leakage, missing/duplicate month keys, nonlatest or
  unmatched pairs, wrong ratio orientation, stale endpoint,
  nonchronological data, endpoint count other than 13, nonfinite log ratio,
  accepted tie, invalid rank permutation, wrong D/T parity/range/identity,
  wrong threshold inclusion, or wrong package sides.
- Fail on same-month retry, non-atomic package, notional imbalance, missing
  hard stop, wrong risk mode, wrong spread ceiling, late entry, missed month-
  boundary exit, or nondeterminism.
- Retire on later portfolio-correlation rejection; no waiver is implied.
- Do not rescue failure by changing formation, rank rule, threshold,
  direction, carrier, risk, stop, balance, hold, spread, retry, or order
  sequence.

## Strategy Allowability Check

- [x] R1: PASS with method/carrier translation risk. Peer-reviewed
  gold/silver and statistical-method lineage plus official exchange carrier
  evidence; no performance is imported.
- [x] R2: PASS. Synchronized endpoints, strict ranks, integer score,
  contrarian direction, attempt, aggregate risk, atomicity, and exits are
  fixed.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XAU
  and XAG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic timestamps, logarithms, ranks, integer
  arithmetic, calendar, and ATR risk; no trained model or external feed.
- [x] Dedup: canonical checker CLEAN; carrier/direction/lifecycle and two
  fixed rank-vector counterexamples separate the candidate from neighbors.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, fixed-risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: durable month attempt, synchronized endpoint reconstruction,
  strict ranks, D/T invariants, inclusive threshold, contrarian sides,
  spread/quote/ATR/stop checks, equal-notional sizing, and atomic validation.
- trade_management: package repair, prior-month exit, and stale exit before
  entry-only gates.
- trade_close: framework close helper per leg, broker hard stops, and kill
  switch.

## Validation Plan

1. Schema-lint canonical and EA card copies.
2. Independently reproduce strict ranks, D/T identity and parity, inclusive
   thresholds, long/short symmetry, all 13! density count, both separation
   vectors, monotone paths, and exact contrarian sides.
3. Validate synchronization, thirteen consecutive month keys, year rollover,
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
one logical basket), and one paced non-live logical Q02 enqueue if CPU
capacity permits. It does not authorize a manual backtest; live, demo,
shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy or
live manifest; portfolio-gate mutation; portfolio admission; threshold
change; correlation waiver; or terminal process control.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial XAU/XAG Spearman ratio-rank reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED; R1-R4 PASS | `decisions/2026-08-27_qm5_41174_xauxag_monthly_spearman_rank_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
