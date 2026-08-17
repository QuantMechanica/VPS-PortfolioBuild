---
card_schema_version: 2
type: strategy
strategy_id: EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01
variant_id: EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026_S01
source_id: EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026
ea_id: QM5_41054
slug: xng-postthu-gap-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41054_xng-postthu-gap-fade_card.md
execution_contract_status: APPROVED
created: 2026-08-18
created_by: Research+Development
last_updated: 2026-08-18
g0_status: APPROVED
g0_decision: decisions/2026-08-18_xng_post_thursday_countergap_fade_g0.md
source_approval: decisions/2026-08-18_xng_post_thursday_countergap_fade_source_approval.md
source_author: "U.S. Energy Information Administration; Larry R. Williams; Yurun Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_authors: "U.S. Energy Information Administration; Larry R. Williams; Yurun Yang; Ahmet Goncu; Athanasios A. Pantelous"
source_citation: "U.S. Energy Information Administration, Weekly Natural Gas Storage Report; Williams (1999), Long-Term Secrets to Short-Term Trading, Wiley Trading; Yang, Goncu, and Pantelous (2018), International Review of Financial Analysis 60, 177-196."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and official release schedule."
    location: "Governed lineage strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md"
    quality_tier: A
    role: standard_thursday_natural_gas_information_clock
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
strategy_mechanic: standard-thursday-xng-event-session-post-event-countergap-strict-opposition-event-dominance-fade-same-friday-close
sources:
  - "[[sources/EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026]]"
concepts:
  - "[[concepts/natural-gas-information-clock]]"
  - "[[concepts/price-flow-decomposition]]"
  - "[[concepts/commodity-short-horizon-reversal]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, natural-gas, scheduled-event-proxy, price-flow-decomposition, post-event-gap, counter-gap-fade, friday-entry, friday-close, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 410540000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 8-18 completed XNG Friday-session positions per full post-warm-up year after exact-calendar, strict-opposition, and event-dominance gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 13
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SESSION_LABEL_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_QUEUED
review_focus: "Falsify a different-logic XNG event-time sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact Tuesday-Wednesday-Thursday identity, completed Thursday event-session endpoints, frozen Friday open, strict opposition, event-session dominance, reconciliation, durable Friday attempt, counter-gap-fade side, and broker-hour-21 flattening. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_standard_thursday_proxy, normalized_energy_label, completed_thursday_open_close, frozen_friday_open, strict_cross_boundary_opposition, event_session_dominance, return_reconciliation, friday_decision_clock, friday_attempt_state, no_intrabar_leakage, no_late_restart_entry, friday_hour21_exit, risk_mode_dual, hard_stop_present, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 combines official EIA event identity, complete Tier-A Williams price-flow extraction, and named peer-reviewed commodity-reversal lineage while declaring the incomplete local paper receipt and untested conjunction; R2 locks weekdays, label normalization, frozen Friday open, strict opposition, event dominance, reconciliation, fade side, attempt, risk, and lifecycle; R3 uses registered native XNG D1 with session-label risk explicit; R4 is deterministic arithmetic without trained logic, banned signal indicators, or an external feed; canonical dedup returned CLEAN and manual family review separated the disjoint agreement and internal-Thursday flow states."
---

# QM5_41054 XNG Post-Thursday Counter-Gap Fade

## Hypothesis

The ordinary Thursday U.S. natural-gas storage information clock can displace
XNG during the completed event session. When the frozen next-session open
partly retraces that move without erasing it, the smaller counter-gap may be
an overnight overreaction rather than a new dominant state. The candidate
enters at the first executable Friday tick in the still-dominant Thursday
event-session sign and exits at the framework Friday cutoff.

This is a falsifiable event-time, price-flow, and short-horizon reversal
translation. It is not an inventory forecast, a source replication, a
profitability claim, or evidence of low correlation with the certified book.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/EIA-WILLIAMS-YANG-XNG-POSTTHUGAPFADE-2026/source.md`,
approved before card extraction in
`decisions/2026-08-18_xng_post_thursday_countergap_fade_source_approval.md` at
commit `860798f0a`.

EIA supplies only the ordinary Thursday storage-information clock and
holiday-shift caveat. Williams supplies completed price-flow segments and the
idea that their separate behavior can be informative. Yang, Goncu, and
Pantelous supply broad commodity-reversal lineage from a different futures
universe and horizon; the local record is not a complete-paper receipt.

The exact Thursday proxy, D1-label normalization, frozen Friday-open endpoint,
strict opposition, event-session dominance, reconciliation, counter-gap-fade
side, grace, fixed cash risk, hard stop, spread cap, and attempt ledger are QM choices. No
source performance, significance, density, cost, drawdown, CFD equivalence,
decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,541 EA-registry rows and 625
root-card files and returned `CLEAN` with no exact or fuzzy match. Manual
family review fixes the material boundaries:

- `QM5_41052_xng-postthu-gap-agree` uses the same endpoints but admits only
  strict same-sign agreement and follows the common sign. This card admits
  only strict opposition plus event-session dominance and fades the later
  counter-gap; the eligible states are disjoint.
- `QM5_41044_xng-thu-flow-fade` compares the earlier Wednesday-close-to-
  Thursday-open pre-event flow with the completed Thursday session and holds
  across the weekend. This card starts with the completed event session and
  requires the later Thursday-close/frozen-Friday-open counter-gap.
- `QM5_41043_xng-thu-flow-agree` and `QM5_41048_xng-thu-trend-agree` never use
  the frozen Friday-opening counter-gap.
- `QM5_12898_xng-eia-multiday-drift` requires event range, body, close
  location, moving-average state, and a multiday hold. This card has none of
  those gates.
- `QM5_20124`, `QM5_20128`, and `QM5_20132` trade M30 release-window impulse,
  reclaim, or breakout objects before the completed D1/next-open state exists.
- `QM5_41053_wti-postwed-gap-fade` shares the abstract construction but uses
  WTI, a Wednesday petroleum clock, a Thursday decision, a tighter oil spread
  cap, and a next-D1 lifecycle. No carrier result transfers.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI
  pullback above a slow mean.

Verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Markets, Clock, And Formula

- Host and target: exact `XNGUSD.DWX`, D1, slot 0, magic `410540000`.
- Decision clock: first executable tick of broker Friday.
- Entry grace: no later than 180 minutes after the executable D1 open.
- Formation: current frozen Friday open plus exact completed Thursday,
  Wednesday, and Tuesday sessions.
- Normal exit: framework Friday close at broker hour 21.
- Repair exits: first later D1 boundary and four elapsed calendar days.
- Expected cadence: approximately 8-18 completed positions/year.

```text
event_session_flow = ln(ThursdayClose / ThursdayOpen)
post_event_gap      = ln(FridayOpen / ThursdayClose)
confirmed_path      = ln(FridayOpen / ThursdayOpen)
total_flow          = event_session_flow + post_event_gap

require event_session_flow * post_event_gap < 0
require abs(event_session_flow) > abs(post_event_gap)
require abs(total_flow - confirmed_path) <= 1e-10

event_session_flow > 0 => BUY XNGUSD.DWX
event_session_flow < 0 => SELL XNGUSD.DWX
```

## Rules

These rules are the complete baseline. No storage value, forecast, surprise,
magnitude, volatility signal, moving mean, oscillator, range, body, tail,
breakout, season, or external-data filter is authorized.

## 4. Entry Rules

1. Evaluate only on a new `XNGUSD.DWX` D1 bar while attached to exact
   `XNGUSD.DWX`, D1, EA ID 41054, slot 0.
2. Process malformed and stale owned exposure before every entry-only gate.
3. Require broker Friday. Support only native same-day D1 labels or one
   uniform `+1` calendar-day energy offset; require normalized current D1 date
   to equal broker date.
4. Read exactly three immediately preceding completed D1 bars. Under the same
   offset, require exact Thursday, Wednesday, and Tuesday dates at offsets one,
   two, and three, strict newest-to-oldest order, and adjacent gaps of 20-28
   hours. Missing or shifted history consumes Friday flat.
5. Derive the attempt key from broker-Friday `yyyymmdd`. Persist it before
   history validation, return calculation, news, spread, quote, ATR, sizing,
   or order gates. Never retry that Friday.
6. Require elapsed time from executable D1 open to be 0-180 minutes. A later
   attachment consumes the attempt and never backfills.
7. Require positive finite Thursday open/close and frozen Friday open. Compute
   exactly the three returns above. Friday high, low, close, volume, and every
   post-open price are forbidden from the signal.
8. Reconcile `total_flow` to `confirmed_path` within `1e-10`. Require both
   components nonzero, their product strictly negative, and strict
   `abs(event_session_flow) > abs(post_event_gap)`. Agreement, exact zero,
   equality, counter-gap dominance, invalid arithmetic, or failed
   reconciliation consumes Friday flat.
9. Positive `event_session_flow` buys XNG and negative sells XNG. Magnitude
   never changes size.
10. Require valid completed-bar ATR(20,D1). Place one frozen hard stop at
    `3.5 * ATR`; use no take-profit.
11. Require a valid quote and no genuinely positive spread above 3,000 points.
    Modeled zero `.DWX` spread is valid.
12. Submit one market order once. No pending order, retry, scale-in, grid,
    martingale, pyramid, hedge, or companion leg exists.

## 5. Exit Rules

1. Framework Friday close at broker hour 21 is the ordinary exit.
2. Close any survivor at the first observable D1 boundary strictly later than
   the entry D1 session.
3. Close after four elapsed calendar days as a final stale guard.
4. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time exposure.
5. The frozen broker hard stop and framework kill switch remain authoritative.
6. No target, reversal, trailing stop, break-even move, partial exit, or
   discretionary close is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41054, and slot 0.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes are OFF; the signal uses native prices fixed by Friday open.
- Exact normalized Tuesday-Wednesday-Thursday history, strict opposition,
  event-session dominance, and reconciliation are load-bearing.
- Opening grace, quote, spread, ATR, sizing, and stop geometry must be valid.
  Failure after attempt persistence consumes Friday.

## 7. Trade Management Rules

- Own at most one position under magic `410540000`.
- Freeze the original hard stop; never widen, trail, or remove it.
- Run malformed and stale repair on every tick before entry logic.
- Persist the last attempted broker-Friday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Do not add, pyramid, grid, hedge, partially close, or reverse.

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
| `strategy_reconcile_tolerance` | 1e-10 | cross-boundary return identity |
| `qm_friday_close_enabled` | true | ordinary strategy exit |
| `qm_friday_close_hour_broker` | 21 | Friday cutoff |

No sweep, magnitude threshold, dominance ratio, weekday, endpoint, direction,
or lifecycle change is authorized.

## Data Requirements

- Native `XNGUSD.DWX` D1 OHLC and tick timestamps from the registered factory
  history route.
- Broker clock, symbol quotes/properties, positions, deal history, and terminal
  global variables.
- No storage number, external calendar, analyst forecast, weather series,
  futures curve, volume, open interest, API, CSV, or manual signal input.

## Source-Defined Rules

EIA defines the ordinary Thursday information clock and warns holiday weeks
can shift. Williams defines close-to-open and open-to-close price-flow
objects. Yang, Goncu, and Pantelous provide broad commodity-reversal lineage.
No source defines this exact cross-boundary opposition, dominance, Friday
entry, side, stop, or lifecycle.

## QM Interpretations

QM fixes the event proxy, label normalization, frozen Friday open, strict
opposition, event-session dominance, reconciliation, counter-gap-fade side,
grace, durable attempt, fixed risk, ATR stop, spread ceiling, and same-Friday
exit. They are pre-result falsification choices.

## Framework Execution Overrides

The framework kill switch, ownership checks, fixed-risk sizing contract,
position/deal state, and Friday-close orchestration remain authoritative. Both
news axes are OFF. This non-live card creates no live mapping, deployment
manifest, execution-contract registry row, or promotion entitlement.

## Exit Precedence

1. Framework kill switch and broker hard stop remain authoritative.
2. Malformed, duplicate, wrong-side, or missing-stop exposure is flattened.
3. Framework Friday hour 21 is the ordinary strategy exit.
4. First-later-D1 and four-day closes are repairs for a survivor.

## Runtime Data Dependencies

Runtime uses only native D1 OHLC/timestamps, broker time, current quotes,
symbol contract properties, positions, deals, and a terminal-global attempt
key. It has no external feed, event-calendar file, fitted artifact, trained
output, or manual signal input.

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed positions
per full post-warm-up year, nonpositive governed economics, wrong calendar or
endpoints, current-price leakage beyond Friday open, absent strict opposition
or event-session dominance, failed reconciliation, wrong side, late/repeated
entry, wrong Friday lifecycle, nondeterminism, invalid risk mode, or an
unusable Thursday proxy. Any change to weekday, endpoints, opposition,
dominance, direction, stop, or hold creates a new identity. Q09 alone may
establish realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, attempt, history, frozen open, flows, opposition, dominance, side, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| Friday hour-21 and survivor repair | Trade Close | framework Friday close plus strategy repair helper |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both modes OFF |

## Kill Criteria

Retire rather than tune on fewer than five completed positions per full post-
warm-up year; zero trades; nonpositive governed economics; wrong date sequence
or label normalization; leakage beyond frozen Friday open; incorrect
endpoints, opposition, dominance, reconciliation, or side; late/repeated
entry; missing stop; wrong Friday lifecycle; nondeterminism; or registry/risk
mismatch.

No weak result may be rescued by adding a range, body, tail, magnitude,
volatility, mean, inventory, forecast, weather, or season filter; accepting
agreement or counter-gap dominance; changing the weekday; or extending the
hold.

## Validation Plan

Q01 must prove:

1. native and uniform `+1` label conventions accept only exact Tuesday-
   Wednesday-Thursday history before broker Friday;
2. all sign pairings, equality, zero, and invalid prices select only strict
   opposition plus event-session dominance with the correct fade side;
3. arithmetic uses completed Thursday endpoints plus only frozen Friday open
   and reconciles within `1e-10`;
4. persistent attempts prevent same-Friday retry after every downstream
   failure and restart;
5. fixed-risk sizing uses a valid frozen ATR stop;
6. framework Friday close, later-D1 repair, malformed repair, and stale guard
   remain reachable; and
7. strict compile, card lint, build checks, setfile schema, magic resolver,
   and static Q01 validation pass.

Q02 alone may measure density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-18 | initial post-Thursday counter-gap fade Friday card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-18 | APPROVED | `decisions/2026-08-18_xng_post_thursday_countergap_fade_g0.md` |
| Q01 Build Validation | - | PENDING | Build not started |
| Q02 Baseline Screening | - | NOT_QUEUED | Requires Q01 PASS and an available governed tester slot |

## Safety Boundary

This card authorizes a non-live build, Q01 validation, one D1 backtest setfile,
and one paced target-only Q02 enqueue only below the tester and CPU ceilings.
It does not authorize a manual backtest, tester control, live/demo/shadow/
stress/optimization preset, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio-gate change, portfolio admission, decorrelation claim, or
correlation waiver.
