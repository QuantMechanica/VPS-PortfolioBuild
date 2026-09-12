---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-CLV-FADE-20260912_S01
variant_id: BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-CLV-FADE-20260912_S01
source_id: BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-CLV-FADE-20260912
ea_id: QM5_41456
slug: wti-winter-nr2-clv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41456_wti-winter-nr2-clv-fade.md
execution_contract_status: APPROVED
created: 2026-09-12
created_by: Research+Development
last_updated: 2026-09-12
g0_status: APPROVED
g0_decision: decisions/2026-09-12_qm5_41456_wti_winter_nr2_clv_reversion_g0.md
source_approval: decisions/2026-09-12_wti_winter_nr2_clv_reversion_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; Crabel range-state lineage; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures."
source_citations:
  - type: peer_reviewed_reputable_and_academic_bounded_mechanization
    citation: "Peer-reviewed WTI seasonality, governed reputable Crabel range-state lineage, and academic commodity-reversal evidence."
    location: strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-CLV-FADE-20260912/source.md
    quality_tier: B_and_governed_reputable_and_academic_lineages_with_translation_risk
    role: november_may_calendar_range_contraction_and_symmetric_reversion_lineage
strategy_mechanic: normalized-weekly-wti-november-through-may-two-completed-weeks-newest-strict-narrower-range-than-prior-outer-quartile-final-close-symmetric-reversion-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-CLV-FADE-20260912]]"]
concepts: ["[[concepts/wti-winter-seasonality]]", "[[concepts/completed-week-range-contraction]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, winter-premium, weekly-range-contraction, close-location, symmetric-long-short, weekly-reversion, atr-hard-stop, time-stop, low-frequency]
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
magic: 414560000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 8-18 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3,4,5; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly less than prior; newest CLV strictly below 0.25 buys and strictly above 0.75 sells; 30 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q01_compile_work_item: 592cfacb-3683-45e5-aae8-0f524eb05223
q01_build_report: D:/QM/reports/work_items/592cfacb-3683-45e5-aae8-0f524eb05223/QM5_41456/COMPILE_EA/compile_evidence.json
q02_status: ENQUEUED_ACTIVE
q02_work_item: 39ecd610-2e9c-4b80-b7a4-f0da802ce21d
q02_receipt: D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/592cfacb-3683-45e5-aae8-0f524eb05223_39ecd610-2e9c-4b80-b7a4-f0da802ce21d.json
force_build: true
review_focus: "Falsify a WTI November-May range-contraction outer-quartile fade distinct from the certified XNG oscillator, WTI winter range-expansion fade, contraction continuation, contraction body fade, and same-sign weekly-return fade. Verify exact weeks, strict inequalities, both contrarian sides, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, november_may_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_contraction, strict_outer_quartile_close, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed, academic, and governed reputable lineage with explicit translation risk; R2 exact mechanical WTI winter NR2/CLV symmetric reversion; R3 XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41456 WTI Winter NR2 Close-Location Reversion

## Hypothesis

During the documented November-through-May WTI winter regime, a contracting completed week that
settles in an outer quartile may be temporarily overextended. Fade that settlement at the next
normalized week boundary and hold one week. This exact Darwinex-CFD rule is unproven and belongs
to Q02.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-CLV-FADE-20260912/source.md`.
Burakov, Freidin, and Solovyev supply the WTI November-May calendar; Yang, Goncu, and Pantelous
supply commodity-reversal lineage; governed Crabel work supplies range-state lineage and
completed-week construction. None establishes this conjunction.

The canonical scan found no exact match. `QM5_41442` fades outer-quartile closes after expansion,
the opposite volatility state. `QM5_41447` uses contraction but buys upper-quartile continuation
only. `QM5_41446` uses contraction but fades body sign. `QM5_41403` uses two same-sign weekly
returns and no range/CLV state. `QM5_41453` is a paired XAU/XAG ratio basket. Carrier, full
November-May clock, strict contraction, both outer-quartile closes, contrarian sides, and
one-week hold are jointly load-bearing.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41456, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is November, December, January, February, March,
   April, or May and entry is within 180 elapsed minutes.
4. Reconstruct exactly the two immediately completed consecutive normalized weeks, each with
   three through five valid, unique, ordered D1 sessions.
5. Require positive finite ranges and require the newest range to be strictly less than the
   preceding range; equality is flat.
6. Compute newest-week `CLV=(final_close-low)/(high-low)`. Buy only when `CLV<0.25`; sell only
   when `CLV>0.75`; equality and the middle half are flat. Weekly body sign is irrelevant.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, ineligible month, malformed packages, noncontracting range, CLV at a
threshold or inside the middle half, spread, quote, ATR, stop, sizing, or order state. Framework
RNG, news, and Friday-close inputs remain configurable and are never equality-pinned. Stress
rejection is checked only for finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop, take-profit-bearing,
future-dated, or invalid-volume owned exposure. No trail, break-even, partial close, scale-in,
pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

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
| `strategy_clv_lower` | 0.25 |
| `strategy_clv_upper` | 0.75 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, strict range rank, CLV thresholds, orientation, carrier, stop,
hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

Burakov et al. supply the November-May WTI interval. The Yang and governed Crabel records supply
broad commodity-reversal and range-state lineage. They do not supply this exact weekly
conjunction or its thresholds.

## QM Interpretations

Monday anchors, two completed weeks, strict range contraction, outer-quartile thresholds,
boundary entry, one-week hold, retry semantics, and every numeric threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the weekly lifecycle is intact. Those
framework inputs and RNG seed remain configurable and unpinned. Stress rejection receives only
range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed owned-exposure repair;
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
range contraction, range tie, both strict CLV thresholds, both contrarian sides, body-sign
irrelevance, current-week exclusion, durable attempt, frozen stop, next-week exit, card lint,
resolver, PACER audit, reference tests, and strict compile/build checks. Q02 retires on zero trades,
fewer than five completed positions in a full scored year, nonpositive governed economics, or
contract mismatch. No weak result may be tuned into survival.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live Q01 build, one fixed-risk set, and one
paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests, optimization, portfolio-gate
edits or admission, correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-12 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-12 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-12 | PASS | governed T5 compile; zero compiler errors/warnings; strict build check PASS; 12 reference tests; PACER audit zero hits |
| Q02 Baseline Screening | 2026-09-12 | ENQUEUED_ACTIVE | deterministic intake `39ecd610-2e9c-4b80-b7a4-f0da802ce21d`; claimed by T6 at handoff |
