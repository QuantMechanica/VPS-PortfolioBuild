---
card_schema_version: 2
type: strategy
strategy_id: EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026_S01
variant_id: EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026_S01
source_id: EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026
ea_id: QM5_41042
slug: wti-wed-flow-agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41042_wti-wed-flow-agree_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_wti_wednesday_flow_agreement_g0.md
source_approval: decisions/2026-08-17_wti_wednesday_flow_agreement_source_approval.md
source_author: "U.S. Energy Information Administration; Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "U.S. Energy Information Administration; Larry R. Williams; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "U.S. Energy Information Administration, Weekly Petroleum Status Report; Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and official release schedule."
    location: "Governed packet strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md"
    quality_tier: A
    role: standard_wednesday_crude_oil_information_clock
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper receipt strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: broad_own_return_continuation_lineage
strategy_mechanic: standard-wednesday-wti-close-open-and-open-close-strict-sign-agreement-follow-completed-total-next-thursday-one-d1-hold
sources:
  - "[[sources/EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026]]"
concepts:
  - "[[concepts/crude-oil-information-clock]]"
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/commodity-return-continuation]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, scheduled-event-proxy, price-flow-decomposition, flow-agreement-continuation, thursday-entry, next-d1-exit, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410420000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 18-32 completed WTI positions per full post-warm-up year after exact-session, strict flow-agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 24
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify a standard-Wednesday WTI information-time continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact Monday-Tuesday-Wednesday identity, completed Wednesday close/open endpoints, strict component sign agreement, continuation side, durable Thursday attempt, and next-D1 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_wednesday_proxy, normalized_energy_label, completed_close_open_endpoints, strict_flow_sign_agreement, completed_day_continuation, thursday_decision_clock, thursday_attempt_state, no_current_bar_leakage, no_late_restart_entry, next_d1_exit, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines official EIA event lineage, complete Tier-A Williams decomposition, and a complete-paper peer-reviewed JFE continuation source while declaring the untested conjunction and horizon mismatch; R2 exact weekdays, label normalization, endpoints, agreement, reconciliation, continuation side, attempt, risk, and lifecycle; R3 registered XTI D1 only; R4 deterministic arithmetic without trained logic or an external feed; canonical dedup found no exact identity and manual family review separated the weekly/monthly relatives."
---

# QM5_41042 WTI Standard-Wednesday Strict Flow-Agreement Continuation

## Hypothesis

The ordinary Wednesday U.S. petroleum-information clock can concentrate WTI
repricing across both the close-to-open interval and the liquid session. When
the completed Wednesday overnight and session components have the same strict
sign, their agreement may identify a coherent displacement that persists for
the next D1 interval. The candidate follows that completed Wednesday total at
Thursday open and exits at the next D1 boundary.

This is a falsifiable event-time, price-flow, and short-horizon continuation
translation. It is not an inventory forecast, a source replication, a
profitability claim, or proof of low correlation with the certified book.

## Source Provenance And Claim Boundary

The approved source packet is
`strategy-seeds/sources/EIA-WILLIAMS-MOP-WTI-WEDFLOWAGREE-2026/source.md`.
EIA establishes the ordinary Wednesday crude-oil information clock. Williams
defines prior-close-to-open and open-to-close price-flow objects and their
separate accumulation. Moskowitz, Ooi, and Pedersen provide peer-reviewed
own-return continuation lineage across liquid futures, including WTI.

No source tests strict same-sign Wednesday components, a Thursday entry, a
one-D1 hold, Darwinex continuous CFDs, fixed cash risk, or this execution
contract. The MOP evidence uses materially longer horizons. No source
performance or correlation result transfers.

## Non-Duplicate Review

The canonical checker scanned 4,529 registry rows and 625 flat card files. It
found no exact identity and surfaced the expected fuzzy family:

- `QM5_41029_wti-flow-agree` forms over a full Monday-Friday week, enters the
  next Monday, and holds to Friday. This card forms from one standard
  Wednesday, enters Thursday, and exits next D1.
- `QM5_41034_wti-mflow-agree` forms and holds over broker months. This card
  owns one D1 interval around a weekly event clock.
- `QM5_41041_wti-wed-flow-fade` requires component opposition plus session
  dominance and fades the total. This card requires strict agreement and
  follows the total.
- `QM5_20154_wti-wed-trend` is long-only under a positive completed 252-D1
  trend state. This card is symmetric and has no slow trend state.
- `QM5_41024_wti-1wed-mom1` trades only the first Wednesday of a month from the
  prior month's sign. This card evaluates every eligible Thursday from the
  immediately completed Wednesday.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_STRICT_FLOW_AGREEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XTIUSD.DWX`, D1, slot 0, magic `410420000`.
- Decision clock: first executable tick of broker Thursday.
- Entry grace: no later than 180 minutes after executable D1 open.
- Formation: exact completed Monday, Tuesday, and Wednesday sessions.
- Normal exit: first new D1 boundary after entry, ordinarily Friday open.
- Friday fail-safe: broker Friday hour 21.
- Expected cadence: approximately 18-32 completed positions/year.

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow

require overnight_flow * session_flow > 0
require abs(total_flow - day_return) <= 1e-10

total_flow > 0 => BUY XTIUSD.DWX
total_flow < 0 => SELL XTIUSD.DWX
```

## Rules

The following rules are the complete authorized baseline. No magnitude,
volatility-signal, moving-mean, oscillator, range, tail, breakout, inventory-
value, or season filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XTIUSD.DWX` D1 bar while attached to exact
   `XTIUSD.DWX`, D1, EA ID 41042, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require the broker date to be Thursday. Support only native same-day D1
   labels or one uniform `+1` calendar-day energy offset; require normalized
   current D1 date to equal broker date.
4. Read exactly three immediately preceding completed D1 bars. Under the same
   offset, require exact Wednesday, Tuesday, and Monday dates at calendar
   offsets one, two, and three from broker Thursday, strict newest-to-oldest
   order, and adjacent gaps of 20-28 hours. A missing or shifted session
   consumes Thursday flat and is never substituted.
5. Derive the attempt key from broker Thursday `yyyymmdd`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that Thursday.
6. Require elapsed time from executable D1 open to be 0-180 minutes. Later
   attachment consumes the attempt and never backfills.
7. Require positive finite Wednesday open/close and Tuesday close. Compute all
   returns from those completed endpoints; current Thursday price enters none
   of them.
8. Reconcile `total_flow` to `day_return` within `1e-10`. Require both
   components nonzero and strictly same-sign. Opposition, exact zero, invalid
   arithmetic, or failed reconciliation consumes Thursday flat.
9. If `total_flow > 0`, BUY WTI. If `total_flow < 0`, SELL WTI. Magnitude never
   changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.0 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 1,500 points.
    Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, or companion leg exists.

## 5. Exit Rules

1. Close on the first observable new D1 boundary strictly later than the entry
   D1 bar. The ordinary lifecycle is Thursday entry to Friday open.
2. Close after three elapsed calendar days as a final stale guard.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
4. Framework Friday close remains enabled at broker hour 21 as a fail-safe.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, signal reversal, trailing stop, break-even move, partial exit,
   discretionary close, or Friday override is authorized.

## 6. Filters (No-Trade Module)

- Exact `XTIUSD.DWX`, D1, EA 41042, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed native prices and enters
  after the standard event-proxy day.
- Friday close is ON at broker hour 21 and is a fail-safe.
- Exact normalized Monday-Tuesday-Wednesday history, strict sign agreement,
  and arithmetic reconciliation are load-bearing.
- History, opening grace, quotes, spread, ATR, sizing, and stop geometry must
  be valid. Failure after attempt persistence consumes Thursday.

## 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `410420000`.
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
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_hold_days` | 3 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `strategy_reconcile_tolerance` | 1e-10 | completed-return identity |
| `qm_friday_close_enabled` | true | weekly fail-safe |
| `qm_friday_close_hour_broker` | 21 | fail-safe clock |

No parameter sweep, after-result threshold, weekday, flow component, sign
gate, continuation side, or lifecycle change is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and tick timestamps through the registered
  factory history route.
- Native broker clock, symbol quotes/properties, positions, deal history, and
  terminal global variables.
- No inventory number, event calendar, analyst forecast, futures curve,
  volume, open interest, API, CSV, or manually maintained signal input.

## Source-Defined Rules

EIA defines the ordinary Wednesday petroleum-information clock and warns that
holiday weeks can shift. Williams defines prior-close-to-open and open-to-
close price-flow objects and separate accumulation. Moskowitz, Ooi, and
Pedersen supply broad futures continuation lineage at longer horizons. No
source defines this exact D1 conjunction, sign-agreement gate, entry clock,
risk, stop, or lifecycle.

## QM Interpretations

QM fixes the standard-Wednesday proxy, uniform label normalization, completed
endpoints, strict same-sign gate, reconciliation, continuation direction,
Thursday grace, durable attempt, fixed risk, ATR stop, spread ceiling, and
next-D1 exit. All are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and Friday-close fail-safe remain authoritative. Both
news axes are OFF because the signal uses completed native prices. This
non-live card creates no test-to-live alias, live symbol mapping, execution-
contract registry row, or promotion entitlement.

## Exit Precedence

1. Framework kill switch and live broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. The ordinary strategy exit is the first D1 boundary after entry.
4. Three elapsed calendar days is the final stale guard.
5. Framework Friday hour 21 is a fail-safe.
6. No target, signal reversal, trail, break-even, or partial close exists.

## Runtime Data Dependencies

Runtime uses only native `XTIUSD.DWX` D1 OHLC and timestamps, broker time,
current quotes, symbol contract/tick/volume properties, positions, deals, and
a terminal-global attempt key. It has no external feed, inventory value,
event-calendar file, futures curve, fitted artifact, trained output, or manual
signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong calendar or
endpoints, current-bar leakage, component opposition, failed reconciliation,
wrong side, late or repeated entry, wrong lifecycle, nondeterminism, invalid
risk mode, or an unusable standard-Wednesday proxy. Any change to weekday,
endpoints, sign gate, direction, stop, or hold creates a new identity and
requires the full governed pipeline from the beginning. Q09 alone may
establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, completed history, flows, agreement, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and later-D1/stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-D1 and stale lifecycle | Trade Close | strategy helper closes owned position; framework Friday close is fail-safe |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; current-bar leakage; incorrect endpoints, agreement,
reconciliation, or continuation side; late or repeated entry; missing stop;
wrong next-D1 lifecycle; nondeterminism; or registry/risk-mode mismatch.

No weak result may be rescued by adding magnitude, volatility, mean, range,
tail, inventory, or season filters; accepting opposition; changing the
weekday; or extending the hold.

## Validation Plan

Q01 must prove:

1. same-day and uniform `+1` label conventions accept only exact Monday-
   Tuesday-Wednesday history before broker Thursday;
2. both same-sign branches trade in the correct continuation direction while
   opposition, equality, zero, and invalid prices remain flat;
3. arithmetic uses only completed Tuesday/Wednesday endpoints and reconciles
   within `1e-10`;
4. persistent attempts prevent same-Thursday retry after every downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen ATR stop;
6. next-D1 exit, malformed repair, three-day stale guard, and Friday fail-safe
   remain reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver, and
   static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial standard-Wednesday WTI strict flow-agreement continuation card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_wti_wednesday_flow_agreement_g0.md` |
| Q01 Build Validation | TBD | PENDING | TBD |
| Q02 Baseline Screening | TBD | NOT_ENQUEUED | TBD |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue if the tester ceiling permits. It does
not authorize a manual backtest, tester control, live/demo/shadow/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate change, portfolio admission, decorrelation claim, or
correlation waiver.
