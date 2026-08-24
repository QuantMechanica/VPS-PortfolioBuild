---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01
variant_id: SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01
source_id: SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026
ea_id: QM5_41138
slug: xauxag-mdaily-hl-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41138_xauxag-mdaily-hl-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-24
created_by: Research+Development
last_updated: 2026-08-24
g0_status: APPROVED
g0_decision: decisions/2026-08-24_qm5_41138_xauxag_monthly_daily_hodges_lehmann_reversion_g0.md
source_approval: decisions/2026-08-24_xauxag_monthly_daily_hodges_lehmann_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread; governed H-L arithmetic precedent MOP-WTI-HLRET-2026."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_driver_difference
  - type: governed_method_precedent
    citation: "QuantMechanica bounded Hodges-Lehmann-style return-location mechanization."
    location: "strategy-seeds/sources/MOP-WTI-HLRET-2026/source.md"
    quality_tier: internal_governed
    role: inclusive_pair_enumeration_and_exact_median_arithmetic_only
strategy_mechanic: exact-synchronized-xau-xag-immediately-completed-broker-month-seventeen-to-twenty-three-daily-gold-minus-silver-log-ratio-returns-all-inclusive-self-cross-pair-averages-dynamic-hodges-lehmann-pseudomedian-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/robust-within-month-relative-return-location]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-relative-return-hodges-lehmann-pseudomedian]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, completed-month-daily-relative-return-pseudomedian, robust-location-direction, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41138_XAU_XAG_MDAILY_HL_RV_D1
symbol: QM5_41138_XAU_XAG_MDAILY_HL_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411380000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year after exact synchronization and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_DAILY_PSEUDOMEDIAN_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a completed-month gold/silver daily-relative-return Hodges-Lehmann-style reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify exact synchronization, older boundary pair, every relative return ending in the month, endpoint identity, inclusive self/cross-pair enumeration, dynamic pair count, exact odd/even median, contrarian equal-notional sides, one attempt, aggregate fixed risk, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, immediate_completed_calendar_month, synchronized_session_count, older_boundary_pair, chronological_relative_log_return_orientation, every_month_return_once, endpoint_identity, inclusive_pair_bounds, self_pair_identity, dynamic_pair_count, ascending_sort, odd_even_median, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-24 and decisions/2026-08-24_qm5_41138_xauxag_monthly_daily_hodges_lehmann_reversion_g0.md: R1 PASS with explicit translation risk using peer-reviewed gold/silver relation, official exchange carrier, and governed H-L arithmetic precedent; R2 PASS locked synchronized month package, returns, inclusive pairs, dynamic count, exact median, sides, attempt, aggregate risk, stops, and repair; R3 PASS registered native XAU/XAG D1 with synchronization/CFD risk; R4 PASS deterministic native arithmetic only. Canonical dedup found one fuzzy central-band neighbor, manually resolved as a different estimator."
---

# QM5_41138 XAU/XAG Completed-Month Daily-Return Hodges-Lehmann Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but respond differently
to safe-haven, monetary, industrial, and business-cycle shocks. One completed
month's net ratio move can be dominated by a few extreme sessions. The
Hodges-Lehmann-style pseudomedian uses every daily relative return both alone
and in cross-pairs to estimate a robust central displacement before fading it
over the following broker month.

The opposite equal-target-notional legs are designed to reduce common
outright-metal direction and create a market-neutral-style return stream
different from the certified directional XAU, SP500, NDX, and XNG book. They
do not prove dollar, beta, volatility, factor, or portfolio neutrality. Q02
owns density and baseline economics; unchanged Q09 alone owns realized
portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
SHA-256
`D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`,
authorized before extraction by
`decisions/2026-08-24_xauxag_monthly_daily_hodges_lehmann_reversion_source_approval.md`
at commit `46e7be1d3` and committed as a bounded packet at `f28f564a5`.

Schweikert supplies a related, state-dependent gold/silver hypothesis. CME
supplies the intermarket-spread carrier and the two metals' different economic
drivers. The governed H-L packet supplies exact inclusive-pair and median
arithmetic only. None tests a daily relative-return pseudomedian inside one
broker month, contrarian next-month sides, Darwinex continuous CFDs, equal-
notional fixed-dollar ATR risk, or the QM book. Every horizon, estimator,
direction, execution, and risk choice below is a declared QM interpretation.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, or correlation
statistic is imported. New public routes were policy-deferred and not used.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,637 registry
identities, 1,305 cards, and 45 Strategy Wiki nodes. It found no exact identity
and surfaced only `QM5_41135_xauxag-mdaily-iqrmean-rv` as a fuzzy neighbor.
Evidence is
`artifacts/qm5_xauxag_mdaily_hl_rv_preallocation_dedup_20260824.json`.

Manual family review fixes the mechanical boundaries:

- `QM5_41135` removes `floor(n/4)` raw returns from both tails and averages
  the retained 9-13 observations. This card retains every observed return,
  forms every inclusive self/cross-pair average, and takes the exact median of
  153-276 derived values.
- `QM5_20276_wti-hl-mom` uses twelve completed monthly outright-WTI returns,
  follows the estimator, and owns one WTI position. This card uses 17-23 daily
  intermetal returns inside one completed month, fades the estimator, and owns
  an atomic XAU/XAG package.
- rolling ratio, OLS, quantile, and MAD cards estimate a fitted center,
  coefficient, scale, or threshold crossing. This card estimates none.
- sign breadth, fixed blocks, sequences, path quotients, RMS coherence, and
  persistence observe different state objects; none enumerates inclusive
  pairwise return averages.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The paired carrier, exact completed month, older boundary pair, every relative
return ending in the month, inclusive self/cross-pair enumeration, dynamic
pair count, exact odd/even median, contrarian sides, durable attempt, equal-
notional aggregate-risk package, and next-month exit are jointly load
bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_HODGES_LEHMANN_REVERSION_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `411380000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `411380001`.
- Logical symbol: `QM5_41138_XAU_XAG_MDAILY_HL_RV_D1`.
- Decision: first synchronized executable tick of a new broker-calendar
  month, within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: exact immediately completed synchronized calendar month plus
  one adjacent older boundary pair; current-month prices are excluded.
- Position count: zero or one valid two-leg package and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: eleven packages/year as an ordering prior within a
  10-12 design range; Q02 must prove at least five in every scored full year.

## Formula

For older boundary ratio `s[-1]`, chronological completed-month ratios
`s[0]..s[n-1]`, and `n` relative returns:

```text
s[j] = ln(XAU_close[j]) - ln(XAG_close[j])
r[j] = s[j] - s[j-1], j=0..n-1

k = 0
for i = 0..n-1:
  for j = i..n-1:
    w[k] = (r[i] + r[j]) / 2
    k += 1

m = n * (n + 1) / 2
require k == m
sorted = ascending(w[0..m-1])

hl = sorted[m/2]                         when m is odd
hl = (sorted[m/2-1] + sorted[m/2]) / 2  when m is even

hl > 0 => SELL XAU, BUY XAG
hl < 0 => BUY XAU, SELL XAG
otherwise => FLAT
```

Require positive finite closes, finite ratios, returns, pairwise values and
sums, `17 <= n <= 23`, and `m=n*(n+1)/2` in `[153,276]`. Verify `sum(r)`
against the direct log-ratio move from the older boundary pair to the final
completed-month pair within `1e-10`. Exact-zero constituent returns and
duplicate pairwise values are valid. A zero pseudomedian, pair-count defect,
self-pair defect, endpoint mismatch, or invalid numerical state is flat. The
raw endpoint is diagnostic only and cannot gate direction.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

1. Repair malformed or partial owned exposure before entry-only filters.
2. Require exact symbols, D1, EA ID, slots, risk mode, news modes, Friday-close
   inputs, and synchronized current host/companion bars.
3. Observe a new host D1 bar and derive current broker `yyyymm` from its raw
   bar time.
4. Admit only within `strategy_entry_grace_minutes=180` elapsed minutes of raw
   host-bar open. Late attachment consumes the month flat.
5. Persist current `yyyymm` before history, aggregation, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that month.
6. Aggregate the exact immediately completed synchronized broker month.
   Require 17 through 23 valid pairs and one older boundary pair.
7. Build chronological gold-minus-silver log-ratio returns ending on every
   completed-month session. Require endpoint identity and finite arithmetic.
8. Enumerate every inclusive pair `(i,j)` with `0 <= i <= j < n`, append
   `(r[i]+r[j])/2` once, require the exact dynamic pair count, and verify each
   self-pair against its source return within tolerance.
9. Sort the complete pairwise array and compute the exact odd/even median.
   Fade positive with SELL XAU / BUY XAG and negative with BUY XAU / SELL XAG.
   Equality and invalid state remain flat.
10. Require XAU spread no greater than 1,500 points, XAG spread no greater
    than 500 points, valid quotes, and valid completed-bar `ATR(20,D1)` on
    both legs.
11. Freeze one hard stop `3.5*ATR` from each leg's entry and use no target.
12. Size to equal target absolute USD notionals with combined normalized stop
    risk at or below the single aggregate `RISK_FIXED` budget. Reject a
    package whose realized notional mismatch exceeds 20%.
13. Submit the first leg then the second; if the second leg fails or the pair
    is malformed, close all owned exposure immediately. No same-month retry.

Pseudomedian and endpoint magnitudes never change the fixed risk budget or
target notionals.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA and logical basket, and
stores the current broker `yyyymm`. It is written before every fallible gate.
Initialization after the 180-minute grace consumes the missed month without a
late trade. Owned deal history and open-position checks are additional fail-
closed guards. An order rejection, atomic repair, stop-out, news block, spread
failure, restart, invalid ATR, or invalid history cannot create a same-month
retry.

## 5. Exit Rules

1. Broker hard stops and framework kill switch remain authoritative.
2. Orphaned, duplicated, same-side, wrong-magic, stopless, or notional-invalid
   owned exposure is flattened as one broken package.
3. Close both legs on the first tick whose broker `yyyymm` is later than the
   month stored for the package's entry attempt.
4. Forty elapsed calendar days is a stale repair only.

There is no convergence target, take-profit, opposite-signal exit, trailing
stop, break-even move, partial close, Friday flattening, scale-in, pyramid,
grid, martingale, hedge adjustment, or discretionary close.

## 6. Filters (No-Trade Module)

- Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, EA ID
  `41138`, and slots 0/1.
- Require `RISK_FIXED=1000`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact synchronized calendar month,
  history and close validity, pair enumeration/count, self-pair identity,
  sort/median arithmetic, spread ceilings, quotes, completed ATRs, sizing,
  notional mismatch, and atomicity fail closed.
- No fitted center, scale, z-score, regression, quantile threshold, moving
  average, oscillator, sign count, block vote, sequence count, range location,
  volume, open interest, event calendar, futures curve, external file, API, or
  manual runtime input is used.

## 7. Trade Management Rules

- Own either zero exposure or exactly one valid opposite-side two-leg package
  on registered magics and symbols.
- Flatten orphaned, duplicated, same-side, stopless, wrong-side, or notional-
  invalid exposure before considering a new entry.
- Leave both frozen server-side stops unchanged; do not trail, widen, partial-
  close, rebalance, reverse, scale, or pyramid.
- Close both survivors at the first later broker-month boundary; use the
  forty-day guard only when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 45 | bounded synchronized month buffer |
| `strategy_min_month_sessions` | 17 | minimum completed-month pairs/returns |
| `strategy_max_month_sessions` | 23 | maximum completed-month pairs/returns |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_max_pair_count` | 276 | exact bounded inclusive-pair array ceiling |
| `strategy_numerical_tolerance` | 1e-10 | endpoint/self-pair identity tolerance |
| `strategy_atr_period_d1` | 20 | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_pct` | 20.0 | atomic package validity ceiling |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | gold entry-cost guard |
| `strategy_xag_max_spread_points` | 500 | silver entry-cost guard |
| `strategy_deviation_points` | 20 | deterministic order deviation |
| `qm_friday_close_enabled` | false | full-month identity |

Every value is locked in the one logical baseline setfile and is not an
optimization surface.

## Source-Defined Rules

The source lineage supplies a related, state-dependent gold/silver carrier,
an official intermarket-spread interpretation, and already governed pairwise-
median arithmetic. It does not supply the daily-relative-return horizon,
contrarian direction, or execution contract.

## QM Interpretations

`SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01` fixes synchronized broker-
month labels, 17-to-23 pairs plus the older boundary, every relative return
ending in the month, inclusive pair enumeration, dynamic pair count, exact
odd/even median, contrarian sides, equal-notional aggregate fixed risk,
frozen ATR stops, atomic cleanup, one consumed attempt, and first-later-month
exit. These are pre-result falsification choices, not source claims.

## Framework Execution Overrides

Friday close is disabled because the approved lifecycle owns the complete
following broker month. Both news axes are OFF because no event input enters
the native completed-price hypothesis. The execution contract must be
declared explicitly during initialization.

## Exit Precedence

Kill switch and broker hard stops are authoritative. Broken-package repair and
later-month closure execute before any entry-only gate. The forty-day guard is
stale repair, not an alternative holding rule.

## Runtime Data Dependencies

Only registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 bars, current quotes and
spreads, symbol metadata, ATR, broker time, positions, deals, and terminal-
global attempt state are permitted. No external runtime data source exists.

## Risk

- Backtest mode only: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for the logical basket.
- Slots 0 and 1 use registered magics `411380000` and `411380001`.
- Position size comes from the V5 fixed-risk helper, equal target absolute USD
  notionals, and frozen completed-bar `3.5*ATR(20,D1)` stops; aggregate
  normalized stop risk cannot exceed the one fixed budget.
- Both news axes and Friday close are OFF.
- No live/demo/shadow/stress/optimization setfile is authorized.

Expected PF and drawdown fields are low-confidence planning priors, not source
claims or pass criteria. Q02 must retire at zero packages, below five
completed packages in a full scored post-warm-up year, with nonpositive
governed economics, or on any fidelity, determinism, risk, atomicity, or
lifecycle defect. Later Q09 alone decides portfolio overlap.

## Kill Criteria

- Reject current-month leakage, unsynchronized timestamps, a truncated prior
  month, missing older boundary, session count outside 17-23, nonpositive
  close, invalid log ratio/return, endpoint mismatch, omitted or duplicated
  pair, wrong inclusive bounds, wrong dynamic count, invalid self-pair,
  unsorted array, wrong odd/even median, or nonfinite/zero signal.
- Fail wrong-side entry, retry after consumption, orphaned/same-side/stopless
  exposure, aggregate-risk breach, notional mismatch above 20%, or exit after
  the next broker-month boundary except documented stale repair.
- Retire below five completed packages in any full scored post-warm-up year,
  at zero trades, on nonpositive governed economics, or later correlation
  rejection.
- Do not rescue failure by changing sample, pair convention, median, side,
  stop, hold, carrier, threshold, risk, retry, or adding another state.

## Strategy Allowability Check

- [x] R1: peer-reviewed gold/silver relation, official exchange carrier, and
  governed arithmetic precedent; translation risk explicit.
- [x] R2: exact clock, sample, returns, pairs, median, sides, attempt, risk,
  stops, atomicity, and lifecycle.
- [x] R3: registered synchronized XAU/XAG D1 history and native inputs only.
- [x] R4: deterministic native arithmetic; no trained or banned signal.
- [x] Dedup: no exact identity; one fuzzy central-band neighbor manually
  resolved as a different robust-location functional.

## Framework Alignment

- no_trade: exact symbols/D1/EA/slots, locked inputs, fixed risk/news/Friday
  contract, cheap parameter guards, and broken-package repair precedence.
- trade_entry: month attempt, synchronized package, daily relative returns,
  endpoint identity, inclusive pairwise averages, exact median, spread/quote/
  ATR/stop checks, equal-notional sizing, and atomic two-leg submission.
- trade_management: malformed-state repair and paired month/stale lifecycle
  before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, branch-only
build, strict compile/Q01, and one paced non-live logical-basket Q02 handoff.
It does not authorize manual backtesting; live, demo, shadow, optimization, or
stress presets; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio
admission; portfolio-gate edits; or correlation waivers.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-24 | initial source-bounded XAU/XAG daily pseudomedian basket | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-24 | APPROVED | `decisions/2026-08-24_qm5_41138_xauxag_monthly_daily_hodges_lehmann_reversion_g0.md` |
| Q01 Build Validation | - | NOT_BUILT | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | - |
