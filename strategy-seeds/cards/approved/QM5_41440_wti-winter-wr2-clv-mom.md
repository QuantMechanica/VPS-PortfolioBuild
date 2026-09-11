---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911_S01
variant_id: BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911_S01
source_id: BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911
ea_id: QM5_41440
slug: wti-winter-wr2-clv-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41440_wti-winter-wr2-clv-mom.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41440_wti_winter_wr2_clv_momentum_g0.md
source_approval: decisions/2026-09-11_wti_winter_wr2_clv_momentum_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; Crabel range-state lineage; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum."
source_citations:
  - type: peer_reviewed_and_reputable_bounded_mechanization
    citation: "Peer-reviewed WTI seasonality and futures time-series-momentum evidence plus governed reputable Crabel range-state lineage."
    location: strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911/source.md
    quality_tier: A_and_B_lineages_with_cross_source_and_horizon_translation_risk
    role: november_may_calendar_range_expansion_and_long_continuation_lineage
strategy_mechanic: normalized-weekly-wti-november-through-may-two-completed-weeks-newest-strict-wider-range-than-prior-strict-upper-quartile-final-close-long-only-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911]]"]
concepts: ["[[concepts/wti-winter-seasonality]]", "[[concepts/completed-week-range-expansion]]", "[[concepts/time-series-momentum]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, winter-premium, weekly-range-expansion, close-location, long-only, weekly-continuation, atr-hard-stop, time-stop, low-frequency]
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
magic: 414400000
period: D1
timeframe: D1
direction: long_only
expected_trade_frequency: "Approximately 5-12 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3,4,5; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly greater than prior; newest CLV strictly above 0.75; long-only continuation; 30 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q01_compile_work_item: 52424a9e-3256-45af-aa79-1e8b3101a910
q01_build_report: D:/QM/reports/work_items/52424a9e-3256-45af-aa79-1e8b3101a910/QM5_41440/COMPILE_EA/compile_evidence.json
q02_status: ENQUEUED
q02_work_item: cef7693f-73af-432a-93be-bef4123a0de0
q02_receipt: D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/52424a9e-3256-45af-aa79-1e8b3101a910_cef7693f-73af-432a-93be-bef4123a0de0.json
force_build: true
review_focus: "Falsify a WTI November-May range-expansion/upper-quartile continuation distinct from the certified XNG oscillator, monthly WTI winter sign rules, hurricane-only WR2/CLV rules, and XNG winter WR2/CLV rule. Verify exact weeks, strict inequalities, long-only side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, november_may_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_expansion, strict_upper_quartile_close, long_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed and governed reputable lineage with explicit translation risk; R2 exact mechanical WTI winter WR2/CLV long continuation; R3 XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41440 WTI Winter WR2 Upper-Quartile Continuation

## Hypothesis

During the documented November-through-May WTI winter regime, an expanding completed week that
settles in its upper quartile may identify persistent price discovery. Buy at the next normalized
week boundary and hold one week. This exact Darwinex-CFD rule is unproven and belongs to Q02.

## Source Traceability And Non-Duplicate Decision

The source packet is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-WINTER-WR2-CLV-MOM-20260911/source.md`.
Burakov, Freidin, and Solovyev supply the WTI November-May calendar; Moskowitz, Ooi, and Pedersen
supply own-return continuation lineage; governed Crabel work supplies range-state lineage and
completed-week construction. None establishes this conjunction.

The canonical scan found no exact match. The two WTI winter fuzzy neighbors use one completed
calendar-month return sign and no weekly range/CLV state. `QM5_41438` trades XNG symmetrically
only in November-March. `QM5_41434/41435` trade a disjoint August-October WTI hurricane state.
Certified `QM5_12567` is a two-day cumulative-RSI XNG pullback. Carrier, full November-May clock,
two-week range comparison, upper-quartile close, long-only side, and one-week hold are jointly
load-bearing.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41440, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is November, December, January, February, March,
   April, or May and entry is within 180 elapsed minutes.
4. Reconstruct exactly the two immediately completed consecutive normalized weeks, each with
   three through five valid, unique, ordered D1 sessions.
5. Require positive finite ranges and require the newest range to be strictly greater than the
   preceding range; equality is flat.
6. Compute newest-week `CLV=(final_close-low)/(high-low)`. Buy only when `CLV>0.75`; equality or
   lower values are flat. Weekly body sign is irrelevant. There is no short branch.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, ineligible month, malformed packages, nonexpanding range, CLV at or
below 0.75, spread, quote, ATR, stop, sizing, or order state. Framework RNG, news, and Friday-close
inputs remain configurable and are never equality-pinned. Stress rejection is checked only for
finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, non-long, missing-stop,
take-profit-bearing, future-dated, or invalid-volume owned exposure. No trail, break-even,
partial close, scale-in, pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| param | default |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1` | 11 |
| `strategy_winter_month_2` | 12 |
| `strategy_winter_month_3` | 1 |
| `strategy_winter_month_4` | 2 |
| `strategy_winter_month_5` | 3 |
| `strategy_winter_month_6` | 4 |
| `strategy_winter_month_7` | 5 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_clv_upper` | 0.75 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, strict range rank, CLV threshold, direction, carrier, stop,
hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

Burakov et al. supply the November-May WTI winter interval. Moskowitz-Ooi-Pedersen and governed
Crabel records supply broad own-return continuation and range-state lineage. They do not supply
this exact weekly conjunction or its thresholds.

## QM Interpretations

Monday anchors, two completed weeks, strict range expansion, upper-quartile threshold, boundary
entry, one-week hold, retry semantics, and every numeric threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the weekly lifecycle is intact. Those
framework inputs and RNG seed remain configurable and unpinned. Stress rejection receives only
range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed or non-long owned-exposure repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties, positions, deal
history, ATR, and terminal-global attempt state only. No weather, inventory, curve, volume,
open-interest, file, API, optimizer, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis,
financing, label sensitivity, sparse samples, stop slippage, source translation, and overlap with
other WTI candidates can dominate. Q02 owns economics; unchanged Q09 alone owns realized
portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, calendar, two packages, range, CLV, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify eligible and ineligible months, two exact weeks, session-count bounds, strict
range expansion, range tie, strict CLV threshold, long-only entry, body-sign irrelevance,
current-week exclusion, durable attempt, frozen stop, next-week exit, card lint, resolver, PACER
audit, reference tests, and strict compile/build checks. Q02 retires on zero trades, fewer than
five completed positions in a full scored year, nonpositive governed economics, or contract
mismatch. No weak result may be tuned into survival.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live Q01 build, one fixed-risk set, and one
paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests, optimization, portfolio-gate
edits or admission, correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-11 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-11 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-11 | PASS | compile `52424a9e`; zero compiler errors/warnings; strict build check PASS |
| Q02 Baseline Screening | 2026-09-11 | ENQUEUED | pending work item `cef7693f`; fixed-risk set SHA-256 `6f360af1...` |
