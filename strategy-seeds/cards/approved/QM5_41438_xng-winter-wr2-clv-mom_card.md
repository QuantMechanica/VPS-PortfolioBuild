---
card_schema_version: 2
type: strategy
strategy_id: EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911_S01
variant_id: EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911_S01
source_id: EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911
ea_id: QM5_41438
slug: xng-winter-wr2-clv-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41438_xng-winter-wr2-clv-mom_card.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41438_xng_winter_wr2_clv_momentum_g0.md
source_approval: decisions/2026-09-11_xng_winter_wr2_clv_momentum_source_approval.md
source_author: "U.S. Energy Information Administration; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "EIA natural-gas winter-demand context; Crabel range-state lineage; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum."
source_citations:
  - type: official_government_and_academic_bounded_mechanization
    citation: "EIA natural-gas winter-demand context plus governed Crabel and Moskowitz-Ooi-Pedersen range/momentum lineage."
    location: strategy-seeds/sources/EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911/source.md
    quality_tier: A_government_plus_academic_and_reputable_range_lineage_with_translation_risk
    role: winter_calendar_and_range_expansion_continuation_lineage
strategy_mechanic: normalized-weekly-xng-november-december-january-february-march-winter-season-two-completed-weeks-newest-strict-wider-range-than-prior-strict-upper-or-lower-quartile-close-symmetric-continuation-one-week-hold
sources: ["[[sources/EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911]]"]
concepts: ["[[concepts/natural-gas-winter-demand]]", "[[concepts/completed-week-range-expansion]]", "[[concepts/time-series-momentum]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, winter-demand, weekly-range-expansion, close-location, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 414380000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-12 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly greater than prior; newest CLV strictly above 0.75 or below 0.25; symmetric continuation; 30 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: G0_APPROVED_BUILD_PENDING
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify an XNG winter weekly range-expansion/outer-quartile continuation distinct from the incumbent RSI pullback, all-year close-location momentum, winter return-sign momentum, winter two-week agreement, and NR7 breakout. Verify two exact weeks, strict range and CLV inequalities, both sides, body-sign irrelevance, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, winter_month_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_expansion, strict_outer_quartile_close, symmetric_orientation, body_sign_irrelevant, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus governed range-expansion and peer-reviewed time-series-momentum lineage with disclosed translation risk; R2 exact mechanical winter two-week WR2/outer-quartile symmetric continuation; R3 registered XNGUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41438 XNG Winter WR2 Close-Location Momentum

## Hypothesis

During November through March, a completed natural-gas week that expands beyond the preceding
week's range and settles in an outer quartile may reflect persistent winter-demand repricing.
Follow the settlement side at the next normalized week boundary and hold for one week. The exact
rule is unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The source packet is
`strategy-seeds/sources/EIA-CRABEL-MOP-XNG-WINTER-WR2-CLV-MOM-20260911/source.md`.
EIA supports the winter-demand calendar context; governed Crabel and Moskowitz-Ooi-Pedersen
records support range-state and broad own-return continuation lineage. None establishes this
Darwinex CFD conjunction.

The canonical scan found no exact match and raised expected fuzzy relatives. `QM5_41081` uses
return-sign plus outer-fifth CLV without range expansion or winter conditioning. `QM5_41395` and
`QM5_41402` use one- or two-week return signs, while this card ignores body sign. `QM5_41063`
ranks seven weeks and waits for a later current-week breakout. `QM5_41434` is a WTI hurricane,
upper-only, long-only carrier. `QM5_12567` is a two-day long-only oscillator pullback.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XNGUSD.DWX` D1 with EA 41438, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is November, December, January, February, or March and entry is within
   180 elapsed session minutes.
4. Reconstruct exactly the two immediately completed consecutive normalized weeks, each with
   three through five valid, unique, ordered D1 sessions.
5. Require both full ranges positive and finite. Require the newest range strictly greater than
   the preceding range; equality is flat.
6. Compute newest-week `CLV=(final_close-low)/(high-low)`. Buy when `CLV>0.75`; sell when
   `CLV<0.25`. Equality and the interior interval are flat. There is no body-sign test.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, ineligible month, malformed packages, nonexpanding range, interior or
boundary CLV, spread, quote, ATR, stop, sizing, or order state. Framework RNG, news, and Friday-close
inputs remain configurable and are never equality-pinned. Stress rejection is checked only for
finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side, missing-stop,
take-profit-bearing, future-dated, or invalid-volume owned exposure. No trail, break-even,
partial close, scale-in, pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

## Locked Q02 Baseline

| Input | Value |
|---|---:|
| `strategy_symbol` | `XNGUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1..5` | 11 / 12 / 1 / 2 / 3 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_upper` | 0.75 |
| `strategy_clv_lower` | 0.25 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, two-week formation, strict range rank, CLV threshold, direction, carrier,
stop, hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

EIA supplies natural-gas winter-demand context. Crabel and Moskowitz-Ooi-Pedersen supply
range-state and broad continuation lineage. They do not supply this exact conjunction.

## QM Interpretations

November-March Monday anchors, two completed weeks, strict range expansion, outer-quartile
thresholds, symmetric sides, body-sign irrelevance, one-week hold, retry semantics, and every
numeric threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the strategy-owned weekly lifecycle is
measured intact. Those framework inputs and RNG seed remain configurable and unpinned. Stress
rejection receives range/finiteness validation only.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed owned-exposure repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties, positions, deal
history, ATR, and terminal-global attempt state only. No weather, storage, demand, curve, volume,
open-interest, file, API, optimizer, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. XNG gaps, roll/basis,
financing, label sensitivity, sparse seasonal samples, stop slippage, regime instability, source
translation, and overlap with other XNG candidates can dominate. Q02 owns economics; unchanged
Q09 alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, calendar, two packages, range, CLV, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify eligible and ineligible months, two exact weeks, session-count bounds, strict
range expansion, range tie, both strict CLV thresholds, both sides, body-sign irrelevance, current-
week exclusion, durable attempt, frozen stop, next-week exit, card lint, resolver, PACER audit,
reference tests, and strict compile/build checks. Q02 retires on zero trades, fewer than five
completed positions in a full scored year, nonpositive governed economics, or contract mismatch.
No weak result may be tuned into survival.

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
| Q01 Build Validation | 2026-09-11 | PASS | compile `371f3306-2819-436a-8bbf-9e46e7ab1516`; `COMPILE_OK`; build check PASS; 12 reference tests; PACER audit zero hits |
| Q02 Baseline Screening | 2026-09-11 | ENQUEUED_PENDING | work item `17c3e39a-6818-4ef5-90ca-ecae9cb5af25`; CPU avg 93.229528%, max 96.679841% |
