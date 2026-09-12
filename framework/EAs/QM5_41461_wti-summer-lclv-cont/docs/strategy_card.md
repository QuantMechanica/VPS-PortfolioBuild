---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912_S01
variant_id: BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912_S01
source_id: BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912
ea_id: QM5_41461
slug: wti-summer-lclv-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41461_wti-summer-lclv-cont.md
execution_contract_status: APPROVED
created: 2026-09-12
created_by: Research+Development
last_updated: 2026-09-12
g0_status: APPROVED
g0_decision: decisions/2026-09-12_qm5_41461_wti_summer_lower_clv_continuation_g0.md
source_approval: decisions/2026-09-12_wti_summer_lower_clv_continuation_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; governed Crabel completed-week/close-location lineage; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum."
source_citations:
  - type: peer_reviewed_reputable_and_academic_bounded_mechanization
    citation: "Peer-reviewed WTI summer-season and commodity-continuation evidence plus governed reputable completed-week and close-location lineage."
    location: strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912/source.md
    quality_tier: B_and_governed_reputable_and_peer_reviewed_lineages_with_translation_risk
    role: june_october_calendar_lower_tercile_weekly_close_continuation_lineage
strategy_mechanic: normalized-weekly-wti-june-through-october-one-completed-week-lower-tercile-close-location-short-only-continuation-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912]]"]
concepts: ["[[concepts/wti-summer-seasonality]]", "[[concepts/completed-week-close-location]]", "[[concepts/commodity-momentum]]"]
indicators: ["[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, summer-negative-leg, lower-tercile-close-location, short-only, weekly-continuation, atr-hard-stop, time-stop, low-frequency]
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
magic: 414610000
period: D1
timeframe: D1
direction: short_only
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
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 6,7,8,9,10; exactly the immediately completed week with 3-5 sessions; CLV strictly below one third; short only; 20 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PENDING
q02_status: PENDING
force_build: true
review_focus: "Falsify a WTI June-October lower-tercile weekly-close continuation distinct from the certified XNG oscillator, unconditional summer short, two-sign summer continuation, and range-ranked/body-sign variants. Verify exact completed week, strict CLV inequality, no range/body predicate, short-only side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, june_october_gate, normalized_week_clock, immediately_completed_week, bounded_week_sessions, strict_lower_tercile_close_location, no_range_rank, no_body_sign_gate, short_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed and governed reputable lineage with explicit translation risk; R2 exact mechanical WTI summer lower-tercile weekly-close short continuation; R3 XTIUSD.DWX D1; R4 deterministic non-ML; no exact repository duplicate after canonical and manual fuzzy-family review."
---

# QM5_41461 WTI Summer Lower-Tercile Weekly-Close Continuation

## Hypothesis

During the documented June-through-October negative WTI return leg, a completed week settling in
the lower third of its full range may identify downside pressure that persists for one more
normalized broker week. Short at the next week boundary and hold one week. This exact Darwinex-CFD
rule is unproven and belongs to Q02.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/BURAKOV-CRABEL-MOP-WTI-SUMMER-LCLV-CONT-20260912/source.md`.
Burakov, Freidin, and Solovyev supply the WTI June-October negative leg; the governed Crabel
packet supplies completed-week and close-location lineage; Moskowitz, Ooi, and Pedersen supply
commodity continuation lineage. None establishes this conjunction.

The canonical scan found no exact identity and only two fuzzy family matches. `QM5_41459` and
`QM5_41460` require two completed weeks, an expansion/contraction range comparison, and a
negative newest-week body. This card requires one completed week, no range ranking, no body
direction, and only a strict lower-tercile settlement. `QM5_20093` is unconditional summer short,
and `QM5_41406` requires two negative return signs. The exact mechanic is distinct.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41461, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is June, July, August, September, or October and
   entry is within 180 elapsed minutes.
4. Reconstruct exactly the immediately completed normalized week with three through five valid,
   unique, ordered D1 sessions. Exclude every current-week bar.
5. Require a positive finite weekly range and compute `CLV=(final_close-low)/(high-low)`.
6. Sell only when `CLV < strategy_clv_cutoff`, locked to one third. Equality or a higher close is
   flat. There is no long side, range-rank test, or candle-body sign test.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, ineligible month, malformed completed-week package, non-lower-tercile
settlement, spread, quote, ATR, stop, sizing, or order state. Framework RNG, news, and Friday-close
inputs remain configurable and are never equality-pinned. Stress rejection is checked only for
finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop, take-profit-bearing,
future-dated, or invalid-volume owned exposure. No trail, break-even, partial close, scale-in,
pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

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

Changing the calendar, formation, CLV cutoff, orientation, carrier, stop, hold, spread, or retry
contract requires a new identity. The zero-offset label is locked from existing Model-4 WTI
decision-clock evidence before this candidate is tested.

## Source-Defined Rules

Burakov et al. supply the June-October negative WTI leg. Moskowitz et al. supply broad commodity
continuation. The governed Crabel record supplies weekly close-location lineage. They do not
supply this exact weekly conjunction.

## QM Interpretations

Monday anchors, one completed week, strict lower-tercile threshold, boundary entry, one-week hold,
retry semantics, and every numeric execution threshold are QM choices.

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
financing, label sensitivity, sample scarcity, stop slippage, source translation, and overlap with
other WTI candidates can dominate. Q02 owns economics; unchanged Q09 alone owns realized
portfolio correlation.

## Strategy Allowability Check

- [x] R1 reputable source criteria satisfied with complete-read durable records.
- [x] R2 deterministic calendar, weekly OHLC, CLV, side, stop, and lifecycle.
- [x] R3 registered `XTIUSD.DWX` D1 native route only.
- [x] R4 no ML, banned signal indicator, external runtime feed, grid, or martingale.
- [x] No exact duplicate; fuzzy siblings are mechanically separated above.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, calendar, completed-week CLV, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify eligible/ineligible months, exact completed week, session-count bounds, strict CLV
inequality and equality, absence of range/body gates, short-only side, durable attempt, frozen
stop, next-week exit, card lint, resolver, PACER audit, reference tests, and strict compile/build
checks. Q02 retires on zero trades only after clock and entry observability prove exercise;
otherwise the run enters zero-trades recovery. Fewer than five completed positions in a full
scored year, nonpositive governed economics, or contract mismatch also retires it. No weak result
may be tuned into survival.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live Q01 build, one fixed-risk set, and one
paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests, optimization,
portfolio-gate edits or admission, correlation waivers, deploy/live manifests, `T_Live`,
AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-12 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-12 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-12 | PENDING | governed compile required |
| Q02 Baseline Screening | 2026-09-12 | PENDING | paced enqueue required after Q01 PASS |
