---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911_S01
variant_id: BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911_S01
source_id: BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911
ea_id: QM5_41442
slug: wti-winter-wr2-clv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41442_wti-winter-wr2-clv-fade_card.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41442_wti_winter_wr2_clv_reversion_g0.md
source_approval: decisions/2026-09-11_wti_winter_wr2_clv_reversion_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; Crabel range-state lineage; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures."
source_citations:
  - type: peer_reviewed_reputable_and_academic_bounded_mechanization
    citation: "Peer-reviewed WTI seasonality, governed reputable Crabel range-state lineage, and academic commodity-reversal evidence."
    location: strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911/source.md
    quality_tier: B_and_governed_reputable_and_academic_lineages_with_translation_risk
    role: november_may_calendar_range_expansion_and_symmetric_reversion_lineage
strategy_mechanic: normalized-weekly-wti-november-through-may-two-completed-weeks-newest-strict-wider-range-than-prior-outer-quartile-final-close-symmetric-reversion-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911]]"]
concepts: ["[[concepts/wti-winter-seasonality]]", "[[concepts/completed-week-range-expansion]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, winter-premium, weekly-range-expansion, close-location, symmetric-long-short, weekly-reversion, atr-hard-stop, time-stop, low-frequency]
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
magic: 414420000
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
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3,4,5; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly greater than prior; newest CLV strictly below 0.25 buys and strictly above 0.75 sells; 30 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a WTI November-May range-expansion outer-quartile fade distinct from the certified XNG oscillator, weekly sign fades, WTI winter continuation, hurricane-only short fade, and XNG winter continuation. Verify exact weeks, strict inequalities, both contrarian sides, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, november_may_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_expansion, strict_outer_quartile_close, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed, governed reputable, and academic lineage with explicit translation risk; R2 exact mechanical WTI winter WR2/CLV symmetric reversion; R3 XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41442 WTI Winter WR2 Outer-Quartile Reversion

## Hypothesis

During the documented November-through-May WTI winter regime, an expanding completed week that
settles in either outer quartile may represent a short-lived overreaction. Fade the settlement at
the next normalized week boundary and hold one week. This exact Darwinex-CFD rule is unproven and
belongs to Q02.

## Source Traceability And Non-Duplicate Decision

The source packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-WR2-CLV-FADE-20260911/source.md`.
Burakov, Freidin, and Solovyev supply the WTI November-May calendar; governed Crabel work supplies
range-state lineage and completed-week construction; Yang, Goncu, and Pantelous supply broad
commodity-reversal lineage. None establishes this conjunction.

The canonical scan found no exact match. `QM5_41403/41408` use weekly return signs only.
`QM5_41440` buys upper-quartile WTI continuation and has no lower-quartile branch. `QM5_41435`
sells only the upper-quartile state in the disjoint August-October hurricane window.
`QM5_41438` follows both outer-quartile states on XNG in November-March. Certified `QM5_12567` is
a two-day cumulative-RSI XNG pullback. The new identity requires WTI, the full November-May clock,
two-week range expansion, both outer-quartile states, contrarian sides, and a one-week hold.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41442, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is November, December, January, February, March,
   April, or May and entry is within 180 elapsed minutes.
4. Reconstruct exactly the two immediately completed consecutive normalized weeks, each with
   three through five valid, unique, ordered D1 sessions.
5. Require positive finite ranges and require the newest range to be strictly greater than the
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
late restart, consumed week, ineligible month, malformed packages, nonexpanding range, CLV at a
threshold or inside the middle half, spread, quote, ATR, stop, sizing, or order state. Framework
RNG, news, and Friday-close inputs remain configurable and are never equality-pinned. Stress
rejection is checked only for finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop, take-profit-bearing,
future-dated, or invalid-volume owned exposure. No trail, break-even, partial close, scale-in,
pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1..7` | 11 / 12 / 1 / 2 / 3 / 4 / 5 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_lower` / `strategy_clv_upper` | 0.25 / 0.75 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, strict range rank, CLV thresholds, orientation, carrier, stop,
hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

Burakov et al. supply the November-May WTI interval. The Yang and governed Crabel records supply
broad commodity-reversal and range-state lineage. They do not supply this exact weekly conjunction
or its thresholds.

## QM Interpretations

Monday anchors, two completed weeks, strict range expansion, outer-quartile thresholds, boundary
entry, one-week hold, retry semantics, and every numeric threshold are QM choices.

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
range expansion, range tie, both strict CLV thresholds, both contrarian sides, body-sign
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
| G0 Source Approval | 2026-09-11 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-11 | APPROVED | G0 decision above |
| Q01 Build Validation | - | NOT_STARTED | Build pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | Q01 and fresh CPU admission required |

