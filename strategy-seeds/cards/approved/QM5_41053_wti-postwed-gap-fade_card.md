---
card_schema_version: 2
type: strategy
strategy_id: EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01
variant_id: EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026_S01
source_id: EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026
ea_id: QM5_41053
slug: wti-postwed-gap-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41053_wti-postwed-gap-fade_card.md
execution_contract_status: APPROVED
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
g0_decision: decisions/2026-08-18_wti_post_wednesday_countergap_fade_g0.md
source_approval: decisions/2026-08-18_wti_post_wednesday_countergap_fade_source_approval.md
source_author: "U.S. Energy Information Administration; Larry R. Williams; Yurun Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_authors: "U.S. Energy Information Administration; Larry R. Williams; Yurun Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_citation: "U.S. Energy Information Administration, Weekly Petroleum Status Report; Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Yang, Goncu, and Pantelous (2018), International Review of Financial Analysis 60, 177-196."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and official release schedule."
    location: "Governed lineage strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md"
    quality_tier: A
    role: standard_wednesday_petroleum_information_clock
  - type: practitioner_book
    citation: "Williams, L. R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading."
    location: "OWNER-supplied Tier-A extraction strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt, PDF page 18"
    quality_tier: A
    role: close_to_open_and_open_to_close_price_flow_decomposition
  - type: peer_reviewed_paper
    citation: "Yang, Y., Goncu, A., and Pantelous, A. A. (2018). Momentum and reversal strategies in Chinese commodity futures markets. International Review of Financial Analysis 60, 177-196."
    location: "DOI 10.1016/j.irfa.2018.09.012; governed record strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md"
    quality_tier: B
    role: broad_commodity_reversal_lineage
strategy_mechanic: standard-wednesday-wti-event-session-post-event-countergap-strict-opposition-event-dominance-fade-next-session
sources:
  - "[[sources/EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026]]"
concepts:
  - "[[concepts/wti-information-clock]]"
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/commodity-short-horizon-reversal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, scheduled-event-proxy, price-flow-decomposition, post-event-gap, counter-gap-fade, thursday-entry, one-session-hold, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410530000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-18 completed Thursday-session XTI positions per full post-warm-up year after exact-calendar, strict-opposition, and event-dominance gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 13
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct-WTI event-time sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact Monday-Tuesday-Wednesday identity, completed Wednesday event-session endpoints, frozen Thursday open, strict opposition, event-session dominance, reconciliation, durable Thursday attempt, counter-gap-fade side, and next-D1 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_wednesday_proxy, normalized_energy_label, completed_wednesday_open_close, frozen_thursday_open, strict_cross_boundary_opposition, event_session_dominance, return_reconciliation, thursday_decision_clock, thursday_attempt_state, no_intrabar_leakage, no_late_restart_entry, next_d1_exit, risk_mode_dual, hard_stop_present, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines official EIA event identity, complete Tier-A Williams price-flow extraction, and named peer-reviewed commodity-reversal lineage while declaring the incomplete local paper receipt and untested conjunction; R2 locks weekdays, label normalization, frozen Thursday open, strict opposition, event dominance, reconciliation, fade side, attempt, risk, and lifecycle; R3 uses registered native XTI D1 with session-label risk explicit; R4 is deterministic arithmetic without trained logic, banned signal indicators, or an external feed; canonical dedup returned CLEAN and manual family review separated the disjoint agreement and internal-Wednesday flow states."
---

# QM5_41053 WTI Post-Wednesday Counter-Gap Fade

## Hypothesis

The ordinary Wednesday U.S. petroleum-information clock can displace WTI
during the completed event session. When the frozen next-session open partly
retraces that move without erasing it, the smaller counter-gap may represent
an overnight overreaction rather than a new dominant state. The candidate
fades only that counter-gap by trading in the still-dominant Wednesday
event-session direction through Thursday.

This is a falsifiable event-time, price-flow, and short-horizon reversal
translation. It is not an inventory forecast, a source replication, a
profitability claim, or evidence of low correlation with the certified book.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/EIA-WILLIAMS-YANG-WTI-POSTWEDGAPFADE-2026/source.md`,
approved before card extraction in
`decisions/2026-08-18_wti_post_wednesday_countergap_fade_source_approval.md`
at commit `afdedce04`.

EIA supplies only the ordinary Wednesday petroleum-information clock and the
holiday-shift caveat. Williams supplies completed price-flow segments and the
idea that their separate behavior can be informative. Yang, Goncu, and
Pantelous supply broad commodity-reversal lineage from a different futures
universe and horizon.

The exact Wednesday proxy, D1-label normalization, frozen Thursday-open
endpoint, strict opposition, event-session dominance, reconciliation,
counter-gap-fade side, grace, fixed cash risk, hard stop, spread cap, and
attempt ledger are QM choices. No source performance, significance, density,
cost, drawdown, CFD equivalence, decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,540 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy match. Repository
formula search found this cross-boundary endpoint pair only in the two strict-
agreement carriers. Manual family review fixes the material boundaries:

- `QM5_41050_wti-postwed-gap-agree` uses the same endpoints but admits only
  strict same-sign agreement and follows the common sign. This card admits
  only strict opposition plus event-session dominance and fades the later
  counter-gap; the eligible states are disjoint.
- `QM5_41041_wti-wed-flow-fade` compares Tuesday-close/Wednesday-open with
  Wednesday-open/close and fades a session-dominant completed Wednesday total.
  This card starts with the event session and requires the later Wednesday-
  close/frozen-Thursday-open counter-gap.
- `QM5_41049_wti-wed-overnight-dom` requires opposed internal-Wednesday
  components and pre-event overnight dominance, then follows that total. This
  card requires event-session dominance across the later boundary.
- `QM5_41042_wti-wed-flow-agree` requires agreement inside Wednesday and
  never reads Thursday open.
- `QM5_12590_eia-wti-wpsr-fade` requires range, body, tail, and SMA-stretch
  exhaustion and can hold four days. This card has none of those filters and
  exits at the next D1 boundary.
- `QM5_20133` and `QM5_20134` use exact M30 release-window sequences before
  the completed D1/post-open state exists.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI XNG
  pullback above a slow mean.

Verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XTIUSD.DWX`, D1, slot 0, magic `410530000`.
- Decision clock: first executable tick of broker Thursday.
- Entry grace: no later than 180 minutes after the executable D1 open.
- Formation: current frozen Thursday open plus exact completed Wednesday,
  Tuesday, and Monday sessions.
- Normal exit: first new D1 boundary after entry, ordinarily Friday open.
- Friday fail-safe: broker Friday hour 21.
- Expected cadence: approximately 8-18 completed positions/year.

```text
event_session_flow = ln(WednesdayClose / WednesdayOpen)
post_event_gap      = ln(ThursdayOpen / WednesdayClose)
confirmed_path      = ln(ThursdayOpen / WednesdayOpen)
total_flow          = event_session_flow + post_event_gap

require event_session_flow * post_event_gap < 0
require abs(event_session_flow) > abs(post_event_gap)
require abs(total_flow - confirmed_path) <= 1e-10

event_session_flow > 0 => BUY XTIUSD.DWX
event_session_flow < 0 => SELL XTIUSD.DWX
```

## Rules

These rules are the complete baseline. No inventory value, consensus,
forecast, surprise, magnitude threshold, volatility signal, moving mean,
oscillator, range, body, tail, breakout, season, or external-data filter is
authorized.

## 4. Entry Rules

1. Evaluate only on a new `XTIUSD.DWX` D1 bar while attached to exact
   `XTIUSD.DWX`, D1, EA ID 41053, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require broker Thursday. Support only native same-day D1 labels or one
   uniform `+1` calendar-day energy offset; require normalized current D1 date
   to equal broker date.
4. Read exactly three immediately preceding completed D1 bars. Under the same
   offset, require exact Wednesday, Tuesday, and Monday dates at offsets one,
   two, and three, strict newest-to-oldest order, and adjacent gaps of 20-28
   hours. Missing or shifted history consumes Thursday flat.
5. Derive the attempt key from broker-Thursday `yyyymmdd`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that Thursday.
6. Require elapsed time from executable D1 open to be 0-180 minutes. A later
   attachment consumes the attempt and never backfills.
7. Require positive finite Wednesday open/close and frozen Thursday open.
   Compute exactly the three returns above. Thursday high, low, close, volume,
   later ticks, and every post-open price are forbidden from the signal.
8. Reconcile `total_flow` to `confirmed_path` within `1e-10`. Require both
   components nonzero, their product strictly negative, and strict
   `abs(event_session_flow) > abs(post_event_gap)`. Agreement, exact zero,
   equality, counter-gap dominance, invalid arithmetic, or failed
   reconciliation consumes Thursday flat.
9. Positive `event_session_flow` buys WTI and negative sells WTI. Magnitude
   never changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.0 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 1,500 points.
    Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

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

- Exact host, D1, EA 41053, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses completed prices plus only the
  frozen Thursday open.
- Exact normalized Monday-Tuesday-Wednesday history, strict opposition,
  event-session dominance, and reconciliation are load-bearing.
- Opening grace, quote, spread, ATR, sizing, and stop geometry must be valid.
  Failure after attempt persistence consumes Thursday.

## 7. Trade Management Rules

- Own at most one position under magic `410530000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed and stale repair on every tick before entry logic.
- Persist the last attempted broker-Thursday key in terminal global state so
  a restart cannot create a second weekly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

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
| `strategy_reconcile_tolerance` | 1e-10 | cross-boundary return identity |
| `qm_friday_close_enabled` | true | fail-safe exit |
| `qm_friday_close_hour_broker` | 21 | Friday cutoff |

No sweep, magnitude threshold, dominance ratio, weekday, endpoint, direction,
or lifecycle change is authorized.

## Data Requirements

- Native `XTIUSD.DWX` D1 OHLC and tick timestamps from the registered factory
  history route.
- Broker clock, symbol quotes/properties, positions, deal history, and terminal
  global variables.
- No inventory number, external calendar, analyst forecast, futures curve,
  volume, open interest, API, CSV, or manual signal input.

## Source-Defined Rules

EIA defines the ordinary Wednesday information clock and warns that holiday
weeks can shift. Williams defines close-to-open and open-to-close price-flow
objects. Yang, Goncu, and Pantelous provide broad commodity-reversal lineage.
No source defines this exact cross-boundary opposition, dominance, Thursday
entry, side, stop, or lifecycle.

## QM Interpretations

QM fixes the event proxy, label normalization, frozen Thursday open, strict
opposition, event-session dominance, reconciliation, counter-gap-fade side,
grace, durable attempt, fixed risk, ATR stop, spread ceiling, and next-D1
exit. They are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and Friday-close orchestration remain authoritative. Both
news axes are OFF. This non-live card creates no live mapping, deployment
manifest, execution-contract registry row, or promotion entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. The first later D1 boundary is the ordinary strategy exit.
4. Framework Friday hour 21 and the three-day guard are stale fail-safes.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and a terminal-global attempt
key. It has no external feed, event-calendar file, fitted artifact, trained
output, or manual signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong calendar or
endpoints, current-price leakage beyond Thursday open, absent strict
opposition or event-session dominance, wrong side, failed reconciliation,
late/repeated entry, wrong lifecycle, nondeterminism, invalid risk mode, or an
unusable Wednesday proxy. Any change to weekday, endpoints, opposition,
dominance, direction, stop, or hold creates a new identity. Q09 alone may
establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, history, frozen open, flows, opposition, dominance, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-D1 and stale repair | Trade Close | strategy lifecycle helper plus framework Friday fail-safe |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; leakage beyond frozen Thursday open; incorrect
endpoints, opposition, dominance, reconciliation, or side; late/repeated
entry; missing stop; wrong lifecycle; nondeterminism; or registry/risk
mismatch.

No weak result may be rescued by adding a range, body, tail, magnitude,
volatility, mean, inventory, forecast, weather, or season filter; accepting
agreement or counter-gap dominance; changing the weekday; or extending the
hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label conventions accept only exact Monday-
   Tuesday-Wednesday history before broker Thursday;
2. all sign pairings, equality, zero, and invalid prices select only strict
   opposition plus event-session dominance with the correct fade side;
3. arithmetic uses completed Wednesday endpoints plus only frozen Thursday
   open and reconciles within `1e-10`;
4. persistent attempts prevent same-Thursday retry after every downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen ATR stop;
6. next-D1 exit, Friday fail-safe, malformed repair, and stale guard remain
   reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial post-Wednesday counter-gap-fade card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-18 | APPROVED | `decisions/2026-08-18_wti_post_wednesday_countergap_fade_g0.md` |
| Q01 Build Validation | - | NOT_STARTED | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## Safety Boundary

This card authorizes one branch-only non-live build, one canonical D1
`RISK_FIXED` backtest setfile, strict Q01 validation, and one paced target-only
Q02 enqueue below the governed tester ceiling. It does not authorize a manual
tester run, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, a deploy or T_Live manifest, a portfolio-gate edit, portfolio
admission, a decorrelation claim, or a correlation waiver.
