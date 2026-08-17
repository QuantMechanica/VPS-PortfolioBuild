---
card_schema_version: 2
type: strategy
strategy_id: EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01
variant_id: EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026_S01
source_id: EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026
ea_id: QM5_41043
slug: xng-thu-flow-agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41043_xng-thu-flow-agree_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_xng_thursday_flow_agreement_g0.md
source_approval: decisions/2026-08-17_xng_thursday_flow_agreement_source_approval.md
source_author: "U.S. Energy Information Administration; Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "U.S. Energy Information Administration; Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "U.S. Energy Information Administration, Weekly Natural Gas Storage Report; Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and official release schedule."
    location: "Governed packet strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md"
    quality_tier: A
    role: standard_thursday_natural_gas_information_clock
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper receipt strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: natural_gas_carrier_and_broad_own_return_continuation_lineage
strategy_mechanic: standard-thursday-xng-close-open-and-open-close-strict-sign-agreement-follow-completed-total-next-friday-one-d1-hold
sources:
  - "[[sources/EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026]]"
concepts:
  - "[[concepts/natural-gas-information-clock]]"
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/commodity-return-continuation]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, scheduled-event-proxy, price-flow-decomposition, flow-agreement-continuation, friday-entry, next-d1-exit, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410430000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 18-32 completed XNG positions per full post-warm-up year after exact-session, strict flow-agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 24
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify a second XNG sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact Tuesday-Wednesday-Thursday identity, completed Thursday close/open endpoints, strict component sign agreement, continuation side, durable Friday attempt, and first-later-D1 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_thursday_proxy, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_agreement, completed_day_continuation, friday_decision_clock, friday_attempt_state, no_current_bar_leakage, no_late_restart_entry, next_d1_exit, weekend_hold, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines official EIA event lineage, complete Tier-A Williams decomposition, and a complete-paper peer-reviewed JFE continuation source that explicitly includes natural gas while declaring the untested conjunction, horizon mismatch, and weekend translation; R2 exact weekdays, label normalization, endpoints, agreement, reconciliation, continuation side, attempt, risk, and lifecycle; R3 registered XNG D1 only with session-label risk explicit; R4 deterministic arithmetic without trained logic or an external feed; canonical dedup found no exact identity and manual family review separated the WTI carrier/event relatives plus XNG calendar, storage-M30, and incumbent RSI families."
---

# QM5_41043 XNG Standard-Thursday Strict Flow-Agreement Continuation

## Hypothesis

The ordinary Thursday U.S. natural-gas storage information clock can
concentrate XNG repricing across both the close-to-open interval and the liquid
session. When the completed Thursday overnight and session components have the
same strict sign, their agreement may identify a coherent displacement that
persists for the next D1 interval. The candidate follows that completed
Thursday total at Friday open and exits at the first later D1 boundary.

This is a falsifiable event-time, price-flow, and short-horizon continuation
translation. It is not an inventory forecast, a source replication, a
profitability claim, or proof of low correlation with the certified book.

## Source Provenance And Claim Boundary

The approved source packet is
`strategy-seeds/sources/EIA-WILLIAMS-MOP-XNG-THUFLOWAGREE-2026/source.md`.
EIA establishes the ordinary Thursday natural-gas storage information clock.
Williams defines prior-close-to-open and open-to-close price-flow objects and
their separate accumulation. Moskowitz, Ooi, and Pedersen provide peer-reviewed
own-return continuation lineage across liquid futures and include natural gas.

No source tests strict same-sign Thursday components, a Friday entry, a
weekend-bearing one-D1 hold, Darwinex continuous CFDs, fixed cash risk, or this
execution contract. The academic evidence uses materially longer horizons. No
source performance or correlation result transfers.

## Non-Duplicate Review

The canonical checker scanned 4,530 registry rows and 625 flat card files. It
found no exact identity and surfaced the expected WTI flow-agreement family:

- `QM5_41029_wti-flow-agree` forms over a full WTI Monday-Friday week, enters
  the next Monday, and holds to Friday.
- `QM5_41034_wti-mflow-agree` forms and holds over WTI broker months.
- `QM5_41042_wti-wed-flow-agree` uses WTI's ordinary Wednesday petroleum clock,
  enters Thursday, and normally exits Friday. This card uses XNG's Thursday
  storage clock, enters Friday, and owns the next D1 interval across a weekend.
- `QM5_20163_xng-thu-trend` enters a Thursday short only under a negative
  completed 252-D1 trend; this card waits for completed Thursday internal flow,
  enters Friday, is symmetric, and has no slow trend state.
- `QM5_12819_xng-thu-fade` is an unconditional Thursday short. This card is
  conditional and follows either strict-agreement sign after Thursday closes.
- `QM5_20011_xng-thu-tue` is unconditional long Friday-to-Wednesday carry.
  This card can be long or short and exits at the first later D1 boundary.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` use M30 release impulse, reclaim,
  or live breakout objects. This card never enters during the release session.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XNGUSD.DWX`, D1, slot 0, magic `410430000`.
- Decision clock: first executable tick of broker Friday.
- Entry grace: no later than 180 minutes after executable D1 open.
- Formation: exact completed Tuesday, Wednesday, and Thursday sessions.
- Normal exit: first new D1 boundary after entry, ordinarily Monday open.
- Friday close: disabled because the one-D1 lifecycle spans the weekend.
- Expected cadence: approximately 18-32 completed positions/year.

```text
overnight_flow = ln(ThursdayOpen / WednesdayClose)
session_flow   = ln(ThursdayClose / ThursdayOpen)
day_return     = ln(ThursdayClose / WednesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow > 0
require abs(total_flow - day_return) <= 1e-10

total_flow > 0 => BUY XNGUSD.DWX
total_flow < 0 => SELL XNGUSD.DWX
```

## Rules

The following rules are the complete authorized baseline. No magnitude,
volatility-signal, moving-mean, oscillator, range, tail, breakout, storage-
value, inventory-surprise, weather, or season filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XNGUSD.DWX` D1 bar while attached to exact
   `XNGUSD.DWX`, D1, EA ID 41043, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require the broker date to be Friday. Support only native same-day D1
   labels or one uniform `+1` calendar-day energy offset; require normalized
   current D1 date to equal broker date.
4. Read exactly three immediately preceding completed D1 bars. Under the same
   offset, require exact Thursday, Wednesday, and Tuesday dates at calendar
   offsets one, two, and three from broker Friday, strict newest-to-oldest
   order, and adjacent gaps of 20-28 hours. A missing or shifted session
   consumes Friday flat and is never substituted.
5. Derive the attempt key from broker Friday `yyyymmdd`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that Friday.
6. Require elapsed time from executable D1 open to be 0-180 minutes. Later
   attachment consumes the attempt and never backfills.
7. Require positive finite Thursday open/close and Wednesday close. Compute
   all returns from those completed endpoints; current Friday price enters no
   signal term.
8. Reconcile `total_flow` to `day_return` within `1e-10`. Require both
   components nonzero and strictly same-sign. Opposition, exact zero, invalid
   arithmetic, or failed reconciliation consumes Friday flat.
9. If `total_flow > 0`, BUY XNG. If `total_flow < 0`, SELL XNG. Magnitude never
   changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.5 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 3,000 points.
    Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, or companion leg exists.

## 5. Exit Rules

1. Close on the first observable new D1 boundary strictly later than the entry
   D1 bar. The ordinary lifecycle is Friday entry to Monday open.
2. Close after four elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. Framework Friday close remains disabled; it may not truncate the locked D1
   lifecycle.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, signal reversal, trailing stop, break-even move, partial exit,
   discretionary close, or Friday override is authorized.

## 6. Filters (No-Trade Module)

- Exact `XNGUSD.DWX`, D1, EA 41043, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices and enters
  after the standard event-proxy day.
- Friday close is OFF because the normal exit is the first later D1 boundary.
- Exact normalized Tuesday-Wednesday-Thursday history, strict sign agreement,
  and arithmetic reconciliation are load-bearing.
- History, opening grace, quotes, spread, ATR, sizing, and stop geometry must
  be valid. Failure after attempt persistence consumes Friday.

## 7. Trade Management Rules

- Own at most one `XNGUSD.DWX` position under magic `410430000`.
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
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 4 | stale repair only |
| `strategy_max_spread_points` | 3000 | XNG entry cost guard |
| `strategy_reconcile_tolerance` | 1e-10 | completed-return identity |
| `qm_friday_close_enabled` | false | preserve next-D1 weekend lifecycle |
| `qm_friday_close_hour_broker` | 21 | inert while disabled |

No parameter sweep, after-result threshold, weekday, flow component, sign
gate, continuation side, or lifecycle change is authorized.

## Data Requirements

- Native `XNGUSD.DWX` D1 OHLC and tick timestamps through the registered
  factory history route.
- Native broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No storage number, event calendar, analyst forecast, weather, futures curve,
  volume, open interest, API, CSV, or manually maintained signal input.

## Source-Defined Rules

EIA defines the ordinary Thursday natural-gas storage information clock and
warns that holiday weeks can shift. Williams defines prior-close-to-open and
open-to-close price-flow objects and separate accumulation. Moskowitz, Ooi,
and Pedersen supply broad futures continuation lineage at longer horizons and
include natural gas. No source defines this exact D1 conjunction, sign-
agreement gate, entry clock, risk, stop, or lifecycle.

## QM Interpretations

QM fixes the standard-Thursday proxy, uniform label normalization, completed
endpoints, strict same-sign gate, reconciliation, continuation direction,
Friday grace, durable attempt, fixed risk, ATR stop, spread ceiling, weekend
hold, and next-D1 exit. All are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and broker hard stop remain authoritative. Both news axes
are OFF because the signal uses completed native prices. Friday close is OFF to
preserve the locked one-D1 lifecycle. This non-live card creates no test-to-
live alias, live symbol mapping, execution-contract registry row, or promotion
entitlement.

## Exit Precedence

1. Framework kill switch and live broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. The ordinary strategy exit is the first D1 boundary after entry.
4. Four elapsed calendar days is the final stale guard.
5. No target, signal reversal, trail, break-even, partial close, or Friday
   override exists.

## Runtime Data Dependencies

Runtime uses only native `XNGUSD.DWX` D1 OHLC and timestamps, broker time,
current quotes, symbol contract/tick/volume properties, positions, deals, and
a terminal-global attempt key. It has no external feed, storage value, event-
calendar file, futures curve, fitted artifact, trained output, or manual signal
input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong calendar or
endpoints, current-bar leakage, component opposition, failed reconciliation,
wrong side, late or repeated entry, wrong lifecycle, nondeterminism, invalid
risk mode, or an unusable standard-Thursday proxy. Any change to weekday,
endpoints, sign gate, direction, stop, or hold creates a new identity and
requires the full governed pipeline from the beginning. Q09 alone may
establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, completed history, flows, agreement, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and later-D1/stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-D1 and stale lifecycle | Trade Close | strategy helper closes owned position; Friday close remains disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; current-bar leakage; incorrect endpoints, agreement,
reconciliation, or continuation side; late or repeated entry; missing stop;
wrong next-D1 lifecycle; nondeterminism; or registry/risk-mode mismatch.

No weak result may be rescued by adding magnitude, volatility, mean, range,
tail, storage, weather, or season filters; accepting opposition; changing the
weekday; or extending the hold.

## Validation Plan

Q01 must prove:

1. same-day and uniform `+1` labels accept only exact Tuesday-Wednesday-
   Thursday history before broker Friday;
2. both same-sign branches trade in the correct continuation direction while
   opposition, equality, zero, and invalid prices remain flat;
3. arithmetic uses only completed Wednesday/Thursday endpoints and reconciles
   within `1e-10`;
4. persistent attempts prevent same-Friday retry after every downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen ATR stop;
6. first-later-D1 exit, malformed repair, four-day stale guard, and disabled
   Friday close remain coherent; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial standard-Thursday XNG strict flow-agreement continuation card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_xng_thursday_flow_agreement_g0.md` |
| Q01 Build Validation | - | NOT_STARTED | - |
| Q02 Baseline Screening | - | NOT_STARTED | - |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue if the tester ceiling permits. It does
not authorize a manual backtest, tester control, live/demo/shadow/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate change, portfolio admission, decorrelation claim, or
correlation waiver.
