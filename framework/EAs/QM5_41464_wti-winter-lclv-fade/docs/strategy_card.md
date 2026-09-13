---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913_S01
variant_id: BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913_S01
source_id: BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913
ea_id: QM5_41464
slug: wti-winter-lclv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41464_wti-winter-lclv-fade.md
execution_contract_status: APPROVED
created: 2026-09-13
created_by: Research+Development
last_updated: 2026-09-13
g0_status: APPROVED
g0_decision: decisions/2026-09-13_qm5_41464_wti_winter_lower_clv_reversion_g0.md
source_approval: decisions/2026-09-13_wti_winter_lower_clv_reversion_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; governed Crabel completed-week/close-location lineage; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures."
source_citations:
  - type: peer_reviewed_reputable_bounded_mechanization
    citation: "Peer-reviewed WTI winter-season and commodity-reversal evidence plus governed reputable completed-week and close-location lineage."
    location: strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913/source.md
    quality_tier: B_and_governed_reputable_and_academic_lineages_with_translation_risk
    role: november_may_calendar_lower_tercile_weekly_close_reversion_lineage
strategy_mechanic: normalized-weekly-wti-november-through-may-one-completed-week-lower-tercile-close-location-long-only-reversion-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913]]"]
concepts: ["[[concepts/wti-winter-seasonality]]", "[[concepts/completed-week-close-location]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, winter-premium, lower-tercile-close-location, long-only, weekly-reversion, atr-hard-stop, time-stop, low-frequency]
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
magic: 414640000
period: D1
timeframe: D1
direction: long_only
expected_trade_frequency: "Approximately 8-12 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3,4,5; exactly the immediately completed week with 3-5 sessions; CLV strictly below one third; long only; 20 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q01_compile_work_item: dcf47ab2-34a3-4d51-b159-444c00f8c9ac
q01_build_report: D:/QM/reports/work_items/dcf47ab2-34a3-4d51-b159-444c00f8c9ac/QM5_41464/COMPILE_EA/compile_evidence.json
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a WTI November-May lower-tercile weekly-close reversion distinct from the certified XNG oscillator, monthly WTI winter sign rules, and two-week range-state variants. Verify exact completed week, strict CLV inequality, no range/body predicates, long-only side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, november_may_gate, normalized_week_clock, immediately_completed_week, bounded_week_sessions, strict_lower_tercile_close_location, no_range_rank, no_body_sign_gate, long_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed, governed reputable, and academic lineage with explicit translation risk; R2 exact mechanical WTI winter lower-tercile weekly-close long reversion; R3 XTIUSD.DWX D1; R4 deterministic non-ML; expected fuzzy family matches manually separated by the absence of range-rank and symmetric-side gates."
---

# QM5_41464 WTI Winter Lower-Tercile Weekly-Close Reversion

## Hypothesis

During the documented November-through-May positive WTI return leg, a
completed week settling in the lower third of its full range may identify
a temporary selloff that reverts within the positive seasonal leg over the next normalized broker week. Buy at
the next week boundary and hold one week. This exact Darwinex-CFD rule is
unproven and belongs to Q02.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-LCLV-FADE-20260913/source.md`.
Burakov et al. supply the WTI November-May positive leg; the governed Crabel
packet supplies completed-week and close-location lineage; Yang et al.
supply commodity-reversal lineage. None establishes this conjunction.

The canonical scan found no exact collision and four expected fuzzy family
matches; its external Wiki root was unavailable and is recorded rather than
treated as a pass. `QM5_41442` and `QM5_41456` require two completed weeks,
a strict newest-versus-prior range comparison, and symmetric outer-quartile
fades. This card requires one completed week, no range ranking, no body
direction, and only the winter-premium long side after a strict lower-tercile
settlement.
`QM5_20209/20218` use calendar-month return sign. The exact mechanic is new in
the available repository corpus.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41464, slot zero,
   registered magic, and fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist
   the attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is November, December, January,
   February, March, April, or May and entry is within 180 elapsed minutes.
4. Reconstruct exactly the immediately completed normalized week with three
   through five valid, unique, ordered D1 sessions. Exclude every current-week
   bar.
5. Require a positive finite weekly range and compute
   `CLV=(final_close-low)/(high-low)`.
6. Buy only when `CLV < strategy_clv_cutoff`, locked to one third. Equality
   or a higher close is flat. There is no short side, range-rank test, or
   candle-body sign test.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1),
   valid metadata, and one normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten
elapsed days is stale repair. The broker hard stop and framework kill switch
remain authoritative. There is no target, signal-flip exit, Friday exit, or
intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked
`strategy_*` configuration, late restart, consumed week, ineligible month,
malformed completed-week package, non-lower-tercile settlement, spread,
quote, ATR, stop, sizing, or order state. Framework RNG, news, and
Friday-close inputs remain configurable and are never equality-pinned. Stress
rejection is checked only for finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, non-long,
missing-stop, take-profit-bearing, future-dated, or invalid-volume owned
exposure. No trail, break-even, partial close, scale-in, pyramid, grid,
martingale, hedge, reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| param | default |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 20 |
| `strategy_winter_month_1` | 11 |
| `strategy_winter_month_2` | 12 |
| `strategy_winter_month_3` | 1 |
| `strategy_winter_month_4` | 2 |
| `strategy_winter_month_5` | 3 |
| `strategy_winter_month_6` | 4 |
| `strategy_winter_month_7` | 5 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_clv_cutoff` | 0.333333333333 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, CLV cutoff, orientation, carrier, stop,
hold, spread, or retry contract requires a new identity. The zero-offset label
is locked from existing Model-4 WTI decision-clock evidence before this
candidate is tested.

## Source-Defined Rules

Burakov et al. supply the November-May positive WTI leg. Yang et al.
supply broad commodity reversal. The governed Crabel record supplies
weekly close-location lineage. They do not supply this exact weekly
conjunction.

## QM Interpretations

Monday anchors, one completed week, strict lower-tercile threshold, boundary
entry, one-week hold, retry semantics, and every numeric execution threshold
are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the weekly lifecycle
is intact. Those framework inputs and RNG seed remain configurable and
unpinned. Stress rejection receives only range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed or non-long owned-exposure repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties,
positions, deal history, ATR, and terminal-global attempt state only. No
weather, inventory, curve, volume, open-interest, file, API, optimizer,
trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis, financing, label sensitivity,
sample scarcity, stop slippage, source translation, and overlap with other WTI
candidates can dominate. Q02 owns economics; unchanged Q09 alone owns
realized portfolio correlation.

## Strategy Allowability Check

- [x] R1 reputable source criteria satisfied with complete-read durable records.
- [x] R2 deterministic calendar, weekly OHLC, CLV, side, stop, and lifecycle.
- [x] R3 registered `XTIUSD.DWX` D1 native route only.
- [x] R4 no ML, banned signal indicator, external runtime feed, grid, or martingale.
- [x] No exact repository duplicate; neighboring families are mechanically separated above.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, calendar, completed-week CLV, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify eligible/ineligible months, exact completed week,
session-count bounds, strict CLV inequality and equality, absence of range/body
gates, long-only side, durable attempt, frozen stop, next-week exit, card lint,
resolver, PACER audit, reference tests, and strict compile/build checks. Q02
retires on zero trades only after clock and entry observability prove exercise;
otherwise the run enters zero-trades recovery. Fewer than five completed
positions in a full scored year, nonpositive governed economics, or contract
mismatch also retires it. No weak result may be tuned into survival.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live Q01 build, one
fixed-risk set, and one paced Q02 enqueue below the CPU ceiling. Forbidden:
manual backtests, optimization, portfolio-gate edits or admission, correlation
waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal control, or
live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-13 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-13 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-13 | PASS | compile `dcf47ab2-34a3-4d51-b159-444c00f8c9ac`; `COMPILE_OK`; 0 compiler errors/warnings; strict build check PASS; 10 reference tests; PACER audit zero hits |
| Q02 Baseline Screening | 2026-09-13 | NOT_ENQUEUED_CPU_CEILING | eligible read-only intake; maximum CPU 100.0% against 97.0% ceiling; no apply command and no Q02 row |
