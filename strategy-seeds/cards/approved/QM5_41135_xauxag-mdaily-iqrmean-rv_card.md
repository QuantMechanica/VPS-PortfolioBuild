---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026
ea_id: QM5_41135
slug: xauxag-mdaily-iqrmean-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41135_xauxag-mdaily-iqrmean-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41135_xauxag_monthly_daily_interquartile_mean_reversion_g0.md
source_approval: decisions/2026-08-23_xauxag_monthly_daily_interquartile_mean_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.html; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: intermarket_spread_carrier_and_driver_difference
strategy_mechanic: exact-synchronized-xau-xag-immediately-completed-broker-month-seventeen-to-twenty-three-daily-gold-minus-silver-log-ratio-returns-ascending-sort-floor-quarter-trim-each-tail-central-band-arithmetic-mean-sign-contrarian-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026]]"
concepts:
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/robust-within-month-relative-return-location]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-relative-return-interquartile-mean]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, structural-reversion, completed-month-daily-relative-return-interquartile-mean, robust-location-direction, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41135_XAU_XAG_MDAILY_IQRMEAN_RV_D1
symbol: QM5_41135_XAU_XAG_MDAILY_IQRMEAN_RV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411350000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG packages per full post-warm-up year after exact synchronization and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_IQR_LOCATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a completed-month gold/silver daily-relative-return interquartile-mean reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify exact synchronization, older boundary pair, every relative return ending in the month, endpoint identity, full ascending sort, floor(n/4) removal from both tails, exact retained membership, central arithmetic mean direction independent of the raw endpoint, contrarian equal-notional sides, one attempt, aggregate fixed risk, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, immediate_completed_calendar_month, synchronized_session_count, older_boundary_pair, chronological_relative_log_return_orientation, every_month_return_once, endpoint_identity, full_sample_ascending_sort, integer_quartile_tail_count, exact_retained_indexes, central_band_arithmetic_mean, raw_endpoint_not_a_gate, contrarian_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 PASS peer-reviewed gold/silver relation lineage plus official exchange carrier, with the within-month daily relative-return central-band estimator and contrarian direction disclosed as untested translations; R2 PASS exact synchronized month package, return inclusion, endpoint identity, full sort, integer trim, retained mean, sides, attempt, aggregate risk, atomicity, and lifecycle; R3 PASS registered native XAU/XAG D1 routes with synchronization and continuous-CFD basis risk; R4 PASS deterministic arithmetic without a trained or banned signal; canonical pre-allocation dedup CLEAN and manual family review separates fitted ratio/OLS/MAD, daily sign breadth, fixed blocks, path quotients, daily persistence, outright WTI interquartile momentum, and certified XNG RSI logic."
---

# QM5_41135 XAU/XAG Completed-Month Daily-Relative-Return Interquartile-Mean Reversion

## Hypothesis

Gold and silver share precious-metals and USD drivers but respond differently
to safe-haven, monetary, industrial, and business-cycle shocks. A completed
month's net ratio move can be dominated by a few extreme sessions. Fading the
mean of the central daily relative-return band after removing the integer
outer quartiles tests whether the ordinary intermetal displacement reverts in
the following broker month.

The opposite equal-notional legs are designed to reduce common outright-metal
direction and create a market-neutral-style return stream different from the
certified directional XAU, SP500, NDX, and XNG book. They do not prove dollar,
beta, volatility, factor, or portfolio neutrality. Q02 owns density and
baseline economics; unchanged Q09 alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026/source.md`,
SHA-256
`B6D9463B2F73A42998D1FDFB83CFFF552A78D455109369F2C1E2F7AD78D2D7AA`,
authorized before extraction by
`decisions/2026-08-23_xauxag_monthly_daily_interquartile_mean_reversion_source_approval.md`
at commit `2afaad159` and committed as a bounded packet at `c488b9c07`.

Schweikert supports testing a potentially state-dependent long-run gold/silver
relation. CME defines the ratio, the intermarket-spread carrier, and the two
metals' different economic drivers. Neither source tests a daily relative-
return interquartile mean inside one month, contrarian next-month sides,
Darwinex continuous CFDs, equal-notional fixed-dollar ATR risk, or the QM
book. Every horizon, estimator, direction, execution, and risk choice below is
a declared QM interpretation.

No source return, alpha, probability, density, profit factor, drawdown,
transaction cost, hedge ratio, neutrality, CFD equivalence, or correlation
statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,634 registry
identities, 1,302 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`.
Evidence is
`artifacts/qm5_xauxag_mdaily_iqrmean_rv_preallocation_dedup_20260823.json`.

Manual family review fixes the mechanical boundaries:

- rolling ratio, OLS, quantile, and MAD cards estimate a center, coefficient,
  scale, or threshold crossing. This card estimates none.
- `QM5_41112_xauxag-mdaybreadth-rv` counts daily signs, while fixed-block and
  sequence cards aggregate calendar sections or ordered states. This card
  sorts all relative-return magnitudes and averages an exact central band.
- `QM5_41123_xauxag-mpath-eff-rv` uses a net-to-L1 quotient,
  `QM5_41125_xauxag-mrms-coherence-rv` uses a net-to-L2 quotient, and
  `QM5_41128_xauxag-mdaily-persist-rv` uses adjacent demeaned-return products.
  None selects a dynamic order-statistic central band.
- `QM5_41134_wti-mdaily-iqrmean-mom` follows the analogous statistic on one
  outright WTI leg. This card applies it to a synchronized gold/silver
  relative series, fades the sign, and owns an atomic equal-notional package.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon single-symbol
  XNG oscillator pullback.

The paired carrier, exact completed month, older boundary pair, every relative
return ending in the month, full ascending sort, dynamic integer-quartile
tail removal, central-band mean, contrarian sides, durable attempt, equal-
notional aggregate-risk package, and next-month exit are jointly load bearing.
Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host: exact `XAUUSD.DWX`, D1, slot 0, magic `411350000`.
- Companion: exact `XAGUSD.DWX`, D1, slot 1, magic `411350001`.
- Logical symbol: `QM5_41135_XAU_XAG_MDAILY_IQRMEAN_RV_D1`.
- Decision: first synchronized executable tick of a new broker-calendar
  month, within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: exact immediately completed synchronized calendar month plus
  one adjacent older boundary pair; current-month prices are excluded.
- Position count: zero or one valid two-leg package and at most one consumed
  attempt per broker `yyyymm`.
- Expected frequency: eleven packages/year as an ordering prior within a
  10-12 design range; Q02 must prove at least five in every scored full year.

## Completed-Month Contract

The immediately preceding synchronized pair must belong to the prior calendar
month. Within a fixed 45-bar buffer, collect every completed D1 pair labeled
with that prior year and month. Require 17 through 23 unique timestamps in
strict order and one adjacent older synchronized pair proving that the
package was not truncated. A current-month pair, duplicate or mismatched
timestamp, wrong month, missing boundary proof, invalid close, or session
count outside 17-23 consumes the current month flat.

For older boundary ratio `s[-1]`, chronological completed-month ratios
`s[0]..s[n-1]`, and `n` relative returns:

```text
s[j] = ln(XAU_close[j]) - ln(XAG_close[j])
r[j] = s[j] - s[j-1], j=0..n-1
raw  = sum(r[j])

sorted = ascending(r[0], ..., r[n-1])
k = floor(n / 4)
m = n - 2*k
C = sum(sorted[i], i=k..n-k-1) / m

C > 0 => SELL XAU, BUY XAG
C < 0 => BUY XAU, SELL XAG
otherwise => FLAT
```

Require positive finite closes, finite ratios, returns and sums, `k` in
`[4,5]`, and `m` in `[9,13]`. Verify `raw` equals the direct log-ratio move
from the older boundary pair to the completed month's final pair within
`1e-10`. Exact-zero constituent returns are valid. A zero central mean,
endpoint mismatch, invalid retained membership, or invalid numerical state is
flat. Every relative return ending in the month contributes exactly once
before sorting. The raw endpoint is diagnostic only and cannot gate direction.

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
8. Sort the complete return array, remove exactly `floor(n/4)` observations
   from each tail, and average the exact retained indexes once.
9. Fade positive central mean with SELL XAU / BUY XAG and negative central
   mean with BUY XAU / SELL XAG. Equality and invalid state remain flat.
10. Require XAU spread no greater than 1,500 points, XAG spread no greater
    than 500 points, valid quotes, and valid completed-bar `ATR(20,D1)` on
    both legs.
11. Freeze one hard stop `3.5*ATR` from each leg's entry and use no target.
12. Size to equal target absolute USD notionals with combined normalized stop
    risk at or below the single aggregate `RISK_FIXED` budget. Reject a
    package whose realized notional mismatch exceeds 20%.
13. Submit the first leg then the second; if the second leg fails or the pair
    is malformed, close all owned exposure immediately. No same-month retry.

Central-mean and endpoint magnitudes never change the fixed risk budget or
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
  `41135`, and slots 0/1.
- Require `RISK_FIXED=1000`, `RISK_PERCENT=0`, valid stop inputs, news temporal
  OFF, news compliance NONE, and Friday close disabled.
- Framework kill switch, broker, and ownership controls remain authoritative.
- Apply entry grace, durable attempt, exact synchronized calendar month,
  history and close validity, sort/trim/mean arithmetic, spread ceilings,
  quotes, completed ATRs, sizing, notional mismatch, and atomicity fail closed.
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
| `strategy_trim_divisor` | 4 | integer tail-trim divisor |
| `strategy_min_retained_returns` | 9 | fail-closed retained-band floor |
| `strategy_numerical_tolerance` | 1e-10 | endpoint-identity tolerance |
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

The source lineage supplies a related, state-dependent gold/silver carrier and
an official intermarket-spread interpretation. It does not supply the daily-
relative-return horizon, integer trim, central-band direction, or execution
contract.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026_S01` fixes synchronized broker-
month labels, 17-to-23 pairs plus the older boundary, every relative return
ending in the month, full ascending sort, dynamic integer-quartile trimming,
contrarian sides, equal-notional aggregate fixed risk, frozen ATR stops,
atomic cleanup, one consumed attempt, and first-later-month exit. These are
pre-result falsification choices, not source claims.

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
- Slots 0 and 1 use registered magics `411350000` and `411350001`.
- Position size comes from the V5 fixed-risk helper, equal target absolute USD
  notionals, and frozen completed-bar `3.5*ATR(20,D1)` stops; aggregate
  normalized stop risk cannot exceed the one fixed budget.
- Both news axes and Friday close are OFF.
- No live/demo/shadow/stress/optimization setfile is authorized.

Expected PF and drawdown fields are low-confidence planning priors, not source
claims or pass criteria. Q02 must retire at zero packages, below five completed
packages in a full scored post-warm-up year, with nonpositive governed
economics, or on any fidelity, determinism, risk, atomicity, or lifecycle
defect.

## Kill Criteria

Retire at zero packages, below the ratified annual activity floor, nonpositive
governed economics, malformed logical-basket accounting, synchronization or
endpoint defects, inconsistent sort/trim membership, wrong sides, risk-budget
breach, same-month retry, partial-package survival, or nondeterminism.

## Strategy Allowability Check

The strategy is structural relative value using fixed arithmetic and native
completed prices. It contains no trained signal, banned indicator, external
runtime feed, discretionary input, grid, martingale, pyramid, or scale-in.

## Falsification And Requalification

No failure may be rescued by changing the sample, trim formula, direction,
carrier, hold, risk, or by adding endpoint agreement, a fitted center or
scale, sign count, calendar block, event, seasonal, volatility, external, or
prior-result state. Such a change requires a new source approval, card,
identity, and baseline.

## Framework Alignment

- no_trade: exact host/companion/period/ID/slots, registered magics, locked
  risk/news/Friday/strategy inputs, and fail-closed ownership state.
- trade_entry: synchronized month clock, consumed attempt, exact calendar
  package, chronological relative returns, endpoint identity, full sort,
  integer symmetric trim, retained arithmetic mean, contrarian sides,
  spreads/quotes/ATRs, equal-notional aggregate sizing, stops, and atomic open.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: basket close helper, broker hard stops, and kill switch.

## Validation Plan

Before Q02, require card lint, exact registry/magic alignment, a deterministic
reference suite for return orientation, endpoint identity, sorting, integer
trim, retained membership, direction, equal-notional sizing invariants, and
attempt state; spec validation; build guardrails; basket scope validation;
strict governed compile; and a hash-bound logical `RISK_FIXED` setfile. Q02 is
target-only and cannot run without strict Q01.

## Pipeline History

No backtest or portfolio result exists at G0. Source evidence and design
priors are not pipeline evidence.

## Pipeline Phase Status

- Q00/G0: APPROVED by the current explicit OWNER mission and this recorded
  deterministic review.
- Q01: PENDING_BUILD.
- Q02: NOT_ENQUEUED_Q01_PENDING.
- Q03+: NOT_STARTED.

## Safety Boundary

This card authorizes only one branch-local source build, strict compile/Q01,
and one paced target-only Q02 handoff when the CPU ceiling permits. It does not
authorize a manual backtest, live artifact, `T_Live`, AutoTrading, terminal
control, deploy manifest, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim. Q09 alone owns portfolio overlap.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-23 | approved source extraction | G0-approved card; QM5_41135 reserved; magics pending governed allocation |

