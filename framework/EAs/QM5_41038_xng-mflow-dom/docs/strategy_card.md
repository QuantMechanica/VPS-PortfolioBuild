---
card_schema_version: 2
type: strategy
strategy_id: WILLIAMS-MOP-XNG-MFLOWDOM-2026_S01
variant_id: WILLIAMS-MOP-XNG-MFLOWDOM-2026_S01
source_id: WILLIAMS-MOP-XNG-MFLOWDOM-2026
ea_id: QM5_41038
slug: xng-mflow-dom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41038_xng-mflow-dom_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_xng_monthly_opposed_flow_dominance_g0.md
source_approval: decisions/2026-08-17_xng_monthly_opposed_flow_dominance_source_approval.md
source_author: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction strategy-seeds/sources/SRC03/source.md; Pro-Go close/open decomposition in raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_public_flow_and_open_to_close_professional_flow_decomposition
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence and retrieval hash in strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: explicit_xng_carrier_and_one_month_formation_hold_scope
strategy_mechanic: exact-immediately-completed-broker-month-xng-close-open-and-open-close-log-flow-strict-sign-opposition-follow-absolute-dominant-component-entry-first-new-month-hold-to-next-month
sources:
  - "[[sources/WILLIAMS-MOP-XNG-MFLOWDOM-2026]]"
concepts:
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/opposed-flow-dominance]]"
  - "[[concepts/monthly-return-reconciliation]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, price-flow-decomposition, time-series-momentum, opposed-flow-dominance, monthly-entry, monthly-hold, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410380000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed XNG positions per full post-warm-up year after strict monthly component opposition; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify a second XNG return driver that is structurally distinct from QM5_12567: symmetric monthly public/session flow opposition with absolute-dominance direction rather than a long-only two-day oscillator pullback. Verify every completed prior-month endpoint, strict opposition, dominance direction, reconciliation, no late/repeated entry, and next-month renewal; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [immediately_completed_broker_month, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_opposition, absolute_dominant_component_direction, flow_reconciliation, no_current_bar_leakage, monthly_decision_clock, monthly_attempt_state, no_late_restart_entry, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete OWNER-supplied Tier-A flow-decomposition extraction plus complete-read peer-reviewed XNG one-month carrier lineage with disclosed conjunction risk; R2 exact month, endpoints, opposition, reconciliation, absolute-dominance direction, timing, retry, risk, and lifecycle; R3 native XNG D1 with the registered inferred energy-session label risk explicit; R4 deterministic arithmetic without banned signal or trained logic; canonical dedup raised expected carrier and direction-rule neighbors and manual review fixed the carrier, eligible-state, direction, cadence, and lifecycle boundaries."
---

# QM5_41038 XNG Monthly Opposed-Flow Dominance

## Hypothesis

A completed XNG month whose close-to-open public flow opposes its open-to-close
session flow contains an observable disagreement between information clocks.
Following the sign of the larger absolute component through the next broker
month may isolate the dominant information channel while rejecting months when
both channels already agree.

This is a falsifiable price-flow and calendar translation. The sources do not
test the exact monthly opposition gate, absolute-dominance direction,
continuous CFD, fixed entry clock, ATR stop, or QM portfolio.

## Source Traceability And Claim Boundary

The sole governed composite packet is
`strategy-seeds/sources/WILLIAMS-MOP-XNG-MFLOWDOM-2026/source.md`, approved
before card extraction in
`decisions/2026-08-17_xng_monthly_opposed_flow_dominance_source_approval.md` at commit
`a57d5f9a6`.

Williams supplies the two daily information-time components: prior close to
current open and current open to current close. He discusses their separate
accumulation, divergences, and crossings. Moskowitz, Ooi, and Pedersen supply
XNG carrier relevance and a pooled commodity one-month formation/hold family;
they do not validate this component-opposition gate or dominance rule.

The exact completed-month selection, component log sums, strict opposition,
absolute-dominance direction, telescoping reconciliation, normalized label
convention, first-new-month clock, continuous-CFD carrier, hard stop, spread
cap, fixed-dollar risk, Friday-close override, and attempt ledger are disclosed
QM choices. No source return, alpha, coefficient, significance, trade density,
drawdown, cost, XNG-only efficacy, CFD equivalence, decorrelation, or portfolio
result transfers.

## Source-Defined Rules

- Williams defines the two daily information-time components as prior close
  to current open and current open to current close, and treats the separate
  accumulated lines and their disagreement as potentially informative.
- Moskowitz, Ooi, and Pedersen define own-completed-return sign continuation,
  report a one-month formation/hold commodity portfolio, and include XNG in
  the commodity-futures universe.
- Neither source defines monthly component opposition, absolute-dominance
  direction, a continuous-CFD label policy, an ATR stop, a spread ceiling, an
  attempt ledger, or a fixed cash risk budget.

## QM Interpretations

- The strict opposition-only eligibility state and direction from the larger
  absolute component are pre-result QM mechanizations, not source findings.
- `XNGUSD.DWX` is a continuous-CFD carrier rather than a rolled NYMEX futures
  excess-return series. Same-day versus uniform `+1` D1 label normalization is
  an execution adaptation and never repairs an individual missing session.
- The 15-25 session bounds, 180-minute entry grace, persistent attempt,
  `ATR(20) * 3.5` stop, 3,000-point spread ceiling, fixed-dollar risk,
  Friday-close disablement, and 40-day stale guard are locked safety choices.
  They convey no efficacy claim.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,525 EA-registry rows and
621 root cards. It found no exact match and raised five expected fuzzy family
neighbors. Manual review fixes the load-bearing boundaries:

- `QM5_41036_wti-mflow-dom` applies the same absolute-dominance mechanic to
  WTI. This card is the mission-authorized exact XNG economic identity with
  separate magic, route, fills, risk, and result evidence; no WTI outcome
  transfers.
- `QM5_41035_wti-mflow-div` uses the same monthly information clock on WTI
  but always follows session flow. This card follows the larger component.
- `QM5_41037_xng-mflow-div` uses the same XNG endpoints and opposition gate
  but always follows session flow. This card agrees only when session flow
  dominates, takes the opposite side when overnight flow dominates, and is
  flat on exact magnitude equality.
- `QM5_20204_xng-tsmom1m` follows every nonzero completed-month total. This
  card rejects every agreement month and admits only strict opposition.
- `QM5_20054_xng-1m-contr` fades every nonzero completed-month total. This
  card rejects agreement and follows the dominant opposed component.
- `QM5_21504_xng-flowrev` and `QM5_21520_xng-flow-mom` use five-close
  weekly returns plus native tick-volume ranks. This card uses every
  completed prior-month open/close interval and no volume.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day RSI(2) pullback above
  SMA(200), with an RSI/time exit. This card is symmetric, monthly,
  information-clock structural, and has no oscillator or moving-average
  signal.

Verdict:
`CLEAN_XNG_MONTHLY_OPPOSED_FLOW_DOMINANCE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host and target: exact `XNGUSD.DWX`.
- Timeframe: D1; magic slot 0; planned magic `410380000`.
- Decision: first executable D1 tick of a new normalized broker month.
- Signal: opposite strict signs for completed prior-month close-to-open and
  open-to-close log-return sums; direction equals the sign of the larger
  absolute component.
- Normal exit: first observed D1 boundary of the next normalized broker month.
- Expected cadence: approximately 5-8 completed positions/year after
  opposition, history, and entry-safety exclusions.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

For completed prior-month sessions `d`, oldest through newest:

```text
overnight_flow = sum(log(Open[d] / Close[prior_session]))
session_flow   = sum(log(Close[d] / Open[d]))
month_return   = log(PriorMonthEndClose / PriorPriorMonthEndClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow < 0
require abs(total_flow - month_return) <= 1e-10

abs(session_flow) > abs(overnight_flow) => direction = sign(session_flow)
abs(overnight_flow) > abs(session_flow) => direction = sign(overnight_flow)
equal magnitude or any ineligible state => flat
```

The telescoping identity proves that the two component sums reconstruct the
completed month return. The current month bar enters no signal term.

## Rules

The rules below are the complete authorized baseline. No magnitude,
volatility, seasonal, weekday, event, curve, volume, oscillator, range,
breakout, moving-line, crossover, or external-data signal filter is
authorized.

### 4. Entry Rules

1. Evaluate the decision state only on a new `XNGUSD.DWX` D1 bar.
2. Support only a uniform raw-label offset of zero or `+86400` seconds. The
   current normalized label date must equal the broker date.
3. Detect a new broker month only when the completed-bar scan reaches the
   immediately prior consecutive month. If completed current-month bars
   already exist, the attachment is late.
4. Persist the exact broker `yyyymm` attempt before endpoint validation,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry or
   backfill the month.
5. Require the first observation within 180 minutes of the executable current
   D1 open. A late observation consumes the month flat.
6. Starting at shift 1, collect every completed bar whose normalized month is
   the immediately prior month, then require the next older bar to belong to
   its immediately preceding month.
7. Require 15-25 prior-month sessions, positive finite opens/closes, and
   strictly ordered timestamps. The next older bar supplies only the
   preceding month-end close anchor.
8. For each prior-month session, compute the close-to-open and open-to-close
   log returns from completed bars only. The oldest prior-month session uses
   the anchor close as its prior close.
9. Require the accumulated component sums to have strict opposite signs.
10. Require their total to reconcile within `1e-10` to the anchor-to-prior-
    month-end log return.
11. If session-flow absolute magnitude is larger, follow its sign. If
    overnight-flow absolute magnitude is larger, follow its sign. Agreement,
    equal absolute magnitude, exact zero, invalid arithmetic, failed
    reconciliation, or a missing endpoint consumes the month flat. Magnitude
    selects direction only and never alters the risk budget.
12. Require no owned position and no entry deal already recorded in the
    decision month.
13. Require spread from zero through 3,000 points inclusive, a positive
    completed `ATR(20,D1)`, a finite market price, and a valid normalized hard
    stop.
14. Open one position only. Signal magnitude never scales size. No retry,
    scale-in, pyramid, grid, martingale, pending order, or hedge is allowed.

### 5. Exit Rules

- Ordinary exit: first observable D1 boundary whose normalized broker month
  differs from the entry broker month.
- Stale exit: 40 calendar days after entry if the month boundary was not
  actionable.
- Safety exit: malformed, duplicated, wrong-side, nonpositive-volume,
  nonfinite-price, missing-stop, or future-dated owned exposure.
- Broker hard stop: frozen `3.5 * ATR(20,D1)` distance established at entry.
- No take-profit, trailing stop, signal reversal, Friday close, or partial
  close is authorized.

### 6. Filters (No-Trade Module)

- Exact host `XNGUSD.DWX`, D1, `qm_ea_id=41038`, and slot 0 only.
- Exact locked risk, news, Friday-close, stress, and strategy inputs only.
- Both news axes remain OFF; there is no event-feed dependency.
- Fail closed on invalid label offset, date/month identity, history, OHLC,
  timestamps, component opposition, dominance direction, reconciliation,
  spread, ATR, quote, stop,
  magic, or persistent attempt state.

### 7. Trade Management Rules

- Inspect and repair owned exposure on every tick before entry-only work.
- Exactly one valid owned position is permitted.
- Preserve the original hard stop; do not move it, add a target, or resize.
- Close at next-month boundary, malformed state, or the stale guard.
- Framework kill switch remains authoritative.

## Risk

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Stop: `3.5 * ATR(20,D1)` from the last completed bar, frozen at entry and
  normalized through framework stop rules.
- Target: none.
- Max position count: one for this EA magic and symbol.
- Friday close: disabled because the authorized holding unit is one broker
  month; the next-month and stale exits remain mandatory.
- No source performance or portfolio-risk property is assumed.

## Parameters To Test

The Q02 baseline is frozen; no sweep is authorized.

| name | type | default | allowed baseline |
|---|---|---:|---:|
| `strategy_min_prior_month_bars` | int | 15 | 15 |
| `strategy_max_prior_month_bars` | int | 25 | 25 |
| `strategy_entry_grace_minutes` | int | 180 | 180 |
| `strategy_history_bars` | int | 90 | 90 |
| `strategy_reconcile_tolerance` | double | 1e-10 | 1e-10 |
| `strategy_atr_period` | int | 20 | 20 |
| `strategy_atr_sl_mult` | double | 3.5 | 3.5 |
| `strategy_max_hold_days` | int | 40 | 40 |
| `strategy_max_spread_points` | int | 3000 | 3000 |

## Data Requirements

- Native `XNGUSD.DWX` D1 OHLC, current quote/spread, ATR inputs, broker clock,
  position state, deal history, and terminal global state.
- At least 90 completed D1 bars requested for bounded warm-up/history.
- No futures curve, inventory, open interest, COT, news, CSV, web, API, or
  alternate-symbol runtime input.

## Framework Alignment

- no_trade: exact host/input seal, label/month identity, completed history,
  attempt state, spread, price, stop, and position guards.
- trade_entry: monthly flow decomposition, strict opposition,
  reconciliation, absolute-dominance symmetric direction, ATR hard stop,
  slot 0.
- trade_management: malformed/duplicate cleanup, next-month rollover, and
  40-day stale exit.
- trade_close: no signal close; framework kill switch and broker stop plus
  strategy lifecycle exits.
- news_filter: both axes OFF, hook retained for canonical wiring.

## Framework Execution Overrides

- Declare `PERIOD_D1` as the sole execution timeframe.
- Declare `QM_FRIDAY_CLOSE_DISABLED` because a broker-month hold is a card
  rule, not an omission.
- Keep the framework kill switch, equity stream, MAE tracking, risk sizer,
  stop normalization, and transaction instrumentation active.

## Exit Precedence

1. Framework kill switch.
2. Malformed or duplicate owned-exposure repair.
3. Next normalized broker-month boundary.
4. Forty-calendar-day stale guard.
5. Broker hard stop.

## Runtime Data Dependencies

All signal and execution inputs are MT5-native. The EA may not load an
external file, call an external market-data service, import a trained output,
or reconstruct a futures roll series at runtime.

## Falsification And Requalification

The baseline is a new hypothesis, not a rescue of another XNG card. A Q02
failure retires this identity. Any later change to component eligibility,
formation month, decision clock, direction, hold, threshold, or filter needs a
new source packet, dedup review, strategy ID, card, and EA ID.

## Kill Criteria

- zero trades or fewer than five completed positions per full post-warm-up
  year;
- any signal endpoint from the current month/live bar;
- wrong or nonconsecutive month identity, nonuniform label repair, or late
  entry;
- entry when component signs agree or either is zero;
- direction different from the larger absolute component's sign;
- reconciliation failure or use of an unreconciled signal;
- repeated monthly entry, wrong rollover exit, missing hard stop, invalid risk
  mode, or nondeterminism;
- nonpositive governed economics at Q02; or
- failure of later robustness or portfolio gates. No correlation waiver is
  permitted.

## Validation Plan

1. Run both card schema linters and verify root/approved/build copies are
   byte-identical.
2. Run deterministic reference cases covering zero and `+1` label offsets,
   month boundaries, late attachment, 15/25 session bounds, endpoint ordering,
   component arithmetic, opposition/agreement/zero/equal-magnitude states,
   reconciliation, both session- and overnight-dominant directions, attempt state, risk, and
   rollover.
3. Validate EA/slug/magic registry identity and regenerate the resolver with
   zero dropped rows.
4. Strict-compile with zero errors and warnings; run focused build checks and
   static P1 validation.
5. Enqueue exactly one target-only `RISK_FIXED` Q02 item if tester capacity is
   below the governed ceiling. Do not dispatch a tester manually.

## Version History

| version | date | change | gate | status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial XNG monthly opposed-flow dominance extraction | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, 20 passing mechanic fixtures, locked fixed-risk set, strict compile and build gate (0 errors, 0 warnings, 0 failures) | Q01 | PASS |
| v1-queue | 2026-08-17 | paced target-only enqueue subject to the tester ceiling | Q02 | PENDING |

## Pipeline Phase Status

- G0: `APPROVED`.
- Q01: `PASS` — deterministic build complete; 20 reference fixtures pass,
  strict compile reports zero errors/warnings, and target build checks report
  zero failures/warnings.
- Q02: `PENDING` — one paced target-only enqueue is authorized only below
  the governed tester ceiling; no manual dispatch is authorized.
- Q03+: not authorized by this card/build task.

## Safety Boundary

This card authorizes one branch-only non-live build, one fixed-risk backtest
setfile, strict Q01, and one paced Q02 enqueue if capacity permits. It excludes
manual backtests; terminal dispatch/control; live/demo/shadow/stress/
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate edits; portfolio admission; and correlation waivers.
