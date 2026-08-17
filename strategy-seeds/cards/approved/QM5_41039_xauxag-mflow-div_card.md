---
card_schema_version: 2
type: strategy
strategy_id: WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01
variant_id: WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026_S01
source_id: WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026
ea_id: QM5_41039
slug: xauxag-mflow-div
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41039_xauxag-mflow-div_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_g0.md
source_approval: decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_source_approval.md
source_author: "Larry R. Williams; Karsten Schweikert; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_authors: "Larry R. Williams; Karsten Schweikert; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; CME Group"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Schweikert (2018), Journal of Banking & Finance 88, 44-51; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction strategy-seeds/sources/SRC03/source.md; Pro-Go close/open decomposition in raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed packets strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md and SCHWEIKERT-QC-2018/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relationship
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: pooled_commodity_one_month_formation_and_hold_lineage
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: precious_metals_intermarket_carrier
strategy_mechanic: exact-immediately-completed-broker-month-synchronized-xau-minus-xag-close-open-and-open-close-relative-log-flow-strict-opposition-follow-session-next-month-equal-notional-basket
sources:
  - "[[sources/WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026]]"
concepts:
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/logical-basket]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, relative-value, price-flow-decomposition, monthly-flow-divergence, logical-basket, monthly-entry, monthly-hold, atr-hard-stop, low-frequency]
markets: [commodities, precious_metals, gold, silver]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41039_XAU_XAG_MFLOWDIV_D1
symbol: QM5_41039_XAU_XAG_MFLOWDIV_D1
host_symbol: XAUUSD.DWX
symbol_slot: 0
magic: 410390000
companion_symbol: XAGUSD.DWX
companion_symbol_slot: 1
companion_magic: 410390001
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed XAU/XAG packages per full post-warm-up year after synchronized month, strict relative-flow opposition, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_DISCLOSED_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
review_focus: "Falsify a synchronized XAU/XAG monthly relative-flow-divergence package outside the directional certified XAU/SP500/NDX/XNG book. Verify every completed close/open endpoint, cross-metal subtraction, strict opposition, session-relative sides, basket atomicity, and next-month flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [immediately_completed_broker_month, synchronized_history, completed_close_open_endpoints, cross_metal_subtraction, strict_relative_flow_opposition, session_relative_direction, flow_reconciliation, monthly_decision_clock, monthly_attempt_state, no_current_bar_leakage, no_late_restart_entry, basket_atomicity, aggregate_fixed_risk, notional_mismatch, magic_schema, paired_month_rollover, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete OWNER-supplied Tier-A flow decomposition plus peer-reviewed and exchange gold/silver carrier lineage and complete-read peer-reviewed monthly commodity lineage with disclosed conjunction risk; R2 exact month, synchronization, endpoints, subtraction, opposition, reconciliation, sides, attempt, timing, joint sizing, atomicity, and lifecycle; R3 native synchronized XAU/XAG D1 only; R4 deterministic arithmetic without a banned signal or trained logic; canonical dedup raised only the expected weekly family neighbor and manual review fixed all cadence, carrier, and state boundaries."
---

# QM5_41039 XAU/XAG Monthly Relative-Flow Divergence

## Hypothesis

Gold and silver share broad precious-metal drivers but react differently to
monetary, safe-haven, and industrial information. When their completed prior-
month close-to-open relative flow points against their open-to-close relative
flow, the session component may contain a cleaner relative directional signal
than the overnight displacement. The candidate follows that session-relative
side with opposite XAU/XAG legs through the next broker month.

This is a falsifiable price-flow, relative-value, and calendar translation.
The opposite legs and equal-notional target suppress some common precious-
metal direction, but they do not prove dollar, beta, volatility, factor,
market, or portfolio neutrality.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/WILLIAMS-SCHWEIKERT-MOP-XAUXAG-MFLOWDIV-2026/source.md`,
approved before card extraction in
`decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_source_approval.md`
at commit `cf8667151`.

Williams supplies the prior-close-to-open and open-to-close daily price-flow
objects and discusses their separate accumulation and divergence. Schweikert
supplies a state-dependent gold/silver relationship with adverse evidence
against a constant automatically tradable equilibrium. CME supplies the
intermarket carrier. Moskowitz, Ooi, and Pedersen supply pooled commodity
one-month formation/hold lineage.

The all-session monthly sums, gold-minus-silver subtraction, strict
disagreement, session-following direction, exact synchronized Darwinex CFDs,
new-month grace, next-month lifecycle, equal-notional constraint, fixed-dollar
risk, hard stops, spread caps, and attempt ledger are disclosed QM choices.
No source return, alpha, coefficient, significance, density, drawdown, cost,
neutrality, CFD equivalence, decorrelation, or portfolio result transfers.

## Source-Defined Rules And QM Interpretations

- Williams defines prior-close-to-open and open-to-close information-time
  components and treats divergence between accumulated lines as potentially
  informative.
- Schweikert and CME support a state-dependent gold/silver intermarket carrier
  but do not establish a fixed tradable equilibrium.
- Moskowitz, Ooi, and Pedersen define a commodity one-month formation/hold
  family but not this relative component state.
- The synchronized broker-month selector, relative subtraction, opposition
  gate, session-following direction, exact CFD mapping, attempt timing,
  aggregate fixed risk, equal-notional solve, ATR stops, and paired lifecycle
  are pre-result QM mechanizations, not source findings.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,526 EA-registry rows and
623 root-card files. It found no exact identity and one expected fuzzy family
neighbor. Manual review fixes the load-bearing boundaries:

- `QM5_41030_xauxag-flowdiv` uses one exact prior Monday-Friday week, enters
  next Monday, and flattens Friday. This card consumes every synchronized
  session in one immediately completed broker month, decides only at a
  new-month boundary, and holds to the next month.
- `QM5_41037_xng-mflow-div` is one directional XNG leg. This card requires a
  synchronized gold-minus-silver logical basket with two registered magics.
- `QM5_20057_xauxag-xmom1`, `QM5_20050_xauxag-xmom12`, and
  `QM5_20184_xauxag-xmom3` rank close-to-close return horizons and follow the
  stronger metal. This card admits only opposed close/open relative
  components and follows session-relative flow, which can oppose the total
  relative-return sign.
- Ratio, OLS, MAD, empirical-tail, failed-break, seasonal-surprise, and CADF
  systems trade relative levels or fitted residuals. This card estimates no
  ratio level, center, scale, regression, quantile, or stationarity state.
- `QM5_41031_xauxag-goldlead` uses one gold-led completed daily shock and a
  one-session catch-up hold. This card uses every prior-month interval and a
  next-month lifecycle.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback,
  not an information-time logical basket.

Verdict:
`CLEAN_XAUXAG_MONTHLY_RELATIVE_FLOW_DIVERGENCE_AFTER_CADENCE_CARRIER_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Logical basket: `QM5_41039_XAU_XAG_MFLOWDIV_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `410390000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `410390001`.
- Decision clock: first executable synchronized D1 tick of a new broker
  month, within 180 minutes of the shared D1 open.
- Formation: every synchronized completed session of the immediately prior
  broker month plus the preceding month-end close anchor.
- Normal exit: both legs at the first observed synchronized host D1 boundary
  whose broker month differs from the package-entry month.
- Expected cadence: approximately 5-8 completed packages/year.

For each synchronized completed prior-month session `d`:

```text
xau_overnight[d] = ln(XAU_open[d] / XAU_close[prior_session])
xag_overnight[d] = ln(XAG_open[d] / XAG_close[prior_session])
xau_session[d]   = ln(XAU_close[d] / XAU_open[d])
xag_session[d]   = ln(XAG_close[d] / XAG_open[d])

overnight_relative = sum(xau_overnight[d] - xag_overnight[d])
session_relative   = sum(xau_session[d]   - xag_session[d])
```

## Rules

The rules below are the complete authorized baseline. No ratio-level,
magnitude, volatility, season, weekday, event, curve, volume, oscillator,
range, breakout, regression, quantile, stationarity, or external-data signal
filter is authorized.

## 4. Entry Rules

1. Evaluate the entry path only on a new `XAUUSD.DWX` D1 bar while attached to
   exact `XAUUSD.DWX`, D1, EA ID 41039, slot 0.
2. Process orphan, malformed-package, wrong-side, duplicate, stale, and
   next-month exits before every entry-only gate.
3. Require the broker date and current XAU D1 date to match. Require current
   XAU and XAG D1 timestamps to match exactly and their shared date to equal
   the broker date. No label shift or per-bar repair is allowed.
4. Detect a new broker month only when the newest completed synchronized bar
   belongs to the immediately prior consecutive month. Any already completed
   current-month bar means attachment is late.
5. Derive the attempt key from the exact broker `yyyymm`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that month.
6. Require elapsed time from the synchronized D1 open to be between zero and
   180 minutes. A later attachment consumes the attempt and never backfills.
7. Starting at shift 1, collect every completed synchronized bar belonging to
   the immediately prior month. Require 15-25 such sessions and the next older
   synchronized bar to belong to the preceding consecutive month.
8. Require exact cross-symbol timestamp equality at every consumed shift,
   strict newest-to-oldest timestamp order, and positive finite open/close
   values for both metals. The next older bar supplies only the preceding
   month-end close anchor.
9. For every prior-month session, compute each metal's close-to-open and
   open-to-close log returns from completed bars only. The oldest session uses
   the synchronized anchor closes as prior closes.
10. Compute the gold-minus-silver overnight-relative and session-relative sums
    exactly as defined above. The current month bar enters neither sum.
11. Require each metal's component total to reconcile within `1e-10` to its
    anchor-to-prior-month-end log return. Require the relative total to
    reconcile within `1e-10` to XAU month return minus XAG month return.
12. If `session_relative > 0` and `overnight_relative < 0`, BUY XAU and SELL
    XAG. If `session_relative < 0` and `overnight_relative > 0`, SELL XAU and
    BUY XAG. Agreement, exact zero, invalid arithmetic, or failed
    reconciliation consumes the month.
13. Require valid completed-bar `ATR(20,D1)` for both legs. Place frozen
    per-leg hard stops at `3.5 * ATR`; use no take-profit.
14. Target equal absolute USD notionals, round volumes down only, reject
    notional mismatch above 20%, and scale the package so combined stop loss
    does not exceed one `RISK_FIXED=1000` budget.
15. Require valid quotes and no genuinely positive spread above 1,500 points
    on either leg. Modeled zero `.DWX` spread is valid.
16. Submit both market legs once. If either fails, immediately close every
    survivor and consume the month. No pending order, retry, scale-in, grid,
    martingale, pyramid, or standalone leg exists.

## 5. Exit Rules

1. Close both legs together at the first observed XAU D1 boundary whose
   broker month differs from the package entry month.
2. Close both legs after 40 elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, same-direction, wrong-symbol,
   wrong-magic, missing-stop, invalid-volume, invalid-entry-time, or
   over-mismatch package.
4. Per-leg frozen hard stops and the framework kill switch remain
   authoritative. If one leg disappears, close the other immediately.
5. Framework Friday close is disabled because the source hold is one broker
   month and the paired rollover is load-bearing.
6. No target, opposite-flow exit, trailing stop, break-even move, partial
   exit, discretionary close, or Friday override is authorized.

## 6. Filters (No-Trade Module)

- Exact host `XAUUSD.DWX`, companion `XAGUSD.DWX`, D1 period, EA ID 41039,
  slot 0, and locked input values.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices and a fixed
  monthly lifecycle.
- Friday close is OFF and must remain off.
- Current and completed D1 histories must be exactly synchronized.
- Month identity, history, opening grace, quotes, spreads, ATR, sizing,
  reconciliation, and hedge mismatch must be valid.
- Failure at any fallible entry gate after attempt persistence consumes the
  broker month.

## 7. Trade Management Rules

- Own at most one logical package: one XAU position under magic `410390000`
  and one XAG position under magic `410390001` in opposite directions.
- Freeze both original broker hard stops; never widen, trail, or remove them.
- Run malformed, orphan, next-month, and stale repair on every tick before
  entry logic.
- If one leg exits or disappears, close the other immediately.
- Persist the last attempted broker-month key in terminal global state so a
  restart cannot create a second monthly attempt.
- Recover package entry time from owned positions after restart; never infer a
  new entry from existing exposure.
- Do not add, pyramid, grid, hedge beyond the defined companion leg, partially
  close, or reverse an owned package.

## Risk

- Backtest only: one logical package `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- The combined frozen-stop loss of both legs must not exceed the one package
  budget after volume rounding.
- Target equal absolute USD notionals and reject post-rounding mismatch above
  20%. This suppresses common metal direction but proves no neutrality.
- Baseline hard stop on each leg: `3.5 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, contract size, volume step,
  minimum volume, computed lot, or package mismatch consumes the month.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_min_prior_month_bars` | 15 | minimum complete sessions |
| `strategy_max_prior_month_bars` | 25 | maximum complete sessions |
| `strategy_entry_grace_minutes` | 180 | restart-safe month boundary |
| `strategy_history_bars` | 90 | bounded D1 retrieval buffer |
| `strategy_reconcile_tolerance` | 1e-10 | per-metal and relative identity |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg hard-stop distance |
| `strategy_xau_max_spread_points` | 1500 | host entry cost guard |
| `strategy_xag_max_spread_points` | 1500 | companion entry cost guard |
| `strategy_max_notional_mismatch_pct` | 20.0 | post-rounding hedge guard |
| `strategy_max_hold_days` | 40 | stale repair only |
| `qm_friday_close_enabled` | false | preserve month hold |
| `qm_friday_close_hour_broker` | 21 | inert locked framework input |

No parameter sweep, after-result threshold, flow-sign, side, month,
component, hedge, or lifecycle change is authorized by this card.

## Data Requirements

- Native synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 OHLC and timestamps
  from the registered factory history route.
- Native broker clock, symbol quotes/properties, ATR inputs, positions, deal
  history, and terminal global variables.
- One logical basket manifest binding host slot 0 and companion slot 1 to the
  same D1 setfile and synchronized Q02 window.
- No external market-data API, futures curve, inventory, COT, macro series,
  news-as-signal feed, CSV, fitted coefficients, trained model, or manually
  maintained event calendar.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/input contract | No Trade | `Strategy_NoTradeFilter` plus fail-closed `OnInit` |
| attempt, synchronized month, component arithmetic, opposition, reconciliation, spread, ATR, joint sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic basket helpers |
| pair integrity, next-month exit, and stale repair | Trade Management | `Strategy_ManageOpenPosition` on every tick |
| no separate single-ticket exit | Trade Close | `Strategy_ExitSignal` remains false; paired manager owns closes |
| kill switch and aggregate fixed risk | Framework No-Trade | standard framework orchestration plus foreign-magic registration |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both axes OFF |

## Framework Execution Overrides

- Declare `PERIOD_D1` as the sole execution timeframe.
- Declare `QM_FRIDAY_CLOSE_DISABLED` because a broker-month hold is a card
  rule, not an omission.
- Register companion magic `410390001` as owned foreign-symbol exposure.
- Keep framework kill switch, equity stream, MAE tracking, risk sizer, stop
  normalization, and transaction instrumentation active.

## Exit Precedence

1. Framework kill switch.
2. Malformed, duplicate, or orphaned package repair.
3. First next broker-month boundary.
4. Forty-calendar-day stale guard.
5. Per-leg broker hard stops.

## Runtime Data Dependencies

All signal and execution inputs are MT5-native. The EA may not load an
external file, call an external market-data service, import a trained output,
or reconstruct a futures roll series at runtime.

## Falsification And Requalification

The baseline is a new monthly logical-basket hypothesis, not a rescue or
optimization of weekly `QM5_41030`. A Q02 failure retires this identity. Any
later change to component eligibility, formation month, decision clock,
direction, hold, threshold, or filter needs a new source packet, dedup review,
strategy ID, card, and EA ID.

## Kill Criteria

Retire rather than tune when any of the following occurs:

- fewer than five completed logical packages per full post-warm-up year;
- zero trades or nonpositive governed economics;
- any signal endpoint from the current month/live bar;
- wrong or nonconsecutive month identity, cross-symbol timestamp mismatch, or
  late entry;
- entry when relative components agree or either is zero;
- direction different from the exact session-relative sign;
- failed per-metal or relative reconciliation;
- repeated monthly entry, wrong rollover exit, missing hard stop, invalid risk
  mode, or nondeterminism;
- a standalone leg, excess notional mismatch, combined risk above one fixed
  budget, or orphan survival; or
- failure of later robustness or portfolio gates. No correlation waiver is
  permitted.

No weak result may be rescued by changing the month, admitting agreement,
following overnight or total flow, adding a threshold/filter, changing the
hold, dropping one leg, or adding a ratio, trend, volatility, seasonal, or
news filter.

## Validation Plan

Q01 must prove:

1. current and completed timestamps accept only exact synchronized D1 history
   and reject any cross-symbol mismatch;
2. month detection accepts only the first D1 boundary after one immediately
   completed consecutive broker month and rejects late attachment;
3. 15/25 session boundaries, anchor identity, timestamp order, and positive
   finite OHLC values fail closed;
4. component arithmetic uses every completed prior-month interval and no
   current-bar price;
5. per-metal and relative telescoping identities pass at `1e-10` and each
   independent failure is rejected;
6. positive/negative strict opposition maps to exact opposite leg sides while
   agreement and zero remain flat;
7. the persistent broker-month attempt prevents retry after every downstream
   failure and restart;
8. the joint solve targets equal notionals, rounds down, respects the 20%
   mismatch guard, and consumes at most one fixed stop budget;
9. second-leg failure immediately rolls back the host leg;
10. the first next-month D1 boundary closes both legs, with orphan and 40-day
    guards independently reachable; and
11. card lint, source traceability, manifest validation, reference tests,
    strict compile/build checks, setfile schema, magic resolver, and static
    Q01 validation pass.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial monthly XAU/XAG relative-flow-divergence card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_xauxag_monthly_relative_flow_divergence_g0.md` |
| Q01 Build Validation | - | PENDING_BUILD | deterministic implementation and validation required |
| Q02 Baseline Screening | - | NOT_ENQUEUED | paced capacity gate required after Q01 PASS |

## Safety Boundary

This card authorizes a branch-only non-live build, strict Q01 validation, one
logical D1 `RISK_FIXED` backtest setfile, and one paced Q02 enqueue if CPU
capacity permits. It does not authorize a manual tester launch,
live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, a deploy
or T_Live manifest, portfolio-gate change, portfolio admission, neutrality
claim, or correlation waiver.
