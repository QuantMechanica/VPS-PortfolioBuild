---
card_schema_version: 2
type: strategy
strategy_id: EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01
variant_id: EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01
source_id: EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026
ea_id: QM5_41044
slug: xng-thu-flow-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41044_xng-thu-flow-fade_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_xng_thursday_flow_fade_g0.md
source_approval: decisions/2026-08-17_xng_thursday_flow_fade_source_approval.md
source_author: "U.S. Energy Information Administration; Larry R. Williams; Yurun Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_authors: "U.S. Energy Information Administration; Larry R. Williams; Yurun Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_citation: "U.S. Energy Information Administration, Weekly Natural Gas Storage Report; Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Yang, Goncu, and Pantelous (2018), International Review of Financial Analysis 60, 177-196."
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
    citation: "Yang, Y., Goncu, A., and Pantelous, A. A. (2018). Momentum and reversal strategies in Chinese commodity futures markets. International Review of Financial Analysis 60, 177-196."
    location: "DOI 10.1016/j.irfa.2018.09.012; governed partial extraction strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md"
    quality_tier: B
    role: broad_fixed_horizon_commodity_reversal_lineage
strategy_mechanic: standard-thursday-xng-close-open-versus-open-close-strict-opposition-session-dominant-fade-next-friday-one-d1-hold
sources:
  - "[[sources/EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026]]"
concepts:
  - "[[concepts/natural-gas-information-clock]]"
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/short-horizon-commodity-reversal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, scheduled-event-proxy, price-flow-decomposition, session-dominant-reversal, friday-entry, next-d1-exit, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410440000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-18 completed XNG positions per full post-warm-up year after exact-session, strict flow-opposition, and strict session-dominance gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0
review_focus: "Falsify an XNG standard-Thursday information-time reversal stream outside the certified XAU/SP500/NDX/XNG book. Verify exact Tuesday-Wednesday-Thursday identity, completed Thursday close/open endpoints, strict component opposition, strict session dominance, contrarian side, durable Friday attempt, and first-later-D1 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_thursday_proxy, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_opposition, strict_session_dominance, completed_day_fade, friday_decision_clock, friday_attempt_state, no_current_bar_leakage, no_late_restart_entry, next_d1_exit, weekend_hold, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one approved composite lineage with official EIA event identity, complete Tier-A Williams decomposition, and peer-reviewed commodity-reversal support while declaring the partial academic record and untested XNG conjunction; R2 exact weekdays, label normalization, endpoints, opposition, dominance, reconciliation, fade side, attempt, risk, and lifecycle; R3 registered XNG D1 only with session-label risk explicit; R4 deterministic arithmetic without trained logic or an external feed; canonical dedup returned CLEAN and manual family review separated the incumbent RSI, unconditional calendar, M30 storage-event, monthly flow, XNG agreement, and WTI sibling systems."
---

# QM5_41044 XNG Standard-Thursday Session-Dominant Flow Fade

## Hypothesis

The ordinary Thursday U.S. natural-gas storage information clock can
concentrate XNG repricing inside the liquid session. When the completed
Thursday close-to-open move opposes but is smaller than the open-to-close move,
the session-dominated displacement may partially reverse during the next D1
interval. The candidate fades the exact completed Thursday total at Friday
open and exits at the first later D1 boundary.

This is a falsifiable price-flow, event-time, and short-horizon-reversal
translation. It is not an inventory forecast, a source replication, a
profitability claim, or proof of low correlation with the certified book.

## Source Traceability And Claim Boundary

The sole canonical lineage is the governed composite packet
`strategy-seeds/sources/EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026/source.md`,
approved before card extraction in
`decisions/2026-08-17_xng_thursday_flow_fade_source_approval.md` at commit
`fcccf5407`.

EIA supplies only the ordinary Thursday natural-gas information clock and the
fact that holiday weeks can shift. Williams supplies completed prior-close-to-
open and open-to-close price-flow objects and treats their separate behavior
as potentially informative. Yang, Goncu, and Pantelous supply broad fixed-
horizon commodity reversal lineage; the governed local record is not a full-
paper receipt and the source universe is not XNG.

The exact D1 Thursday proxy, energy-label normalization, strict opposition,
strict session-dominance gate, contrarian direction, Friday grace, weekend-
bearing one-D1 hold, fixed-dollar risk, hard stop, spread cap, and attempt
ledger are disclosed QM choices. No source performance, coefficient,
significance, density, cost, drawdown, XNG efficacy, CFD equivalence,
decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,531 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy match. Manual review
fixes the load-bearing boundaries:

- `QM5_41043_xng-thu-flow-agree` requires strict component agreement and
  follows the completed total. This card requires strict opposition plus
  session dominance and fades the completed total.
- `QM5_12819_xng-thu-fade` is an unconditional Thursday short. This card waits
  for a completed Thursday, enters Friday, can trade either side, and requires
  an opposed-flow state.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` use exact-clock M30 release
  impulse, reclaim, or live-breakout objects. This card decides only after a
  completed D1 Thursday and owns the next D1 interval.
- `QM5_41037` and `QM5_41038` form over complete broker months and hold to the
  following month. This card forms from one event-clock session.
- `QM5_41041_wti-wed-flow-fade` uses WTI's Wednesday petroleum clock, enters
  Thursday, and normally exits Friday. This card uses XNG's Thursday storage
  clock, enters Friday, and spans the weekend to the next D1 boundary.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  above a slow mean.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_SESSION_DOMINANT_FLOW_FADE_AFTER_CARRIER_EVENT_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XNGUSD.DWX`, D1, slot 0, magic `410440000`.
- Decision clock: first executable tick of broker Friday.
- Entry grace: no later than 180 minutes after executable D1 open.
- Formation: exact completed Tuesday, Wednesday, and Thursday sessions.
- Normal exit: first new D1 boundary after entry, ordinarily Monday open.
- Friday close: disabled because the one-D1 lifecycle spans the weekend.
- Expected cadence: approximately 8-18 completed positions/year.

```text
overnight_flow = ln(ThursdayOpen / WednesdayClose)
session_flow   = ln(ThursdayClose / ThursdayOpen)
day_return     = ln(ThursdayClose / WednesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow < 0
require abs(session_flow) > abs(overnight_flow)
require abs(total_flow - day_return) <= 1e-10

total_flow > 0 => SELL XNGUSD.DWX
total_flow < 0 => BUY XNGUSD.DWX
```

## Rules

The following rules are the complete authorized baseline. No inventory value,
forecast, magnitude threshold, volatility signal, moving mean, oscillator,
range, tail, breakout, season, or external-data filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XNGUSD.DWX` D1 bar while attached to exact
   `XNGUSD.DWX`, D1, EA ID 41044, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require the broker date to be Friday. Support only native same-day D1 labels
   or one uniform `+1` calendar-day energy offset; require normalized current
   D1 date to equal broker date.
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
8. Reconcile `total_flow` to `day_return` within `1e-10`. Require strict
   component opposition and strict session dominance. Agreement, exact zero,
   equal magnitude, absent dominance, invalid arithmetic, or failed
   reconciliation consumes Friday flat.
9. If `total_flow > 0`, SELL XNG. If `total_flow < 0`, BUY XNG. Magnitude never
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

- Exact `XNGUSD.DWX`, D1, EA 41044, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices and enters
  after the standard event-proxy day.
- Friday close is OFF because the normal exit is the first later D1 boundary.
- Exact normalized Tuesday-Wednesday-Thursday history, strict opposition,
  strict session dominance, and arithmetic reconciliation are load-bearing.
- History, opening grace, quotes, spread, ATR, sizing, and stop geometry must
  be valid. Failure after attempt persistence consumes Friday.

## 7. Trade Management Rules

- Own at most one `XNGUSD.DWX` position under magic `410440000`.
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

No parameter sweep, after-result threshold, weekday, flow component, dominance
gate, direction, or lifecycle change is authorized.

## Data Requirements

- Native `XNGUSD.DWX` D1 OHLC and tick timestamps through the registered
  factory history route.
- Native broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No storage number, event calendar file, analyst forecast, weather, futures
  curve, volume, open interest, API, CSV, or manually maintained signal input.

## Source-Defined Rules

EIA defines the ordinary Thursday natural-gas storage information clock and
warns that holiday weeks can shift. Williams defines prior-close-to-open and
open-to-close price-flow objects and their separate interpretation. Yang,
Goncu, and Pantelous provide broad fixed-horizon commodity reversal lineage.
No source defines this exact D1 conjunction, dominance gate, entry clock, risk,
stop, or lifecycle.

## QM Interpretations

QM fixes the standard-Thursday proxy, uniform label normalization, completed
endpoints, strict opposition, strict session dominance, reconciliation,
contrarian direction, Friday grace, durable attempt, fixed risk, ATR stop,
spread ceiling, weekend hold, and next-D1 exit. All are pre-result
falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and broker hard stop remain authoritative. Both news axes
are OFF because the signal uses completed native prices. Friday close is OFF
to preserve the locked one-D1 lifecycle. This non-live card creates no
test-to-live alias, live symbol mapping, execution-contract registry row, or
promotion entitlement.

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
endpoints, current-bar leakage, component agreement, absent session dominance,
failed reconciliation, wrong contrarian side, late or repeated entry, wrong
lifecycle, nondeterminism, invalid risk mode, or an unusable standard-Thursday
proxy. Any change to weekday, endpoints, opposition, dominance, direction,
stop, or hold creates a new identity and requires the full governed pipeline
from the beginning. Q09 alone may establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, completed history, flows, opposition, dominance, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and later-D1/stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-D1 and stale lifecycle | Trade Close | strategy helper closes owned position; Friday close remains disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; current-bar leakage; incorrect endpoints, opposition,
dominance, reconciliation, or contrarian side; late or repeated entry; missing
stop; wrong next-D1 lifecycle; nondeterminism; or registry/risk-mode mismatch.

No weak result may be rescued by adding magnitude, volatility, mean, range,
tail, storage, weather, or season filters; accepting agreement; changing the
weekday; or extending the hold.

## Validation Plan

Q01 must prove:

1. same-day and uniform `+1` labels accept only exact Tuesday-Wednesday-
   Thursday history before broker Friday;
2. both session-dominant opposition branches trade in the correct contrarian
   direction while agreement, equality, zero, and invalid prices remain flat;
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
| v1 | 2026-08-17 | initial standard-Thursday XNG session-dominant flow-fade card | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, fixed-risk set, and mechanic fixtures | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_xng_thursday_flow_fade_g0.md` |
| Q01 Build & Spec | 2026-08-17 | PASS | 14 fixtures; strict compile 0/0; targeted build check 0/0; symbol/spec/P1 PASS |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue if the tester ceiling permits. It does
not authorize a manual backtest, tester control, live, demo, shadow, stress, or
optimization preset; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio-gate change; portfolio admission; decorrelation claim; or
correlation waiver.
