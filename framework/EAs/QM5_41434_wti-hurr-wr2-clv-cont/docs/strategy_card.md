---
card_schema_version: 2
type: strategy
strategy_id: EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911_S01
variant_id: EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911_S01
source_id: EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911
ea_id: QM5_41434
slug: wti-hurr-wr2-clv-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41434_wti-hurr-wr2-clv-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41434_wti_hurricane_wr2_clv_continuation_g0.md
source_approval: decisions/2026-09-11_wti_hurricane_wr2_clv_continuation_source_approval.md
source_author: "U.S. Energy Information Administration; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Toby Crabel; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "EIA hurricane-season petroleum-supply context; Crabel range-state lineage; Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum."
source_citations:
  - type: official_government_and_academic_bounded_mechanization
    citation: "EIA hurricane-season petroleum-supply risk plus governed Crabel and Moskowitz-Ooi-Pedersen range/momentum lineage."
    location: strategy-seeds/sources/EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911/source.md
    quality_tier: A_government_plus_academic_and_reputable_range_lineage_with_translation_risk
    role: hurricane_calendar_and_range_expansion_continuation_lineage
strategy_mechanic: normalized-weekly-wti-august-september-october-hurricane-season-two-completed-weeks-newest-strict-wider-range-than-prior-upper-quartile-close-long-continuation-one-week-hold
sources: ["[[sources/EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911]]"]
concepts: ["[[concepts/hurricane-season-supply-risk]]", "[[concepts/completed-week-range-expansion]]", "[[concepts/time-series-momentum]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, hurricane-season, weekly-range-expansion, close-location, long-only, atr-hard-stop, time-stop, low-frequency]
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
magic: 414340000
period: D1
timeframe: D1
direction: long_only
expected_trade_frequency: "Approximately 3-7 completed positions per full post-warm-up year; Q02 must prove at least three in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 8,9,10; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly greater than prior; newest CLV strictly above 0.75; long-only; 30 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a WTI hurricane-season weekly range-expansion/upper-quartile continuation distinct from all-year WR4 symmetric continuation, return-sign hurricane continuation, and D1 channel breakout. Verify two exact weeks, strict range and CLV inequalities, long-only side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, hurricane_season_month_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_expansion, strict_upper_quartile_close, long_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus governed range-expansion and peer-reviewed time-series-momentum lineage with disclosed translation risk; R2 exact mechanical seasonal two-week WR2/CLV long continuation; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate and the sole fuzzy neighbor manually resolved."
---

# QM5_41434 WTI Hurricane-Season WR2 Close-Location Continuation

## Hypothesis

During August through October, a completed WTI week that expands beyond the preceding week's
range and settles in its own upper quartile may reflect persistent repricing of Gulf Coast
petroleum disruption risk. Buy at the next normalized week boundary and hold for one week. The
exact rule is unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The source packet is
`strategy-seeds/sources/EIA-CRABEL-WTI-HURR-WR2-CLV-CONT-20260911/source.md`.
EIA supports the hurricane-risk calendar context; governed Crabel and Moskowitz-Ooi-Pedersen
records support range-state and broad own-return continuation lineage. None establishes this
Darwinex CFD conjunction.

The canonical scan found no exact match and one fuzzy neighbor. `QM5_41087` is all-year,
symmetric, WR4, and body-direction-gated; this card is seasonal, long-only, compares two weeks,
and uses range expansion plus upper-quartile settlement without a body-sign condition.
`QM5_41430` uses positive weekly return alone. `QM5_12591` is an intraseason D1 channel breakout.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41434, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is August, September, or October and entry is within
   180 elapsed session minutes.
4. Reconstruct exactly the two immediately completed consecutive normalized weeks, each with
   three through five valid, unique, ordered D1 sessions.
5. Require both full ranges positive and finite. Require the newest range strictly greater than
   the preceding range; equality is flat.
6. Compute newest-week `CLV=(final_close-low)/(high-low)`. Buy only when `CLV>0.75`; equality or
   lower values are flat. There is no short branch and no body-sign test.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, or intentional carry beyond the next week.

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

## Locked Q02 Baseline

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_hurricane_month_1..3` | 8 / 9 / 10 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_upper` | 0.75 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, two-week formation, strict range rank, CLV threshold, direction, carrier,
stop, hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

EIA supplies hurricane-season physical-risk context. Crabel and Moskowitz-Ooi-Pedersen supply
range-state and broad continuation lineage. They do not supply this exact conjunction.

## QM Interpretations

August-October Monday anchors, two completed weeks, strict range expansion, `CLV>0.75`, the
long-only side, one-week hold, retry semantics, and every numeric threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the strategy-owned weekly lifecycle is
measured intact. Those framework inputs and RNG seed remain configurable and unpinned. Stress
rejection receives range/finiteness validation only.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed or non-long owned-exposure repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties, positions, deal
history, ATR, and terminal-global attempt state only. No weather, hurricane forecast, refinery,
inventory, curve, volume, open-interest, file, API, optimizer, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis,
financing, label sensitivity, sparse seasonal samples, stop slippage, regime instability, source
translation, and overlap with other WTI candidates can dominate. Q02 owns economics; unchanged
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
range expansion, range tie, strict CLV threshold, long-only entry, body-sign irrelevance, current-
week exclusion, durable attempt, frozen stop, next-week exit, card lint, resolver, PACER audit,
reference tests, and strict compile/build checks. Q02 retires on zero trades, fewer than three
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
| Q01 Build Validation | 2026-09-11 | PENDING | branch build not yet compiled |
| Q02 Baseline Screening | 2026-09-11 | NOT_ENQUEUED | gated on Q01 and CPU admission |
