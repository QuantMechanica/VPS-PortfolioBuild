---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913_S01
variant_id: BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913_S01
source_id: BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913
ea_id: QM5_41466
slug: wti-summer-lclv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41466_wti-summer-lclv-fade.md
execution_contract_status: APPROVED
created: 2026-09-13
created_by: Research+Development
last_updated: 2026-09-13
g0_status: APPROVED
g0_decision: decisions/2026-09-13_qm5_41466_wti_summer_lower_clv_reversion_g0.md
source_approval: decisions/2026-09-13_wti_summer_lower_clv_reversion_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; governed Crabel completed-week/close-location lineage; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures."
source_citations:
  - type: peer_reviewed_reputable_and_academic_bounded_mechanization
    citation: "Peer-reviewed WTI summer-season evidence plus governed reputable completed-week/close-location and academic commodity-reversal lineage."
    location: strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913/source.md
    quality_tier: B_and_governed_reputable_and_academic_lineages_with_translation_risk
    role: june_october_calendar_lower_tercile_weekly_close_reversion_lineage
strategy_mechanic: normalized-weekly-wti-june-through-october-one-completed-week-lower-tercile-close-location-long-only-reversion-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913]]"]
concepts: ["[[concepts/wti-summer-seasonality]]", "[[concepts/completed-week-close-location]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, summer-negative-leg, lower-tercile-close-location, long-only, weekly-reversion, atr-hard-stop, time-stop, low-frequency]
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
magic: 414660000
period: D1
timeframe: D1
direction: long_only
expected_trade_frequency: "Approximately 6-8 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 6,7,8,9,10; exactly the immediately completed week with 3-5 sessions; CLV strictly below one third; long only; 20 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q01_compile_work_item: b6ccc50f-af38-4f28-b0b9-76ec087b87eb
q01_build_report: D:/QM/reports/work_items/b6ccc50f-af38-4f28-b0b9-76ec087b87eb/QM5_41466/COMPILE_EA/compile_evidence.json
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a WTI June-October lower-tercile weekly-close reversion distinct from the certified XNG oscillator, summer lower-tercile continuation, upper-tercile summer fade, winter lower-tercile fade, and two-week range/body variants. Verify exact completed week, strict CLV inequality, no range/body predicate, long-only side, durable attempt, fixed risk, frozen stop, and next-week exit. The new WTI seasonal-reversal driver is the intended diversification axis; Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, june_october_gate, normalized_week_clock, immediately_completed_week, bounded_week_sessions, strict_lower_tercile_close_location, no_return_sign_gate, no_range_rank, no_body_wick_or_mean_gate, long_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed and governed reputable lineage with explicit translation and counter-seasonal-direction risk; R2 exact mechanical WTI summer lower-tercile weekly-close long reversion; R3 XTIUSD.DWX D1; R4 deterministic non-ML; four fuzzy neighbors mechanically separated after repository review."
---

# QM5_41466 WTI Summer Lower-Tercile Weekly-Close Reversion

## Hypothesis

During the documented June-through-October WTI summer regime, a completed
week settling in the lower third of its full range may represent a local
selloff that reverts over the next normalized broker week. Buy at the next
week boundary and hold one week. This direction is counter to the regime's
average negative drift; the exact Darwinex-CFD rule is unproven and belongs to
Q02.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-SUMMER-LCLV-FADE-20260913/source.md`.
Burakov et al. supply the WTI June-October regime; the governed Crabel packet
supplies completed-week and close-location lineage; Yang et al. supply
commodity-reversal lineage. None establishes this conjunction.

The canonical scan found no exact identity and four fuzzy family matches.
`QM5_41457` and `QM5_41458` require two completed weeks, a contraction or
expansion range comparison, and a positive newest-week body. `QM5_41462` uses
the disjoint upper tercile and sells. `QM5_41464` uses the same lower-tercile
reversion construction only in November-May. `QM5_41461` uses the same summer
lower-tercile state but sells under continuation lineage. This card requires
one completed week, no range ranking or body direction, and buys only a strict
lower-tercile summer settlement. The exact mechanic is distinct.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41466, slot zero,
   registered magic, and fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist
   the attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is June, July, August,
   September, or October and entry is within 180 elapsed minutes.
4. Reconstruct exactly the immediately completed normalized week with three
   through five valid, unique, ordered D1 sessions. Exclude every current-week
   bar.
5. Require a positive finite weekly range and compute
   `CLV=(final_close-low)/(high-low)`.
6. Buy only when `CLV < strategy_clv_cutoff`, locked to one third. Equality
   or a higher close is flat. There is no short side, return-sign gate, range-
   rank test, or candle-body-sign test.
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
quote, ATR, stop, sizing, or order state. Framework RNG, news, and Friday-
close inputs remain configurable and are never equality-pinned. Stress
rejection is checked only for finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
take-profit-bearing, future-dated, or invalid-volume owned exposure. No trail,
break-even, partial close, scale-in, pyramid, grid, martingale, hedge,
reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| param | default |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 20 |
| `strategy_summer_month_1` | 6 |
| `strategy_summer_month_2` | 7 |
| `strategy_summer_month_3` | 8 |
| `strategy_summer_month_4` | 9 |
| `strategy_summer_month_5` | 10 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_clv_cutoff` | 0.333333333333 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, CLV cutoff, orientation, carrier, stop,
hold, spread, or retry contract requires a new identity. The zero-offset label
is locked from existing Model-4 WTI decision-clock evidence before testing.

## Source-Defined Rules

Burakov et al. supply the June-October WTI regime. Yang et al. supply broad
commodity reversal. The governed Crabel record supplies weekly close-location
construction. They do not supply this exact weekly conjunction.

## QM Interpretations

Monday anchors, one completed week, strict lower-tercile threshold, long-only
boundary entry, one-week hold, retry semantics, and every numeric execution
threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the weekly lifecycle
is intact. Those framework inputs and RNG seed remain configurable and
unpinned. Stress rejection receives only range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed owned-exposure repair;
3. first processed tick in the next normalized broker week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC, native timestamps, quotes, symbol metadata, ATR,
positions, deals, and persistent state only. No external runtime source,
news-as-signal, futures chain, inventory, open interest, grid, or martingale.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
WTI roll/basis, financing, gaps, stop slippage, CFD translation, and the
counter-seasonal trade direction are material failure risks. Q02 owns cadence
and economics. Only Q09 may establish actual book correlation.

## Strategy Allowability Check

- [x] R1 reputable source criteria satisfied with complete-read durable records.
- [x] R2 deterministic calendar, weekly OHLC, CLV, side, stop, and lifecycle.
- [x] R3 registered `XTIUSD.DWX` D1 supplies all runtime market inputs.
- [x] R4 no ML, banned signal indicator, external runtime feed, grid, or martingale.
- [x] No exact duplicate; all four fuzzy family matches are mechanically separated.

## Framework Alignment

| Module | Implementation |
|---|---|
| No-Trade | Framework defaults plus fail-closed strategy preflight. |
| Trade Entry | Weekly clock, completed-week CLV, long order, frozen ATR stop. |
| Trade Management | Validate owned exposure and close at next week or stale limit. |
| Trade Close | Time/stale exits only; broker stop and framework kill switch remain authoritative. |

## Kill Criteria

Retire on a Q01 contract/build defect, zero Q02 trades after chronology is
proven, fewer than five completed trades in any full scored year, or
nonpositive governed Q02 economics. Do not change the threshold, calendar,
side, lifecycle, or risk to rescue a failure.

## Pipeline Phase Status

| Phase | Status | Evidence |
|---|---|---|
| Q00/G0 | APPROVED | This card and G0 decision. |
| Q01 | PASS | Compile `b6ccc50f-af38-4f28-b0b9-76ec087b87eb`; `COMPILE_OK`; 0 errors/warnings; strict build check PASS; 10 reference tests; PACER audit zero hits. |
| Q02 | NOT_ENQUEUED_CPU_CEILING | Read-only intake eligible; apply failed closed on governed-backup timeout; subsequent CPU maximum 98.6% against 97.0% ceiling; no Q02 row. |

## Safety Boundary

Non-live research and Q02 only. No manual backtest, optimization, demo,
shadow, deploy, portfolio-gate, `T_Live`, or AutoTrading action is authorized.
