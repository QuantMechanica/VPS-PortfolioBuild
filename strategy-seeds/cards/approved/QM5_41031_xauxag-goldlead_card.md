---
card_schema_version: 2
type: strategy
strategy_id: KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026_S01
variant_id: KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026_S01
source_id: KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026
ea_id: QM5_41031
slug: xauxag-goldlead
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41031_xauxag-goldlead_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_xauxag_gold_lead_lag_g0.md
source_approval: decisions/2026-08-16_xauxag_gold_lead_lag_source_approval.md
source_author: "Monika Krawiec; Anna Gorska; Karsten Schweikert; CME Group"
source_authors: "Monika Krawiec; Anna Gorska; Karsten Schweikert; CME Group"
source_citation: "Krawiec and Gorska (2015), Granger Causality Tests for Precious Metals Returns, Quantitative Methods in Economics 16(2), 13-22; supporting carrier evidence in Schweikert (2018), Journal of Banking & Finance 88, 44-51, and CME Group gold/silver spread material."
source_citations:
  - type: academic_paper
    citation: "Krawiec, M., and Gorska, A. (2015). Granger Causality Tests for Precious Metals Returns. Quantitative Methods in Economics 16(2), 13-22."
    location: "Complete ten-page paper at https://qme.sggw.edu.pl/article/download/3763/3390/4072; complete-read evidence in strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026/source.md"
    quality_tier: A
    role: daily_gold_to_silver_predictive_ordering_and_reverse_direction_adverse_test
  - type: peer_reviewed_carrier_support
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed extraction strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relationship_and_adverse_constant_equilibrium_evidence
  - type: exchange_carrier_support
    citation: "CME Group. Gold & Silver Ratio Spread and related precious-metals spread material."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: intermarket_gold_silver_carrier
strategy_mechanic: synchronized-d1-one-completed-gold-shock-bounded-silver-underresponse-asymmetric-one-session-equal-notional-catchup-basket
sources:
  - "[[sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026]]"
concepts:
  - "[[concepts/precious-metals-lead-lag]]"
  - "[[concepts/cross-metal-catch-up]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, lead-lag, catch-up, market-neutral-basket, one-session-hold, atr-hard-stop, low-frequency, symmetric-gold-shock]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41031_XAU_XAG_GOLDLEAD_D1
symbol: XAUUSD.DWX
symbol_slot: 0
magic: 410310000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-30 completed XAU/XAG packages per full post-warm-up year after the 75 bp gold-shock, bounded silver-underresponse, synchronization, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 18
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a one-way gold-to-silver daily catch-up package outside the directional certified XAU/SP500/NDX/XNG book. Verify completed-return ordering, gold-only leadership, bounded silver response, no current-bar leakage, atomic equal-notional sizing, and first-next-D1 flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [synchronized_d1_endpoints, gold_to_silver_direction_only, completed_bar_signal, fixed_thresholds, daily_attempt_state, no_current_bar_leakage, no_late_restart_entry, aggregate_fixed_risk, equal_notional_pair, orphan_rollback, first_next_d1_exit, risk_mode_dual, friday_close_enabled, cfd_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete-read academic gold-to-silver daily causality plus governed peer-reviewed/exchange carrier evidence with translation risk disclosed; R2 fixed synchronized return, threshold, direction, timing, package, risk and exit contract; R3 native XAU/XAG D1; R4 deterministic ML-free arithmetic; exac"
---

# QM5_41031 XAU/XAG Asymmetric Gold-Lead Catch-Up

## Hypothesis

Daily gold returns may contain information that silver has not yet fully
reflected. When a completed gold move is at least 75 basis points and the
synchronized silver move remains less than one-half as large in gold's
direction, the next D1 session may contain a relative silver catch-up. The EA
buys the lagging silver leg and sells gold after an upward gold lead, reverses
both legs after a downward gold lead, and closes the package at the first next
D1 boundary.

This is a falsifiable one-day relative-value translation. The source reports
predictive ordering, not coefficient signs, trading returns, a 75 bp threshold,
or a profitable convergence rule. Equal notional reduces first-order USD
directional exposure but does not establish beta neutrality, market neutrality,
or low portfolio correlation.

## Source Traceability And Claim Boundary

The sole canonical lineage is
`strategy-seeds/sources/KRAWIEC-SCHWEIKERT-XAUXAG-GOLDLEAD-2026/source.md`,
approved before card extraction in
`decisions/2026-08-16_xauxag_gold_lead_lag_source_approval.md` at commit
`f4aa2f4c7`.

Krawiec and Gorska use daily London USD closes from 2008-2013. Their paper
reports positive gold/silver return correlation and rejects no-causality from
gold returns to silver returns at 1, 5, and 10 lags, while the reverse
direction is not rejected. The paper does not show the coefficient signs, so
same-direction silver catch-up is a QM hypothesis. Schweikert supplies adverse
evidence against a universal constant gold/silver equilibrium. CME supports
the two-metal intermarket carrier.

The exact CFD symbols, completed-return formula, shock floor, under-response
fraction, absolute-response cap, entry grace, no-retry ledger, equal-notional
sizing, aggregate fixed risk, stops, spread ceilings, first-next-D1 exit, and
Friday/stale repair are disclosed QM choices. No source performance,
coefficient, density, drawdown, transaction cost, CFD equivalence, neutrality,
decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,518 registry rows and 614
root-card files and returned no exact or fuzzy match. Manual review fixes the
load-bearing boundaries:

- `QM5_12577_cme-xauxag-ratio`, `QM5_20157_xau-xag-ratio`,
  `QM5_20161_xauxag-ols-rv`, `QM5_20263_xauxag-mad-rv`,
  `QM5_20268_xauxag-qtail-rv`, and `QM5_21526_xau-xag-cadf` estimate a
  ratio/residual level, center, scale, regression, tail, or stationarity
  state. This card uses one completed return per metal and estimates none.
- `QM5_20275_gsr-runfade` counts five same-sign relative returns and waits for
  a counter-return. This card uses one asymmetric gold-led event and no run.
- `QM5_20249_xauxag-vr-spread` and `QM5_20254_xauxag-vr-fade` estimate
  multiweek return memory. This card has no variance-ratio or regime state.
- XAU/XAG cross-sectional momentum, higher-moment, and seasonal cards make
  monthly decisions from longer samples. This card is one-day formation and
  one-session holding.
- `QM5_41030_xauxag-flowdiv` compares weekly relative close-to-open versus
  open-to-close flows and holds Monday-Friday. This card has no open price,
  information-time split, weekly aggregation, Monday selector, or Friday
  lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not a two-leg causal-ordering package.

Verdict:
`CLEAN_XAUXAG_ASYMMETRIC_GOLD_LEAD_SILVER_CATCHUP_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, planned magic `410310000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, planned magic
  `410310001`.
- Logical Q02 symbol: `QM5_41031_XAU_XAG_GOLDLEAD_D1`.
- Decision: first executable tick of each synchronized broker D1 session.
- Formation: exactly one completed close-to-close return per metal.
- Normal exit: first subsequent XAU D1 boundary, both legs together.
- Expected cadence: approximately 10-30 completed packages/year.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized baseline. No ratio z-score,
moving center, regression, VAR fit, stationarity test, quantile, oscillator,
trend, volatility regime, calendar selector, external feed, or parameter
sweep is authorized.

### 4. Entry Rules

1. Evaluate the entry path only after the framework observes a new
   `XAUUSD.DWX` D1 bar.
2. Require the broker date and current XAU D1 date to match. Require current
   XAU and XAG D1 timestamps to match exactly.
3. Derive the attempt key from the exact broker date. Persist it before
   history, signal, news, spread, quote, ATR, sizing, or order gates. Never
   retry that broker date after any flat, blocked, rejected, stopped, or
   partially opened outcome.
4. Require the first observed tick within 180 minutes of the current host D1
   open. A late attachment consumes the date and primes the framework D1 edge
   so restart cannot manufacture an entry.
5. Read exactly two immediately completed XAU D1 bars and the synchronized
   XAG bars. Require positive finite closes, exact cross-symbol timestamps,
   strictly descending time, and a gap from the current bar to the newest
   completed bar no longer than four calendar days.
6. Compute only completed log returns:
   `g = ln(XAU_close[1]/XAU_close[2])` and
   `s = ln(XAG_close[1]/XAG_close[2])`. The current D1 price enters neither
   return.
7. Positive gold lead: require `g >= 0.0075`, `s < 0.50*g`, and
   `abs(s) <= abs(g)`. SELL XAU and BUY XAG.
8. Negative gold lead: require `g <= -0.0075`, `s > 0.50*g`, and
   `abs(s) <= abs(g)`. BUY XAU and SELL XAG.
9. Exact response equality, `abs(g) < 0.0075`, a completed or
   excessive silver response, invalid arithmetic, and every other state
   consume the date flat. Silver never leads gold. Signal magnitude never
   scales risk.
10. Require valid completed-bar `ATR(20,D1)` for both legs. Place frozen hard
    stops at `3.0 * ATR`; use no take-profit.
11. Require no owned leg or same-date owned entry deal, valid quotes and
    symbol metadata, and no genuinely positive spread above 1,500 points on
    either leg. A modeled zero `.DWX` spread is valid.
12. Solve volumes jointly so the two legs target equal USD notionals after
    rounding down, reject mismatch above 20%, and keep combined frozen-stop
    loss at or below one `RISK_FIXED=1000` budget.
13. Open the XAU host leg and then the XAG companion leg. If either open fails
    or the finished package is malformed, close every surviving owned leg and
    consume the date. No pending order, retry, scale-in, grid, martingale, or
    pyramid exists.

### 5. Exit Rules

1. Close both legs at the first observed XAU D1 bar whose open timestamp is
   later than the package entry time. This is the ordinary one-session exit.
2. Framework Friday close remains enabled and closes both owned legs at broker
   hour 21 as a fail-safe, including a Friday entry before the ordinary next
   D1 boundary.
3. Close both legs after three elapsed calendar days as a stale guard.
4. Immediately close malformed, orphaned, duplicated, same-side, wrong-magic,
   wrong-symbol, zero-stop, zero-volume, invalid-entry-time, or over-mismatch
   owned exposure.
5. The frozen broker hard stops and framework kill switch remain authoritative.
6. No target, ratio-center exit, opposite signal, trail, break-even move,
   partial close, discretionary close, or Friday-close override is authorized.

### 6. Filters (No-Trade Module)

- Exact chart symbol `XAUUSD.DWX`; exact period D1; EA ID 41031; host slot 0.
- Companion input is locked to exact `XAGUSD.DWX` and slot 1.
- Framework kill switch, ownership checks, and Friday close remain
  authoritative.
- Both news axes are OFF because the signal uses completed native prices and
  the fixed one-session lifecycle must not be altered by an event mode.
- Synchronization, attachment grace, completed history, quote, ATR, metadata,
  spread, notional, and fixed-risk arithmetic must all be valid.
- Every fallible entry gate occurs after attempt persistence. No same-date
  retry or late backfill is allowed.

### 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under magic `410310000` and one
  `XAGUSD.DWX` position under magic `410310001`, or own none.
- The two legs must have opposite sides, positive frozen stops, and no more
  than 20% actual entry-notional mismatch.
- Run malformed/orphan repair and normal/stale lifecycle checks every tick
  before entry-only filters.
- Freeze both original broker hard stops; never widen, trail, or remove them.
- Do not add, pyramid, grid, partially close, reverse, or treat either leg as
  standalone exposure.
- Persist the last attempted broker-date key in terminal global state.
- Recover package entry time from owned positions after restart; never infer a
  new entry from existing exposure.

## Risk

- Backtest mode only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- The one fixed-dollar budget belongs to the logical package, not to each leg.
- Baseline stops: `3.0 * ATR(20,D1)` from completed data on each leg.
- Volumes target 1:1 USD notional, round down to broker steps, and must remain
  within 20% mismatch while combined normalized stop risk stays at or below
  1.0 package budget.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, contract size, volume step,
  minimum volume, or joint solve consumes the date without a package.
- CFD basis, gold/silver beta drift, financing, gaps, legging, and residual
  notional exposure are material risks. Approximate equal notional is not a
  neutrality claim.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_entry_grace_minutes` | 180 | restart-safe D1 boundary |
| `strategy_gold_shock_abs_return` | 0.0075 | minimum absolute completed gold log return |
| `strategy_silver_response_fraction` | 0.50 | maximum directional silver response fraction |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | XAU:XAG USD notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | post-rounding package guard |
| `strategy_max_hold_days` | 3 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | host entry cost guard |
| `strategy_xag_max_spread_points` | 1500 | companion entry cost guard |
| `friday_close_enabled` | true | package fail-safe exit |
| `friday_close_hour_broker` | 21 | fail-safe exit clock |

No parameter sweep, after-result threshold change, silver-led reversal,
ratio/residual overlay, carrier change, or lifecycle rescue is authorized.

## Data Requirements

- Native synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 close/time history from
  registered factory routes.
- Native current quotes, ATR readers, symbol properties, broker clock,
  position state, deal history, and terminal global variables.
- One logical basket manifest binding host slot 0 and companion slot 1 to the
  same D1 setfile and synchronized Q02 window.
- No external market-data API, futures curve, COT positioning, macro series,
  news-as-signal feed, CSV, VAR coefficients, trained model, or manually
  maintained event calendar.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/input contract | No Trade | `Strategy_NoTradeFilter` plus fail-closed `OnInit` |
| attempt, synchronization, completed returns, asymmetric direction, spread, ATR, joint sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic basket helpers |
| pair integrity, next-D1 exit, Friday/stale repair | Trade Management | `Strategy_ManageOpenPosition` on every tick |
| no separate single-ticket exit | Trade Close | `Strategy_ExitSignal` remains false; paired manager owns closes |
| kill switch and fixed risk | Framework No-Trade | standard framework orchestration plus foreign-magic registration |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both axes OFF |

## Kill Criteria

Retire rather than tune when any of the following occurs:

- fewer than five completed logical packages per full post-warm-up year;
- zero trades or nonpositive governed economics;
- any silver-to-gold predictive direction or current-bar price leakage;
- entry below the exact gold threshold or outside the bounded silver-response
  state;
- unsynchronized completed timestamps or use of more/fewer than two completed
  closes per metal;
- entry after the 180-minute grace or more than one attempt per broker date;
- wrong package sides, a standalone leg, excess notional mismatch, or combined
  risk above one fixed budget;
- survival beyond the first next D1 boundary/Friday/stale lifecycle without
  repair;
- wrong risk mode, nondeterministic result, or registry/magic mismatch.

No weak result may be rescued by fitting coefficients, moving either
threshold, changing the hold, dropping XAU, allowing silver leadership, or
adding a ratio, trend, volatility, seasonal, or news filter.

## Validation Plan

Q01 must prove:

1. synchronized current and completed timestamps accept only the intended two
   completed close pairs and reject cross-symbol mismatch;
2. positive and negative gold-threshold boundary cases map to exact opposite
   leg sides, while response equality and every non-lead state remain flat;
3. current D1 prices cannot enter either return;
4. silver never predicts gold and the absolute-response cap rejects an
   opposite extreme;
5. the persistent broker-date attempt prevents retry after every downstream
   failure and restart;
6. the joint solve targets equal notionals, rounds down, respects the 20%
   mismatch guard, and consumes at most one fixed stop budget;
7. second-leg failure immediately rolls back the host leg;
8. the first next XAU D1 boundary closes both legs, with Friday and three-day
   guards independently reachable;
9. malformed, orphaned, same-side, and over-mismatch packages repair before
   entry gates; and
10. card lint, source traceability, manifest validation, reference tests,
    strict compile/build checks, setfile schema, magic resolver, and static
    Q01 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial asymmetric gold-lead card extraction | G0 | APPROVED |
| v1-build | 2026-08-16 | deterministic gold-lead logical-basket implementation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-16 | APPROVED | `decisions/2026-08-16_xauxag_gold_lead_lag_g0.md` |
| Q01 Build Validation | 2026-08-16 | PASS | `D:/QM/reports/framework/21/build_check_20260816_211706.json` |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, strict Q01 validation, one
logical D1 `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU
capacity permits. It does not authorize a manual tester launch,
live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a deploy
or T_Live manifest, portfolio-gate change, portfolio admission, neutrality
claim, or correlation waiver.
