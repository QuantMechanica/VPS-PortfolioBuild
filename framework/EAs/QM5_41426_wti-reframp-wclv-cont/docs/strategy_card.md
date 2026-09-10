---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910_S01
variant_id: EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910_S01
source_id: EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910
ea_id: QM5_41426
slug: wti-reframp-wclv-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41426_wti-reframp-wclv-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41426_wti_refinery_ramp_weekly_close_location_continuation_g0.md
source_approval: decisions/2026-09-10_wti_refinery_ramp_weekly_close_location_continuation_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "EIA refinery-maintenance and pre-summer utilization context; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_government_and_peer_reviewed_bounded_mechanization
    citation: "EIA refinery-utilization-ramp context plus Moskowitz-Ooi-Pedersen WTI momentum and governed completed-week close-location lineage."
    location: strategy-seeds/sources/EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910/source.md
    quality_tier: A_lineages_with_cross_source_calendar_and_weekly_translation_risk
    role: refinery_ramp_context_and_directional_close_location_lineage
strategy_mechanic: normalized-weekly-wti-april-july-refinery-utilization-ramp-parent-close-to-newest-close-strict-positive-return-newest-week-upper-tercile-close-location-long-continuation-one-week-hold
sources: ["[[sources/EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910]]"]
concepts: ["[[concepts/time-series-momentum]]", "[[concepts/refinery-utilization-ramp]]", "[[concepts/completed-week-close-location]]"]
indicators: ["[[indicators/completed-week-ohlc]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, refinery-ramp, completed-week-close-location, weekly-momentum, long-only, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 414260000
period: D1
timeframe: D1
direction: long_only
expected_trade_frequency: "Approximately 5-8 completed positions per full post-warm-up year after the positive-return and upper-tercile gates; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; eligible months 4,5,6,7; two immediately completed adjacent weeks with 3-5 sessions each; strictly positive parent-close to newest-close log return; newest close location strictly above 2/3; long-only continuation; 30 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: G0
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a long-only WTI refinery-ramp completed-week close-location continuation distinct from the year-round symmetric outer-fifth rule, the one-week April-May open-to-close sign sleeve, daily May-July squeeze/pullback builds, and incumbent XNG logic. Verify exact two-week membership, parent-close endpoint, upper-tercile gate, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, refinery_ramp_month_gate, normalized_week_clock, two_completed_week_membership, parent_close_to_newest_close_endpoint, strict_positive_sign, strict_upper_tercile_close_location, long_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 one canonical governed child source with complete official EIA and peer-reviewed WTI lineage plus explicit translation risk; R2 exact mechanical long-only April-July two-week endpoint/range continuation; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate and three fuzzy family neighbors manually resolved."
---

# QM5_41426 WTI Refinery-Ramp Weekly Close-Location Continuation

## Hypothesis

Planned refinery maintenance generally peaks in late February and March before
utilization rises heading into summer. During April-July, a positive completed
weekly close-to-close move that also settles in the newest week's upper
tercile may identify persistent crude demand pressure for one further week.
This exact price-only interaction is unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The single source of record is
`strategy-seeds/sources/EIA-MOP-WTI-REFRAMP-WCLV-CONT-20260910/source.md`.
EIA supports only refinery-ramp context; the governed MOP packet supports
broader own-return continuation and records the weekly close-location
translation. Neither establishes this WTI CFD result.

The canonical checker found no exact identity and surfaced three fuzzy family
neighbors. `QM5_41080` is year-round, symmetric, and requires outer-fifth
locations; `QM5_41081` trades XNG. `QM5_41422` uses one completed week's
open-to-close sign in April-May without a range-location gate. This card uses
two adjacent completed packages, parent-close to newest-close return, strict
upper-tercile confirmation, and April-July. A newest-week opening gap can make
the two return signs disagree, so neither signal contains the other. Existing
May-July refinery squeeze/pullback cards use current D1 patterns rather than
this frozen completed-week endpoint/range state.

## Rules

### Entry

1. Run only on the setfile-bound `XTIUSD.DWX` D1 host with EA 41426, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is April, May, June, or July and
   entry is within 180 elapsed session minutes.
4. Reconstruct exactly the two immediately completed adjacent normalized
   weeks; each must contain three through five valid, unique D1 sessions.
5. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
6. If `r > 0` and `clv > 2/3`, buy. Equality, a nonpositive return, a lower
   close location, zero range, malformed/stale history, or nonfinite arithmetic
   stays flat and consumes the week. Never sell.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid
   symbol metadata, and one normalized frozen `3.5*ATR` hard stop.

### Exit And Management

Close on the first processed tick in the next normalized broker week. Ten
elapsed days is stale repair. Immediately flatten duplicate, wrong-symbol,
wrong-magic, non-long, missing-stop, take-profit-bearing, future-dated, or
invalid-volume owned exposure. The broker stop and framework kill switch are
authoritative. No target, intraweek signal flip, trail, break-even, partial
close, scale-in, pyramid, grid, martingale, or discretionary exit is allowed.

### No-Trade And Framework Inputs

Fail closed on wrong host/period/identity/slot/risk mode, unlocked
`strategy_*` configuration, late restart, consumed week, ineligible month,
bad packages, nonpositive return, non-upper-tercile close, spread, quote, ATR,
stop, sizing, or order state. Framework RNG, news, and Friday-close inputs
remain configurable and are never equality-pinned by the EA. Stress rejection
is checked only for finiteness and inclusive `0..1` range.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_ramp_month_1..4` | 4 / 5 / 6 / 7 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_clv_upper` | 0.6666666666666667 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, packages, endpoint, threshold, direction, carrier,
stop, hold, spread, or retry contract requires a new identity.

## Risk And Data

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Runtime uses configured-symbol D1 OHLC/timestamps,
broker clock, quotes, symbol properties, positions, deal history, and terminal-
global attempt state only. No refinery, inventory, curve, volume, open-
interest, file, API, trained output, optimizer result, or portfolio state is
read at runtime.

WTI gaps, roll/basis/financing, label sensitivity, sparse seasonal samples,
hard-stop slippage, regime instability, source translation, and overlap with
other WTI sleeves can dominate. Q02 owns activity/economics; unchanged Q09
alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk mode, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, ramp gate, packages, endpoint, close location, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all four eligible months, ineligible boundaries, qualifying
long entry, negative/zero/equality/lower-location flat states, three-to-five
sessions per week, adjacency, current-week exclusion, attempt persistence,
frozen stop, next-week exit, card lint, magic resolver, PACER audit, reference
tests, and strict compile/build checks. Q02 retires on zero positions, fewer
than five completed positions in any full scored year, nonpositive governed
economics, or any contract mismatch. No weak result may be rescued by tuning;
a material rule change requires a new identity and G0 review. Q09 alone may
establish realized portfolio diversification.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build/Q01, one
fixed-risk backtest set, and one paced Q02 enqueue below the CPU ceiling.
Forbidden: manual backtests, optimization, portfolio-gate edits or admission,
correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-10 | APPROVED_SOURCE | `decisions/2026-09-10_wti_refinery_ramp_weekly_close_location_continuation_source_approval.md` |
| G0 Research Intake | 2026-09-10 | APPROVED | decision above |
| Q01 Build Validation | - | NOT_BUILT | pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 and CPU ceiling |
