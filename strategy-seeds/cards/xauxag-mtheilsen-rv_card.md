---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026_S01
variant_id: SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026_S01
source_id: SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026
ea_id: QM5_41157
slug: xauxag-mtheilsen-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41157_xauxag-mtheilsen-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-25
created_by: Research+Development
last_updated: 2026-08-25
g0_status: APPROVED
g0_decision: decisions/2026-08-25_qm5_41157_xauxag_monthly_theilsen_reversion_g0.md
source_approval: decisions/2026-08-25_xauxag_monthly_theilsen_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; governed Theil-Sen arithmetic precedent MOP-WTI-THEILSEN-2026."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed lineage strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "governed lineage strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_driver_difference
  - type: governed_method_precedent
    citation: "QuantMechanica bounded thirteen-endpoint Theil-Sen-style robust-slope mechanization."
    location: "strategy-seeds/sources/MOP-WTI-THEILSEN-2026/source.md"
    quality_tier: internal_governed
    role: exact_pair_enumeration_month_index_denominator_sort_and_median_arithmetic_only
strategy_mechanic: exact-synchronized-thirteen-consecutive-completed-broker-month-end-gold-minus-silver-log-ratio-seventy-eight-forward-month-index-normalized-slopes-exact-even-theil-sen-median-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/robust-multi-month-ratio-slope-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-end-ratio-theil-sen-slope]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, completed-month-end-ratio-slope, robust-theil-sen-direction, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41157_XAU_XAG_MTHEILSEN_RV_D1
symbol: QM5_41157_XAU_XAG_MTHEILSEN_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411570000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year after thirteen-month formation, exact synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ROBUST_SLOPE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a thirteen-completed-month gold/silver ratio-path Theil-Sen reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify exact synchronization, consecutive broker months, latest month-end selection, ratio orientation, all 78 forward pairs, j-i denominators, central indexes 38/39, contrarian sides, one attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, thirteen_consecutive_completed_months, synchronized_month_end_pairs, latest_pair_per_month, chronological_ratio_orientation, forward_pair_bounds, month_index_denominator, exact_pair_count_78, ascending_sort, even_median_indexes, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-25 and decisions/2026-08-25_qm5_41157_xauxag_monthly_theilsen_reversion_g0.md: R1 PASS with explicit robust-slope translation risk using peer-reviewed gold/silver relation, official exchange carrier, and governed exact Theil-Sen arithmetic; R2 PASS locked synchronized month ends, ratios, pair bounds, denominators, count, median, sides, attempt, aggregate risk, stops, and repair; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup and manual family review found no duplicate."
---

# QM5_41157 XAU/XAG Thirteen-Month Theil-Sen Ratio Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. A persistent relative
move can therefore overshoot while common metal direction remains large. The
median of all forward slopes through thirteen synchronized month-end log
ratios estimates the direction of that relative path without letting one
chosen endpoint or one monthly jump own the signal. Fading the robust slope
tests whether the ratio partially reverts over the following broker month.

The opposite equal-target-notional legs are designed to reduce common
outright-metal direction and create a market-neutral-style stream different
from the certified directional XAU, SP500, NDX, and XNG book. They do not
prove dollar, beta, volatility, factor, market, or portfolio neutrality. Q02
owns density and baseline economics; unchanged Q09 alone owns realized
portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026/source.md`,
SHA-256
`69D36A01FF335BEE5A539CD58939F587ABC5DCAE3317C4AE77CAEAAB38B5BDCA`,
authorized before extraction by
`decisions/2026-08-25_xauxag_monthly_theilsen_reversion_source_approval.md`
at commit `e6c9d2ae4` and committed as a bounded packet at `d4e13bb6c`.

Schweikert supplies a related, state-dependent gold/silver hypothesis. CME
supplies the intermarket-spread carrier and the metals' different economic
drivers. The governed Theil-Sen packet supplies exact thirteen-endpoint,
78-forward-pair, month-index-denominator, sorting, and median arithmetic only.
None tests a thirteen-month gold/silver robust ratio slope, its contrarian
next-month mapping, Darwinex continuous CFDs, equal-notional fixed-dollar ATR
risk, or the QM book.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, or correlation
statistic is imported. No new public route was needed or used.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,656 registry
identities, 1,307 cards, and 45 current Strategy Wiki nodes. It returned
`CLEAN`, with no exact or fuzzy match. Evidence is
`artifacts/qm5_xauxag_mtheilsen_rv_preallocation_dedup_20260825.json`.

Manual family review fixes the mechanical boundaries:

- `QM5_20271_wti-theilsen-tr` uses thirteen outright WTI month ends, follows
  the slope, and owns one WTI leg. This card uses paired gold-minus-silver
  month-end ratios, fades the slope, and owns an atomic XAU/XAG package.
- `QM5_20050_xauxag-xmom12` and `QM5_20202_xauxag-rev18` use endpoint return
  mechanics rather than all 78 month-index-normalized forward slopes.
- `QM5_20161_xauxag-ols-rv` and `QM5_21526_xau-xag-cadf` fit regression
  residual centers/scales and trade threshold crossings. This card fits no
  alpha, beta, residual scale, unit-root statistic, half-life, or z-score.
- `QM5_41138_xauxag-mdaily-hl-rv` uses 17-23 daily relative returns inside
  one completed month and inclusive self/cross-pair averages. This card uses
  thirteen month-end ratio levels, excludes self-pairs, and divides every
  displacement by elapsed month indexes.
- fixed-ratio, quantile, MAD, flow, sign-breadth, sequence, and path cards
  observe different state objects; none uses this exact robust temporal
  slope contract.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  long-only XNG oscillator pullback.

The paired carrier, thirteen consecutive completed months, latest exactly
synchronized close pair per month, log-ratio orientation, 78 forward pairs,
`j-i` denominators, exact even median, contrarian sides, durable attempt,
equal-notional aggregate-risk package, and next-month exit are jointly load
bearing. Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_THEILSEN_RATIO_SLOPE_REVERSION_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `411570000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `411570001`.
- Logical symbol: `QM5_41157_XAU_XAG_MTHEILSEN_RV_D1`.
- Decision: first synchronized executable tick of a new broker-calendar
  month, within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: the latest exactly synchronized close pair from each of the
  thirteen consecutive completed broker months ending immediately before the
  decision month; all current-month closes are excluded.
- Position count: zero or one valid two-leg package and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: eleven packages/year as an ordering prior within a
  10-12 design range; Q02 must prove at least five in every scored full year.

## Formula

For thirteen chronological positive finite month-end pairs:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..12

k = 0
for i = 0..11:
  for j = i+1..12:
    slope[k] = (s[j] - s[i]) / (j - i)
    k += 1

require k == 78
sorted = ascending(slope[0..77])
theilsen = (sorted[38] + sorted[39]) / 2

theilsen > 0 => SELL XAU, BUY XAG
theilsen < 0 => BUY XAU, SELL XAG
otherwise    => FLAT
```

Require exact host/companion timestamps, exactly one latest pair for every
required month, strict chronological order, positive finite closes, finite
ratios/slopes/central sum, positive `j-i`, exact pair count 78, and ascending
sort. The raw endpoint displacement `s[12]-s[0]` is diagnostic only. It may
agree or disagree with the median slope and never gates direction. Exact zero
or invalid state consumes the month flat.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed or partial owned exposure before entry-only filters.
2. Require exact symbols, D1, EA ID, slots, risk mode, news modes, Friday-close
   inputs, and all locked strategy inputs.
3. Detect a genuine host broker-month transition and require the companion's
   raw current D1 bar timestamp to match the host. The first eligible tick
   must be within 180 elapsed minutes of the raw host D1 bar open.
4. Before history or any other fallible gate, persist the current broker
   `yyyymm` as consumed. Tester initialization may clear only a marker lying in
   the future of the restarted historical clock.
5. From at most 500 completed D1 bars per symbol, match timestamps exactly and
   retain only the latest pair in each broker month. Require exactly the
   immediately prior thirteen consecutive month keys, newest to oldest, then
   reverse them into chronological order. The newest endpoint may be no more
   than ten calendar days before the current host D1 bar open.
6. Compute the thirteen log ratios, all 78 forward slopes, ascending sort, and
   exact central average. Do not use the current month or any endpoint,
   regression, scale, crossing, event, seasonal, volatility, external, or
   prior-result gate.
7. A strict positive slope requests SELL XAU / BUY XAG. A strict negative
   slope requests BUY XAU / SELL XAG. Equality and invalid state are flat.
8. Require no owned exposure or same-month entry deal, both spreads inside
   their locked caps, executable quotes, completed `ATR(20,D1)` for each leg,
   valid stops and contract metadata, and exact fixed-risk mode.
9. Split one aggregate `RISK_FIXED=1000` budget equally between the legs,
   calculate each independent stop-risk volume against a frozen
   `3.5*ATR(20,D1)` stop, then reduce only the larger target volume as needed
   to obtain equal target absolute USD notionals. Never increase either risk-
   sized volume. Require both normalized volumes to remain valid.
10. Open XAU first and XAG second with no target. Retain the package only when
    exactly one correctly directed position with its registered magic and a
    valid hard stop exists in each slot and realized absolute USD notionals
    differ by no more than 20% of the larger leg. On any order or final
    validation failure, flatten every owned leg immediately without retry.

## 5. Exit Rules

1. Close both legs on the first tick whose broker `yyyymm` is later than the
   package entry month.
2. Close both legs after forty elapsed calendar days as stale repair.
3. Immediately flatten an orphan, duplicate, same-side, wrong-symbol,
   wrong-magic, missing-stop, or over-20%-notional-mismatch package.
4. Broker hard stops and the framework kill switch remain authoritative. If
   one hard stop closes a leg, repair the resulting orphan immediately.
5. Friday close is disabled for the multi-session hold. There is no target,
   convergence exit, signal reversal exit, trailing stop, break-even, partial
   close, scale-in, grid, martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, companion, timeframe, EA ID, slots, active
  magic rows, fixed-risk mode, news mode, Friday mode, or locked inputs.
- Reject a consumed month, owned exposure, same-month deal, late decision
  tick, unsynchronized current bars, missing/duplicate/nonconsecutive month,
  nonlatest monthly selection, nonchronological or stale endpoint,
  nonpositive close, invalid ratio/slope/median, wrong pair count, excessive
  spread, invalid quote, missing ATR, invalid stop, invalid contract metadata,
  or unachievable two-leg notional tolerance.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and package repair run before entry-only gates.
- Runtime may not read an external file or API, futures chain, analyst input,
  optimizer result, trained output, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one two-leg package and one consumed attempt per broker
  month.
- Preserve each original broker hard stop; never modify a stop or position
  size after entry.
- Recompute no signal while the package is open. The first later month and
  forty-day stale clock own normal lifecycle exits.
- Restart recovery combines a terminal-persistent consumed-month marker with
  owned position and deal history. Historical tester initialization removes
  only a marker that lies in the future of the restarted test clock.
- Process later-month exit, stale exit, and malformed-package repair before
  any new entry gate.
- No randomness, adaptive PnL fitting, external state, partial close,
  scale-in, grid, martingale, or pyramiding is allowed.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled for the monthly basket hold.
- Stress rejection: zero for the Q02 baseline.
- Framework kill switch and server-side broker hard stops: authoritative.
- Forced session flatten: none; later-month, forty-day, and malformed-package
  exits are strategy-owned.

## Exit Precedence

1. Framework kill switch and each server-side hard stop.
2. Malformed, orphaned, duplicated, same-side, wrong-symbol/magic, stopless,
   or notional-invalid package repair.
3. First tick in a broker month later than the entry month.
4. Forty-calendar-day stale repair.
5. No Friday, news, target, convergence, signal-reversal, trailing,
   break-even, partial, or discretionary exit is added.

## Runtime Data Dependencies

- Exact chart route: `XAUUSD.DWX`, D1; synchronized companion route:
  `XAGUSD.DWX`, D1.
- Native tester data: D1 timestamps and closes, completed `ATR(20,D1)`,
  executable bid/ask, spread, tick value/size, contract size, volume metadata,
  broker calendar, positions, deals, and terminal-persistent global variables.
- The terminal marker and exact entry-deal tag provide restart-safe no-retry
  state. Historical tester initialization removes only a future marker.
- No external file, API, event calendar, futures chain, trained artifact,
  analyst input, optimizer output, or portfolio state is read at runtime.
- Tester account currency and fixed-risk loss sizing remain framework-owned;
  notional balancing may only reduce a risk-sized leg.

## Parameters To Test

Q02 uses only the locked defaults. The table records the contract and does not
authorize a rescue sweep after failure.

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_month_end_count` | 13 | [13] | exact synchronized completed-month observations |
| `strategy_history_bars_d1` | 500 | [500] | bounded month-end reconstruction buffer per symbol |
| `strategy_entry_window_minutes` | 180 | [180] | maximum elapsed time from raw new-month host D1 open |
| `strategy_max_endpoint_gap_days` | 10 | [10] | immediately prior month-end freshness guard |
| `strategy_atr_period_d1` | 20 | [20] | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop multiple |
| `strategy_notional_ratio` | 1.0 | [1.0] | equal target absolute XAU/XAG notionals |
| `strategy_xau_max_spread_points` | 1500 | [1500] | gold entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | [500] | silver entry spread ceiling |
| `strategy_max_notional_mismatch_fraction` | 0.20 | [0.20] | post-open package tolerance |
| `strategy_max_hold_days` | 40 | [40] | stale package repair ceiling |
| `strategy_deviation_points` | 20 | [20] | paired order deviation |

All values, timestamp matching, calendar-month selection, sample inclusion,
pair bounds, denominator, median definition, direction, risk split, notional
balancing, hard stops, and no-retry policy are locked.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for one aggregate package. Each leg begins with half of
the stop-risk budget; equal-notional balancing may reduce but never increase
a risk-sized volume. Both legs require frozen broker hard stops and no target.

Risk is high: the state-dependent relation may not revert; a robust slope can
remain one-sided; continuous spot CFDs differ from source futures/research;
contract sizes, gaps, spreads, financing, lot granularity, stop slippage, and
legging can break intended neutrality; thirteen consecutive synchronized
month ends may be unavailable; and the stream may remain correlated with the
certified XAU sleeve.

Retire on zero trades, fewer than five completed packages per full post-
warm-up year, invalid month-end reconstruction, wrong slope arithmetic,
aggregate-risk breach, repeated attempts, atomicity failure, nondeterminism,
nonpositive governed economics, or later portfolio-correlation rejection. Do
not alter the horizon, estimator, side mapping, risk, notional tolerance,
stop, or hold to rescue results.

## Reputable-Source Criteria And Allowability

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_ROBUST_SLOPE_TRANSLATION_RISK | Named-author peer-reviewed gold/silver evidence with DOI, official CME spread carrier, durable complete-read lineage, and governed exact Theil-Sen arithmetic; the trading conjunction is explicitly untested. |
| R2 | PASS | Clock, samples, synchronization, ratios, slopes, median, sides, attempt, aggregate risk, stops, atomicity, and exits are fixed. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered XAUUSD.DWX and XAGUSD.DWX D1 histories supply every runtime field; Q02 must prove synchronized support and fills. |
| R4 | PASS | Deterministic native arithmetic only, without trained output, banned signal indicator, external runtime feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact host/timeframe/ID/slots, locked inputs, risk/news/Friday
  contract, current-bar synchronization, month transition, consumed attempt,
  completed-month reconstruction, spreads, quotes, ATR, stops, and package
  guards.
- trade_entry: exact 78-slope Theil-Sen sign, persistent attempt, opposite
  paired orders, shared risk, equal-notional reduction, frozen hard stops, and
  second-leg rollback.
- trade_management: later-month and stale lifecycle, malformed-package repair,
  and no-retry recovery before entry gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five completed packages per full
post-warm-up year, or nonpositive governed economics. Any current-month
leakage, missing/duplicate month, nonlatest close pair, timestamp mismatch,
wrong ratio orientation, missing/duplicate forward pair, wrong denominator,
wrong count or median, wrong direction, same-month retry, malformed package
retention, aggregate-risk breach, or nondeterminism is an implementation
failure rather than a tunable result.

Any change to the carrier, observation count, synchronized-month selection,
ratio orientation, pair enumeration, denominator, median, direction, stop,
spread cap, risk split, notional rule, attempt lifecycle, symbol, timeframe,
news/Friday mode, or risk mode requires a new binary and full pipeline
requalification. Realized diversification may only be assessed at the
unchanged portfolio-correlation gate; a correlation failure receives no
waiver here.

## Safety Boundary

This card authorizes only governed magic allocation, one branch build, strict
compile/Q01, one logical D1 `RISK_FIXED` backtest setfile, and one paced non-
live Q02 enqueue if CPU capacity permits. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio-gate mutation; portfolio
admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-25 | initial thirteen-month XAU/XAG Theil-Sen ratio-slope card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-25 | APPROVED; R1-R4 PASS | `decisions/2026-08-25_qm5_41157_xauxag_monthly_theilsen_reversion_g0.md`; approved source packet |
| Q01 Build Validation | - | NOT_BUILT | strict compile and build checks pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and build review pending |
