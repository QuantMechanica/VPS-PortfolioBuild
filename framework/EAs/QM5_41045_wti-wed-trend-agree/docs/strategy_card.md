---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-WTI-WEDTRENDAGREE-2026_S01
variant_id: EIA-MOP-WTI-WEDTRENDAGREE-2026_S01
source_id: EIA-MOP-WTI-WEDTRENDAGREE-2026
ea_id: QM5_41045
slug: wti-wed-trend-agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41045_wti-wed-trend-agree_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_wti_wednesday_trend_agreement_g0.md
source_approval: decisions/2026-08-17_wti_wednesday_trend_agreement_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "U.S. Energy Information Administration, Weekly Petroleum Status Report and release schedule; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and official release schedule."
    location: "Governed packet strategy-seeds/sources/EIA-WTI-WPSR-AFTERSHOCK-2026/source.md"
    quality_tier: A
    role: standard_wednesday_petroleum_information_clock
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: completed_own_return_trend_lineage_including_wti
strategy_mechanic: standard-wednesday-completed-event-return-and-completed-12m-trend-strict-sign-agreement-thursday-continuation-next-d1-exit
sources:
  - "[[sources/EIA-MOP-WTI-WEDTRENDAGREE-2026]]"
concepts:
  - "[[concepts/petroleum-information-clock]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/cross-horizon-confirmation]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, scheduled-event-proxy, time-series-momentum, cross-horizon-agreement, thursday-entry, next-d1-exit, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410450000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 18-32 completed WTI positions per full post-warm-up year after exact standard-Wednesday and strict event/slow-trend sign-agreement gates; Q02 must prove at least eight/year or retire."
expected_trades_per_year_per_symbol: 24
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
review_focus: "Falsify a WTI standard-Wednesday completed-event continuation stream outside the certified XAU/SP500/NDX/XNG book. Verify exact Monday-Tuesday-Wednesday identity, completed event return, pre-event 252-session trend endpoint, strict sign agreement, durable Thursday attempt, and first-later-D1 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_wednesday_proxy, normalized_energy_label, completed_close_to_close_event_return, pre_event_252_session_trend, no_wednesday_slow_state_leakage, strict_sign_agreement, thursday_decision_clock, thursday_attempt_state, no_current_bar_leakage, no_late_restart_entry, next_d1_exit, risk_mode_dual, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines official EIA event identity with complete-read peer-reviewed WTI trend lineage while declaring the untested conjunction and CFD translation; R2 exact weekdays, label normalization, separate completed endpoints, agreement, side, attempt, risk, and lifecycle; R3 registered native XTI D1 with session-label risk explicit; R4 deterministic arithmetic without trained logic, a banned signal, or external feed; canonical dedup returned CLEAN and manual family review separated pre-event trend, event-flow, range-aftershock, intraday-WPSR, and incumbent RSI systems."
---

# QM5_41045 WTI Standard-Wednesday Event / Slow-Trend Agreement

## Hypothesis

The ordinary Wednesday U.S. petroleum information clock can concentrate WTI
repricing. When the completed Wednesday close-to-close move agrees with a
separate twelve-month WTI trend that ends before the event session, that
cross-horizon agreement may persist for the next D1 interval. The candidate
follows the common sign at Thursday open and exits at the first later D1
boundary.

This is a falsifiable event-time and time-series-momentum translation. It is
not an inventory forecast, a source replication, a profitability claim, or
proof of low correlation with the certified book.

## Source Traceability And Claim Boundary

The sole canonical lineage is the governed composite packet
`strategy-seeds/sources/EIA-MOP-WTI-WEDTRENDAGREE-2026/source.md`, approved
before card extraction in
`decisions/2026-08-17_wti_wednesday_trend_agreement_source_approval.md` at
commit `ebe884e63`.

EIA supplies only the ordinary-Wednesday petroleum information clock and the
fact that holiday weeks can shift. Moskowitz, Ooi, and Pedersen supply broad
own-instrument time-series-momentum lineage, a canonical twelve-month horizon,
and explicit inclusion of WTI in their futures universe. The paper does not
establish this WTI-specific weekly conjunction.

The exact D1 event proxy, uniform energy-label normalization, separate Tuesday
slow-state endpoint, strict sign agreement, Thursday grace, next-D1 hold,
fixed-dollar risk, hard stop, spread cap, and attempt ledger are disclosed QM
choices. No source performance, coefficient, significance, density, cost,
drawdown, CFD equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,532 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy match. Manual review
fixes the load-bearing boundaries:

- `QM5_41042_wti-wed-flow-agree` compares Wednesday close-to-open and
  open-to-close components. This card compares the whole completed Wednesday
  return with a non-overlapping 252-session trend ending Tuesday.
- `QM5_41041_wti-wed-flow-fade` requires opposed Wednesday components and
  fades the dominant completed move; this card requires cross-horizon sign
  agreement and continues it.
- `QM5_20154_wti-wed-trend` enters before Wednesday from a slow trend state;
  this card waits for the completed Wednesday event proxy and enters Thursday.
- `QM5_12590_eia-wti-aftershock` uses event-day range expansion rather than a
  separate slow trend sign.
- `QM5_20133` and `QM5_20134` trade M30 price sequences inside the release
  session.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_COMPLETED_EVENT_RETURN_AND_PRE_EVENT_TWELVE_MONTH_TREND_AGREEMENT_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XTIUSD.DWX`, D1, slot 0, magic `410450000`.
- Decision clock: first executable tick of broker Thursday.
- Entry grace: no later than 180 minutes after executable D1 open.
- Calendar identity: exact completed Monday, Tuesday, and standard Wednesday.
- Normal exit: first new D1 boundary after entry, ordinarily Friday open.
- Friday close: enabled at broker hour 21 as a fail-safe only.
- Expected cadence: approximately 18-32 completed positions/year.

```text
event_return = ln(WednesdayClose / TuesdayClose)
slow_trend   = ln(TuesdayClose / Close252SessionsBeforeTuesday)

require event_return * slow_trend > 0

event_return > 0 and slow_trend > 0 => BUY XTIUSD.DWX
event_return < 0 and slow_trend < 0 => SELL XTIUSD.DWX
```

Wednesday is excluded from `slow_trend`. Magnitudes never alter risk.

## Rules

The following rules are the complete authorized baseline. No inventory value,
forecast, return-magnitude threshold, volatility signal gate, moving mean,
oscillator, range expansion, breakout, season selector, or external-data
filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XTIUSD.DWX` D1 bar while attached to exact
   `XTIUSD.DWX`, D1, EA ID 41045, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require the broker date to be Thursday. Support only native same-day D1
   labels or one uniform `+1` calendar-day energy offset; require normalized
   current D1 date to equal broker date.
4. Under that uniform offset, require the exact immediately completed
   Wednesday, Tuesday, and Monday sessions at calendar offsets one, two, and
   three, strict newest-to-oldest order, and adjacent gaps of 20-28 hours. A
   missing or shifted session consumes Thursday flat and is never substituted.
5. Derive the attempt key from broker Thursday `yyyymmdd`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that Thursday.
6. Require elapsed time from executable D1 open to be 0-180 minutes. Later
   attachment consumes the attempt and never backfills.
7. Require at least 254 completed D1 bars from shift 1. Compute
   `event_return` from completed Wednesday and Tuesday closes only. Compute
   `slow_trend` from Tuesday close and the close 252 D1 sessions before
   Tuesday. Current Thursday and completed Wednesday enter no slow-state term.
8. Require finite positive endpoints and strict nonzero sign agreement.
   Disagreement, exact zero, invalid history, wrong endpoints, or invalid
   arithmetic consumes Thursday flat.
9. Positive agreement buys WTI; negative agreement sells WTI. Magnitude never
   changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.0 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 1,500 points.
    Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, or companion leg exists.

## 5. Exit Rules

1. Close on the first observable new D1 boundary strictly later than the entry
   D1 bar, ordinarily Friday open.
2. Close after three elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe; it
   must not delay the first-later-D1 strategy exit.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, signal reversal, trailing stop, break-even move, partial exit,
   discretionary close, or hold extension is authorized.

## 6. Filters (No-Trade Module)

- Exact `XTIUSD.DWX`, D1, EA 41045, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices after the
  standard event-proxy day.
- Friday close is ON only as a fail-safe behind the ordinary next-D1 exit.
- Exact normalized Monday-Tuesday-Wednesday history and strict event/slow-
  trend sign agreement are load-bearing.
- History, opening grace, quotes, spread, ATR, sizing, and stop geometry must
  be valid. Failure after attempt persistence consumes Thursday.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410450000`.
- Freeze the original broker hard stop; never widen, trail, or remove it.
- Run malformed and stale repair on every tick before entry logic.
- Persist the last attempted broker-Thursday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse an owned
  position.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.0 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes Thursday.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | restart-safe Thursday boundary |
| `strategy_trend_lookback_d1` | 252 | completed pre-event slow state |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 3 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | true | next-D1 fail-safe |
| `qm_friday_close_hour_broker` | 21 | fail-safe hour |

No parameter sweep, after-result threshold, weekday, trend horizon, direction,
or lifecycle change is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and tick timestamps through the registered
  factory history route.
- Native broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No inventory value, event calendar file, analyst forecast, futures curve,
  volume, open interest, API, CSV, or manually maintained signal input.

## Source-Defined Rules

EIA defines the ordinary Wednesday petroleum information clock and warns that
holiday weeks can shift. Moskowitz, Ooi, and Pedersen define own-instrument
completed-return trend direction, report a canonical twelve-month horizon,
and include WTI in their commodity-futures universe. No source defines this
exact weekly conjunction, entry clock, stop, spread, or lifecycle.

## QM Interpretations

QM fixes the standard-Wednesday D1 proxy, uniform label normalization,
completed close-to-close event return, Tuesday-ending 252-session slow state,
strict sign agreement, Thursday grace, durable attempt, fixed risk, ATR stop,
spread ceiling, and next-D1 exit. All are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and broker hard stop remain authoritative. Both news axes
are OFF because the signal uses completed native prices. Friday close is ON as
a fail-safe. This non-live card creates no test-to-live alias, live symbol
mapping, execution-contract registry row, or promotion entitlement.

## Exit Precedence

1. Framework kill switch and live broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. The ordinary strategy exit is the first D1 boundary after entry.
4. Friday close at broker hour 21 is a fail-safe only.
5. Three elapsed calendar days is the final stale guard.
6. No target, signal reversal, trail, break-even, partial close, or hold
   extension exists.

## Runtime Data Dependencies

Runtime uses only native `XTIUSD.DWX` D1 OHLC and timestamps, broker time,
current quotes, symbol contract/tick/volume properties, positions, deals, and a
terminal-global attempt key. It has no external feed, WPSR value, event-
calendar file, futures curve, fitted artifact, trained output, or manual
signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than eight completed positions
per full post-warm-up year, nonpositive governed economics, wrong calendar or
endpoints, current-bar leakage, inclusion of Wednesday in the slow state, sign
disagreement, wrong continuation side, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or an unusable standard-
Wednesday proxy. Any change to weekday, endpoints, trend horizon, agreement,
direction, stop, or hold creates a new identity and requires the full governed
pipeline from the beginning. Q09 alone may establish realized portfolio
correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, completed history, event and slow returns, agreement, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and later-D1/stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-D1 and stale lifecycle | Trade Close | strategy helper closes owned position; Friday close is fail-safe |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than eight completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; current-bar or Wednesday slow-state leakage; incorrect
endpoints, agreement, or side; late or repeated entry; missing stop; wrong
next-D1 lifecycle; nondeterminism; or registry/risk-mode mismatch.

No weak result may be rescued by adding magnitude, volatility, range,
inventory, weather, or season filters; changing the trend horizon; accepting
disagreement; changing the weekday; or extending the hold.

## Validation Plan

Q01 must prove:

1. same-day and uniform `+1` labels accept only exact Monday-Tuesday-Wednesday
   history before broker Thursday;
2. positive and negative strict-agreement branches trade in the correct
   continuation direction while disagreement, zero, and invalid prices remain
   flat;
3. event arithmetic uses only completed Tuesday/Wednesday closes and the slow
   trend ends at Tuesday with exactly 252 D1 intervals;
4. persistent attempts prevent same-Thursday retry after every downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen ATR stop;
6. first-later-D1 exit, malformed repair, three-day stale guard, and Friday
   fail-safe remain coherent; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial standard-Wednesday WTI event/slow-trend agreement card | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, fixed-risk preset, independent fixtures, and strict validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_wti_wednesday_trend_agreement_g0.md` |
| Q01 Build Validation | 2026-08-17 | PASS | `framework/build/compile/20260817_130817/QM5_41045_wti-wed-trend-agree.compile.log`; `D:/QM/reports/framework/21/build_check_20260817_130817.json`; `D:/QM/reports/pipeline/QM5_41045/P1/P1_QM5_41045_result.json` |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue if the tester ceiling permits. It does
not authorize a manual backtest, tester control, live, demo, shadow, stress, or
optimization preset; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio-gate change; portfolio admission; decorrelation claim; or
correlation waiver.
