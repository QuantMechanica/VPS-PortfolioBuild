---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-XNG-THUTRENDPB-2026_S01
variant_id: EIA-MOP-XNG-THUTRENDPB-2026_S01
source_id: EIA-MOP-XNG-THUTRENDPB-2026
ea_id: QM5_41047
slug: xng-thu-trend-pb
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41047_xng-thu-trend-pb_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_xng_thursday_trend_pullback_g0.md
source_approval: decisions/2026-08-17_xng_thursday_trend_pullback_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "U.S. Energy Information Administration, Weekly Natural Gas Storage Report and release schedule; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and official release schedule."
    location: "Governed packet strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md"
    quality_tier: A
    role: standard_thursday_natural_gas_information_clock
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed review strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: completed_own_return_trend_lineage_including_natural_gas
strategy_mechanic: standard-thursday-completed-event-return-and-pre-event-252-session-trend-strict-sign-opposition-friday-slow-trend-reentry-next-d1-exit
sources:
  - "[[sources/EIA-MOP-XNG-THUTRENDPB-2026]]"
concepts:
  - "[[concepts/natural-gas-information-clock]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/counter-move-re-entry]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, scheduled-event-proxy, time-series-momentum, cross-horizon-opposition, trend-re-entry, friday-entry, next-d1-exit, weekend-hold, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410470000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 18-32 completed XNG positions per full post-warm-up year after exact standard-Thursday and strict event/slow-trend opposition gates; Q02 must prove at least eight/year or retire."
expected_trades_per_year_per_symbol: 24
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_STARTED
review_focus: "Falsify a second XNG sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact Tuesday-Wednesday-Thursday identity, completed Thursday event return, pre-event 252-session trend endpoint, strict sign opposition, durable Friday attempt, slow-trend side, and first-later-D1 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_thursday_proxy, normalized_energy_label, completed_close_to_close_event_return, pre_event_252_session_trend, no_thursday_slow_state_leakage, strict_sign_opposition, slow_trend_direction, friday_decision_clock, friday_attempt_state, no_current_bar_leakage, no_late_restart_entry, next_d1_exit, weekend_hold, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines official EIA event identity with complete-read peer-reviewed natural-gas trend lineage while declaring the untested conjunction and CFD translation; R2 exact weekdays, label normalization, separate completed endpoints, opposition, side, attempt, risk, and lifecycle; R3 registered native XNG D1 with session-label risk explicit; R4 deterministic arithmetic without trained logic, a banned signal indicator, or external feed; canonical dedup found no exact identity and manual family review separated the WTI carrier, XNG event-flow, pre-event trend, intraday-storage, and incumbent RSI systems."
---

# QM5_41047 XNG Standard-Thursday Counter-Move / Slow-Trend Re-entry

## Hypothesis

The ordinary Thursday U.S. natural-gas storage information clock can
concentrate XNG repricing. When the completed Thursday close-to-close move
opposes a separate twelve-month XNG trend that ends before the event session,
the one-session move may be a counter-move rather than a regime change. The
candidate enters Friday in the slow-trend direction and exits at the first
later D1 boundary, ordinarily Monday open.

This is a falsifiable event-time and time-series-momentum translation. It is
not an inventory forecast, a source replication, a profitability claim, or
proof of low correlation with the certified book.

## Source Traceability And Claim Boundary

The sole canonical lineage is the governed composite packet
`strategy-seeds/sources/EIA-MOP-XNG-THUTRENDPB-2026/source.md`, approved before
card extraction in
`decisions/2026-08-17_xng_thursday_trend_pullback_source_approval.md` at commit
`25f6f54fb`.

EIA supplies only the ordinary-Thursday natural-gas information clock and the
fact that holiday weeks can shift. Moskowitz, Ooi, and Pedersen supply broad
own-instrument time-series-momentum lineage, a canonical twelve-month horizon,
and explicit inclusion of natural gas in their futures universe. The paper
does not establish this XNG-specific weekly conjunction.

The exact D1 event proxy, uniform energy-label normalization, separate
Wednesday slow-state endpoint, strict sign opposition, Friday grace,
weekend-bearing next-D1 hold, fixed-dollar risk, hard stop, spread cap, and
attempt ledger are disclosed QM choices. No source performance, coefficient,
significance, density, cost, drawdown, CFD equivalence, decorrelation, or
portfolio result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,534 EA-registry rows and 625
root-card files. It found no exact identity and surfaced only the lexical
source-family matches `wti-dom-trend`, `wti-lr-trend`, and `xng-lr-trend`.
Manual review fixes the load-bearing boundaries:

- `QM5_41046_wti-wed-trend-pb` is the WTI/Wednesday carrier of the experiment;
  this card uses XNG's Thursday event clock and a Friday-to-Monday lifecycle.
- `QM5_20163_xng-thu-trend` enters before Thursday from a negative slow trend;
  this card waits for completed Thursday, requires an opposing event move, and
  can trade either side.
- `QM5_41043_xng-thu-flow-agree` and `QM5_41044_xng-thu-flow-fade` compare
  close-to-open with open-to-close components. This card ignores intraday
  components and compares the whole event return with a non-overlapping slow
  state.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` are M30 release-window systems.
- `QM5_20239_wti-pulltrend` is monthly WTI with a monthly hold.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback;
  this card is weekly, symmetric, event-timed, and uses no oscillator.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_COUNTER_MOVE_PRE_EVENT_TREND_REENTRY_AFTER_EXACT_AND_MANUAL_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XNGUSD.DWX`, D1, slot 0, magic `410470000`.
- Decision clock: first executable tick of broker Friday.
- Entry grace: no later than 180 minutes after executable D1 open.
- Calendar identity: exact completed Tuesday, Wednesday, and standard Thursday.
- Normal exit: first new D1 boundary after entry, ordinarily Monday open.
- Friday close: disabled because the one-D1 lifecycle spans the weekend.
- Expected cadence: approximately 18-32 completed positions/year.

```text
event_return = ln(ThursdayClose / WednesdayClose)
slow_trend   = ln(WednesdayClose / Close252SessionsBeforeWednesday)

require event_return * slow_trend < 0

event_return < 0 and slow_trend > 0 => BUY XNGUSD.DWX
event_return > 0 and slow_trend < 0 => SELL XNGUSD.DWX
```

Thursday is excluded from `slow_trend`. Magnitudes never alter risk.

## Rules

The following rules are the complete authorized baseline. No inventory value,
forecast, return-magnitude threshold, volatility signal gate, moving mean,
oscillator, range expansion, breakout, season selector, or external-data
filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XNGUSD.DWX` D1 bar while attached to exact
   `XNGUSD.DWX`, D1, EA ID 41047, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require the broker date to be Friday. Support only native same-day D1 labels
   or one uniform `+1` calendar-day energy offset; require normalized current
   D1 date to equal broker date.
4. Under that uniform offset, require the exact immediately completed Thursday,
   Wednesday, and Tuesday sessions at calendar offsets one, two, and three,
   strict newest-to-oldest order, and adjacent gaps of 20-28 hours. A missing
   or shifted session consumes Friday flat and is never substituted.
5. Derive the attempt key from broker Friday `yyyymmdd`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that Friday.
6. Require elapsed time from executable D1 open to be 0-180 minutes. Later
   attachment consumes the attempt and never backfills.
7. Require exactly the completed history needed for a 252-session trend.
   Compute `event_return` from completed Thursday and Wednesday closes only.
   Compute `slow_trend` from Wednesday close and the close 252 D1 sessions
   before Wednesday. Current Friday and completed Thursday enter no slow-state
   term.
8. Require finite positive endpoints and strict nonzero sign opposition.
   Agreement, exact zero, invalid history, wrong endpoints, or invalid
   arithmetic consumes Friday flat.
9. A positive slow trend buys XNG; a negative slow trend sells XNG. Magnitude
   never changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.5 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 3,000 points.
    Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, or companion leg exists.

## 5. Exit Rules

1. Close on the first observable new D1 boundary strictly later than the entry
   D1 bar, ordinarily Monday open.
2. Close after four elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. Framework Friday close remains disabled; it may not truncate the locked
   weekend-bearing D1 lifecycle.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, signal reversal, trailing stop, break-even move, partial exit,
   discretionary close, or hold extension is authorized.

## 6. Filters (No-Trade Module)

- Exact `XNGUSD.DWX`, D1, EA 41047, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices after the
  standard event-proxy day.
- Friday close is OFF because the normal exit is the first later D1 boundary.
- Exact normalized Tuesday-Wednesday-Thursday history and strict event/slow-
  trend sign opposition are load-bearing.
- History, opening grace, quotes, spread, ATR, sizing, and stop geometry must
  be valid. Failure after attempt persistence consumes Friday.

## 7. Trade Management Rules

- Own at most one `XNGUSD.DWX` position under magic `410470000`.
- Freeze the original broker hard stop; never widen, trail, or remove it.
- Run malformed and stale repair on every tick before entry logic.
- Persist the last attempted broker-Friday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse an owned
  position.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No take-profit and no signal-magnitude sizing.
- Invalid stop distance, tick value, tick size, volume step, minimum volume,
  computed lot, or price consumes Friday.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | restart-safe Friday boundary |
| `strategy_trend_lookback_d1` | 252 | completed pre-event slow state |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 4 | stale repair only |
| `strategy_max_spread_points` | 3000 | XNG entry cost guard |
| `qm_friday_close_enabled` | false | preserve weekend-bearing D1 hold |
| `qm_friday_close_hour_broker` | 21 | inert framework schema value |

No parameter sweep, after-result threshold, weekday, trend horizon, direction,
or lifecycle change is authorized.

## Data Requirements

- Native `XNGUSD.DWX` D1 OHLC and tick timestamps through the registered
  factory history route.
- Native broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No storage value, event calendar file, analyst forecast, futures curve,
  volume, open interest, API, CSV, or manually maintained signal input.

## Source-Defined Rules

EIA defines the ordinary Thursday natural-gas storage information clock and
warns that holiday weeks can shift. Moskowitz, Ooi, and Pedersen define
own-instrument completed-return trend direction, report a canonical
twelve-month horizon, and include natural gas in their commodity-futures
universe. No source defines this exact weekly conjunction, entry clock, stop,
spread, or lifecycle.

## QM Interpretations

QM fixes the standard-Thursday D1 proxy, uniform label normalization,
completed close-to-close event return, Wednesday-ending 252-session slow
state, strict sign opposition, Friday grace, durable attempt, fixed risk, ATR
stop, spread ceiling, weekend-bearing next-D1 exit, and four-day stale guard.
All are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and broker hard stop remain authoritative. Both news axes
are OFF because the signal uses completed native prices. Friday close is OFF
to preserve the next-D1 weekend lifecycle. This non-live card creates no
test-to-live alias, live symbol mapping, execution-contract registry row, or
promotion entitlement.

## Exit Precedence

1. Framework kill switch and live broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. The ordinary strategy exit is the first D1 boundary after entry.
4. Four elapsed calendar days is the final stale guard.
5. No target, signal reversal, trail, break-even, partial close, Friday close,
   or hold extension exists.

## Runtime Data Dependencies

Runtime uses only native `XNGUSD.DWX` D1 OHLC and timestamps, broker time,
current quotes, symbol contract/tick/volume properties, positions, deals, and a
terminal-global attempt key. It has no external feed, storage value, event-
calendar file, futures curve, fitted artifact, trained output, or manual signal
input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than eight completed positions
per full post-warm-up year, nonpositive governed economics, wrong calendar or
endpoints, current-bar leakage, inclusion of Thursday in the slow state,
non-opposed signs, wrong slow-trend side, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or an unusable standard-Thursday
proxy. Any change to weekday, endpoints, trend horizon, opposition, direction,
stop, or hold creates a new identity and requires the full governed pipeline
from the beginning. Q09 alone may establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, completed history, event and slow returns, opposition, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and later-D1/stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-D1 and stale lifecycle | Trade Close | strategy helper closes owned position; Friday close remains disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than eight completed positions per full
post-warm-up year; zero trades; nonpositive governed economics; wrong date
sequence or label normalization; current-bar or Thursday slow-state leakage;
incorrect endpoints, opposition, or side; late or repeated entry; missing stop;
wrong next-D1 lifecycle; nondeterminism; or registry/risk-mode mismatch.

No weak result may be rescued by adding magnitude, volatility, range, storage,
weather, or season filters; changing the trend horizon; accepting agreement;
changing the weekday; or extending the hold.

## Validation Plan

Q01 must prove:

1. same-day and uniform `+1` labels accept only exact
   Tuesday-Wednesday-Thursday history before broker Friday;
2. positive and negative strict-opposition branches trade in the correct
   slow-trend direction while agreement, zero, and invalid prices remain flat;
3. event arithmetic uses only completed Wednesday/Thursday closes and the
   slow trend ends at Wednesday with exactly 252 D1 intervals;
4. persistent attempts prevent same-Friday retry after every downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen ATR stop;
6. first-later-D1 exit, malformed repair, four-day stale guard, disabled Friday
   close, and weekend hold remain coherent; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial XNG standard-Thursday counter-move / slow-trend re-entry card | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, fixed-risk preset, independent fixtures, and strict validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_xng_thursday_trend_pullback_g0.md` |
| Q01 Build Validation | 2026-08-17 | PASS | `framework/build/compile/20260817_150047/QM5_41047_xng-thu-trend-pb.compile.log`; `D:/QM/reports/framework/21/build_check_20260817_150150.json`; `D:/QM/reports/pipeline/QM5_41047/P1/P1_QM5_41047_result.json` |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one fixed-risk D1
backtest setfile, and one paced target-only Q02 enqueue if the tester ceiling
permits. It does not authorize a manual backtest, live, demo, shadow, stress,
or optimization preset; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio-gate change; portfolio admission; decorrelation claim; or correlation
waiver.
