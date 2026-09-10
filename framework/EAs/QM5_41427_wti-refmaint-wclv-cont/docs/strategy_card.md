---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910_S01
variant_id: EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910_S01
source_id: EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910
ea_id: QM5_41427
slug: wti-refmaint-wclv-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41427_wti-refmaint-wclv-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41427_wti_refinery_maintenance_weekly_close_location_continuation_g0.md
source_approval: decisions/2026-09-10_wti_refinery_maintenance_weekly_close_location_continuation_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "EIA refinery-maintenance context; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_government_and_peer_reviewed_bounded_mechanization
    citation: "EIA refinery-maintenance context plus Moskowitz-Ooi-Pedersen WTI momentum and governed completed-week close-location lineage."
    location: strategy-seeds/sources/EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910/source.md
    quality_tier: A_lineages_with_cross_source_calendar_and_weekly_translation_risk
    role: refinery_maintenance_context_and_directional_close_location_lineage
strategy_mechanic: normalized-weekly-wti-refinery-maintenance-february-march-september-october-two-completed-weeks-parent-close-to-newest-close-strict-negative-return-newest-week-lower-tercile-close-location-short-continuation-one-week-hold
sources: ["[[sources/EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910]]"]
concepts: ["[[concepts/time-series-momentum]]", "[[concepts/refinery-maintenance-season]]", "[[concepts/completed-week-close-location]]"]
indicators: ["[[indicators/completed-week-ohlc]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, refinery-maintenance, completed-week-close-location, weekly-momentum, short-only, atr-hard-stop, time-stop, low-frequency]
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
magic: 414270000
period: D1
timeframe: D1
direction: short_only
expected_trade_frequency: "Approximately 5-8 completed positions per full post-warm-up year after the negative-return and lower-tercile gates; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; eligible months 2,3,9,10; two immediately completed adjacent weeks with 3-5 sessions each; strictly negative parent-close to newest-close log return; newest close location strictly below 1/3; short-only continuation; 30 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a short-only WTI refinery-maintenance completed-week close-location continuation distinct from the year-round symmetric outer-fifth rule, the one-week maintenance open-to-close sign sleeve, and the April-July upper-tercile ramp build. Verify exact two-week membership, parent-close endpoint, lower-tercile gate, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, refinery_maintenance_month_gate, normalized_week_clock, two_completed_week_membership, parent_close_to_newest_close_endpoint, strict_negative_sign, strict_lower_tercile_close_location, short_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 one canonical governed child source with complete official EIA and peer-reviewed WTI lineage plus explicit translation risk; R2 exact mechanical short-only maintenance two-week endpoint/range continuation; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate and four fuzzy family neighbors manually resolved."
---

# QM5_41427 WTI Refinery-Maintenance Weekly Close-Location Continuation

## Hypothesis

Planned refinery maintenance concentrates in late winter and fall, when crude
and product demand are seasonally lower. During February, March, September,
and October, a negative completed weekly close-to-close move that also settles
in the newest week's lower tercile may identify persistent crude pressure for
one further week. This exact price-only interaction is unproven and belongs to
Q02 onward.

## Source Traceability And Non-Duplicate Decision

The single source of record is
`strategy-seeds/sources/EIA-MOP-WTI-REFMAINT-WCLV-CONT-20260910/source.md`.
EIA supports only refinery-maintenance context; the governed MOP packet
supports broader own-return continuation and records the weekly close-location
translation. Neither establishes this WTI CFD result.

The canonical checker found no exact identity and surfaced four fuzzy family
neighbors. `QM5_41421` uses one completed week's open-to-close sign without a
range-location gate. This card uses two adjacent completed packages,
parent-close to newest-close return, and strict lower-tercile confirmation. An
opening gap can make the return signs disagree. `QM5_41426` is an April-July
positive/upper-tercile long rule. `QM5_41080` is year-round, symmetric, and
outer-fifth; `QM5_41081` trades XNG. Calendar, endpoint, threshold, short side,
and lifecycle are jointly load-bearing.

## Rules

### Entry

1. Run only on the setfile-bound `XTIUSD.DWX` D1 host with EA 41427, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is February, March, September,
   or October and entry is within 180 elapsed session minutes.
4. Reconstruct exactly the two immediately completed adjacent normalized
   weeks; each must contain three through five valid, unique D1 sessions.
5. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
6. If `r < 0` and `clv < 1/3`, sell. Equality, a nonnegative return, a higher
   close location, zero range, malformed/stale history, or nonfinite arithmetic
   stays flat and consumes the week. Never buy.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid
   symbol metadata, and one normalized frozen `3.5*ATR` hard stop.

### Exit And Management

Close on the first processed tick in the next normalized broker week. Ten
elapsed days is stale repair. Immediately flatten duplicate, wrong-symbol,
wrong-magic, non-short, missing-stop, take-profit-bearing, future-dated, or
invalid-volume owned exposure. The broker stop and framework kill switch are
authoritative. No target, intraweek signal flip, trail, break-even, partial
close, scale-in, pyramid, grid, martingale, or discretionary exit is allowed.

### No-Trade And Framework Inputs

Fail closed on wrong host/period/identity/slot/risk mode, unlocked
`strategy_*` configuration, late restart, consumed week, ineligible month,
bad packages, nonnegative return, non-lower-tercile close, spread, quote, ATR,
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
| `strategy_maintenance_month_1..4` | 2 / 3 / 9 / 10 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_clv_lower` | 0.3333333333333333 |
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
| week clock, maintenance gate, packages, endpoint, close location, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all four eligible months, ineligible boundaries, qualifying
short entry, positive/zero/equality/higher-location flat states, three-to-five
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
| G0 Source Approval | 2026-09-10 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-10 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-10 | PENDING | build not started |
| Q02 Baseline Screening | 2026-09-10 | NOT_ENQUEUED | gated on Q01 and CPU admission |
