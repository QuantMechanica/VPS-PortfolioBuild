---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026_S01
variant_id: SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026_S01
source_id: SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026
ea_id: QM5_41164
slug: xauxag-mrepmedian-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41164_xauxag-mrepmedian-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-26
created_by: Research+Development
last_updated: 2026-08-26
g0_status: APPROVED
g0_decision: decisions/2026-08-26_qm5_41164_xauxag_monthly_repeated_median_reversion_g0.md
source_approval: decisions/2026-08-26_xauxag_monthly_repeated_median_reversion_source_approval.md
source_author: "Karsten Schweikert; Andrew F. Siegel; CME Group"
source_authors: "Karsten Schweikert; Andrew F. Siegel; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Siegel (1982), Biometrika 69(1), 242-244, DOI 10.1093/biomet/69.1.242; official CME Group gold/silver ratio-spread lineage."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete governed packet strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence
  - type: peer_reviewed_statistical_method_record
    citation: "Siegel, A. F. (1982). Robust Regression Using Repeated Medians. Biometrika 69(1), 242-244."
    location: "DOI 10.1093/biomet/69.1.242; official Oxford Academic record preserved in strategy-seeds/sources/MOP-SIEGEL-WTI-REPMEDIAN-2026/source.md"
    quality_tier: A
    role: repeated_median_nested_robust_regression_lineage_only
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "complete governed lineage in strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_driver_difference
strategy_mechanic: synchronized-thirteen-completed-month-end-gold-minus-silver-log-ratio-siegel-repeated-median-of-thirteen-pivot-specific-twelve-slope-medians-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/repeated-median-ratio-slope-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-end-ratio-repeated-median-slope]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, repeated-median, robust-slope, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41164_XAU_XAG_MREPMEDIAN_RV_D1
symbol: QM5_41164_XAU_XAG_MREPMEDIAN_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411640000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year after thirteen-month formation, exact synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ESTIMATOR_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a thirteen-completed-month gold/silver ratio repeated-median reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify synchronization, consecutive months, ratio orientation, thirteen pivot groups, twelve forward slopes per pivot, inner median indexes 5/6, outer median index 6, contrarian sides, one attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, exact_thirteen_pivots, exact_twelve_slopes_per_pivot, forward_slope_orientation, inner_even_median_indexes_5_6, outer_odd_median_index_6, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-26 and decisions/2026-08-26_qm5_41164_xauxag_monthly_repeated_median_reversion_g0.md: R1 PASS with explicit estimator-translation risk using peer-reviewed gold/silver relation, official exchange carrier, and peer-reviewed repeated-median lineage; R2 PASS locks synchronized endpoints, pivot groups, slopes, both median stages, sides, attempt, aggregate risk, stops, and repair; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup is clean and a fixed ratio path proves the opposite package direction versus both existing Theil-Sen and LAD baskets."
---

# QM5_41164 XAU/XAG Thirteen-Month Repeated-Median Ratio Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A relative move supported
by only a few endpoints can be fragile. The repeated-median statistic gives
each synchronized month-end ratio its own central forward slope before taking
the central pivot, testing whether broad relative displacement subsequently
reverts without fitting an adaptive model or scaling risk by signal magnitude.

Opposite equal-target-notional legs are designed to reduce common outright-
metal direction and form a market-neutral-style stream different from the
certified directional XAU, SP500, NDX, and XNG book. They do not prove dollar,
beta, volatility, factor, market, or portfolio neutrality. Q02 owns density
and baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-SIEGEL-CME-XAUXAG-MREPMEDIAN-RV-2026/source.md`,
SHA-256
`C96F58F707CA0D622ACF955ABE82E973B60B06F7F872729701C15D3E03B43462`,
authorized by
`decisions/2026-08-26_xauxag_monthly_repeated_median_reversion_source_approval.md`
and committed at `12d432f58` before card extraction.

Schweikert supplies a related but state-dependent gold/silver hypothesis and
binding adverse evidence. The governed CME record supplies the intermarket
carrier and distinct metal drivers. Siegel supplies repeated-median robust-
regression lineage. None tests this exact paired monthly ratio fade,
Darwinex continuous CFDs, equal-notional fixed-dollar ATR risk, or the QM book.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, robustness improvement, CFD
equivalence, or correlation statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,663 registry
identities, 1,314 cards, and 45 current Strategy Wiki nodes and returned
`CLEAN`. Evidence is
`artifacts/qm5_xauxag_mrepmedian_rv_preallocation_dedup_20260826.json`,
SHA-256
`D831A578286D639AFD34C8BC6AA02A9D6FEF93E3B5AD14E1DBC346691D8CB28F`.

Manual family review fixes the mechanical boundary:

- `QM5_41157_xauxag-mtheilsen-rv` pools all 78 unique slopes into one global
  median. This card takes a median inside each of thirteen pivot groups and
  then an outer median.
- `QM5_41160_xauxag-mlad-rv` profiles intercepts and minimizes vertical
  absolute loss. This card has no intercept or objective.
- On `[0,.01,.06,.11,.14,.13,.11,.12,.09,.04,.02,.05,.10]`, Theil-Sen is
  `+0.00155555555555556`, LAD is `+0.00375`, and repeated median is `-0.0045`;
  the common fade mapping makes this card open the opposite package.
- `QM5_41158_wti-repmedian-tr` uses the estimator on outright WTI, follows it,
  and owns one leg. This card uses a synchronized metal-relative path, fades
  it, and owns an atomic equal-notional basket.
- Conditional regression, z-score, OLS, CADF, MAD, daily-return pseudomedian,
  path, sign, flow, and calendar systems estimate different objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback with neither this carrier nor mechanic.

Verdict: `CLEAN_EXACT_FUZZY_AND_FUNCTIONAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: `XAUUSD.DWX`; companion/traded slot 1: `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41164_XAU_XAG_MREPMEDIAN_RV_D1` on XAU host.
- Timeframe: D1; intended magics `411640000` and `411640001`.
- Decision: first synchronized executable D1 tick after a genuine broker-month
  transition, within 180 elapsed minutes of the raw host D1 bar open.
- Formation: thirteen consecutive synchronized completed broker-month ends.
- Hold: next broker-month boundary; forty calendar days is stale repair.
- Expected cadence: approximately ten to twelve packages per full post-warm-
  up year; retire below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, symbol metadata,
  position, deal, broker calendar, and terminal-persistent attempt state only.

## Formula

At the start of month `t`, let `s[0]..s[12]` be synchronized completed-month
gold-minus-silver log ratios from months `t-13..t-1`, oldest to newest:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i])

for i = 0..12:
  slopes_i = []
  for j = 0..12, j != i:
    lo = min(i,j)
    hi = max(i,j)
    slopes_i.append((s[hi] - s[lo]) / (hi - lo))
  require len(slopes_i) == 12
  ordered = ascending(slopes_i)
  pivot_median[i] = (ordered[5] + ordered[6]) / 2

repeated_median = ascending(pivot_median[0..12])[6]
```

Positive repeated median means SELL XAU / BUY XAG. Negative means BUY XAU /
SELL XAG. Exact zero or invalid state consumes the month flat. Magnitude never
scales risk.

## Rules

These are the complete authorized baseline. There is no parameter sweep,
pooled-slope fallback, fitted intercept, loss objective, endpoint agreement,
OLS, z-score, volatility signal, seasonal filter, external series, or prior-
result gate.

## 4. Entry Rules

1. Require exact EA ID `41164`, host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1,
   slots 0/1, and every baseline input locked to its declared value.
2. Process lifecycle repair before entry-only gates. Evaluate only at a genuine
   broker-month transition no later than 180 elapsed minutes after the raw host
   D1 bar open.
3. Persist current `yyyymm` as consumed before history, signal, news, spread,
   quote, ATR, sizing, margin, or order checks. No flat, rejected, failed,
   stopped, partial, or blocked outcome retries that month.
4. Reject owned exposure or any same-month entry deal for either magic.
5. Reconstruct exactly thirteen consecutive completed month-end pairs from
   bounded D1 buffers. In each month require the latest exactly timestamp-
   matched close pair; reject missing, duplicate, unmatched, current-month,
   nonchronological, or more-than-ten-day-stale newest pairs.
6. Keep pairs oldest to newest. Require positive finite closes and exactly
   thirteen finite gold-minus-silver natural-log ratios.
7. For each of thirteen pivots, enumerate exactly twelve slopes to every other
   endpoint. Orient each from earlier to later and divide by its positive
   integer month-index distance.
8. Sort each pivot's twelve slopes and average zero-based indexes 5 and 6.
   Require thirteen finite pivot medians, sort them, and take index 6. Fade the
   strict sign; exact zero consumes the month flat.
9. Require both spreads in bounds, executable quotes, completed
   `ATR(20,D1)`, valid symbol metadata, fixed-risk sizing, and realized target
   absolute-notional mismatch no greater than 20%.
10. Split aggregate fixed stop-risk equally, reduce only to equalize target
    notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and attach no targets.
11. Submit XAU first and XAG second. Keep only one correctly directed,
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
5. Friday close is disabled because the source-aligned hold spans weekends.
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
  interest, file, API, forecast, trained output, optimizer result, or
  portfolio state.

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
| `strategy_xag_symbol` | XAGUSD.DWX | [XAGUSD.DWX] | exact companion and traded slot 1 |
| `strategy_month_end_count` | 13 | [13] | synchronized completed-month ratio observations and pivots |
| `strategy_history_bars_d1` | 500 | [500] | bounded pair reconstruction |
| `strategy_entry_window_minutes` | 180 | [180] | maximum elapsed time after raw new-month host bar open |
| `strategy_max_endpoint_gap_days` | 10 | [10] | newest synchronized endpoint age ceiling |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 risk estimator per leg |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen broker hard-stop distance |
| `strategy_notional_ratio` | 1.0 | [1.0] | target absolute USD notional ratio |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | realized package-balance tolerance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_xau_max_spread_points` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | [500] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | bounded order deviation |

Every value is a locked singleton. Changing the carrier, endpoint count,
pivot membership, median convention, direction, clock, risk, stop, balance,
hold, spread, order sequence, or retry policy requires a new card and full
pipeline run.

## Author Claims

Schweikert documents a state-dependent gold/silver relationship and adverse
evidence against a simple constant-vector trade. CME documents ratio-spread
lineage. Siegel documents repeated-median statistical lineage. They do not
claim that this rule works, that the statistic is superior, that continuous
CFDs reproduce futures, or that the package diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` as one aggregate package budget. Risk is high: both legs
can gap, relative trends can persist, volume rounding creates imbalance,
spread and financing can dominate a low-frequency edge, atomic repair can
realize one-sided loss, and XAU/XAG can overlap the certified XAU exposure.
Equal target notionals are market-neutral-style construction, not proof of
market or portfolio neutrality.

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

- [x] R1: PASS with estimator-translation risk. Peer-reviewed gold/silver
  evidence, official exchange carrier lineage, and a peer-reviewed method
  record; no method performance is imported.
- [x] R2: PASS. Fixed endpoints, synchronization, pivots, slopes, both median
  stages, direction, attempt, aggregate risk, atomicity, and exits.
- [x] R3: PASS with synchronization/continuous-CFD basis risk. Registered XAU
  and XAG D1 histories plus native V5 state only.
- [x] R4: PASS. Deterministic logarithms, pairwise arithmetic, sorting,
  calendar, and ATR risk arithmetic; no trained model, banned signal
  indicator, external feed, grid, or martingale.
- [x] Dedup: canonical exact/fuzzy scan is clean; fixed sign-divergence path
  distinguishes both neighboring XAU/XAG robust-slope baskets.

## Framework Alignment

- no_trade: exact XAU/XAG/D1/EA/slots, locked inputs, fixed risk/news/Friday
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
portfolio-gate mutation; portfolio admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-26 | initial XAU/XAG repeated-median ratio-reversion card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-26 | APPROVED; R1-R4 PASS | `decisions/2026-08-26_qm5_41164_xauxag_monthly_repeated_median_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
