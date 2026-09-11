---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911_S01
variant_id: BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911_S01
source_id: BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911
ea_id: QM5_41446
slug: wti-winter-nr2-body-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41446_wti-winter-nr2-body-fade.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41446_wti_winter_nr2_body_reversion_g0.md
source_approval: decisions/2026-09-11_wti_winter_nr2_body_reversion_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), The Halloween Effect on Energy Markets; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures; governed Crabel range-state lineage."
source_citations:
  - type: peer_reviewed_reputable_and_academic_bounded_mechanization
    citation: "Peer-reviewed WTI seasonality, governed reputable Crabel range-state lineage, and academic commodity-futures reversal lineage."
    location: strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911/source.md
    quality_tier: B_and_governed_reputable_and_academic_lineages_with_translation_risk
    role: november_may_calendar_range_contraction_and_body_reversion_lineage
strategy_mechanic: normalized-weekly-wti-november-through-may-two-completed-weeks-newest-strict-narrower-range-than-prior-own-body-sign-symmetric-reversion-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911]]"]
concepts: ["[[concepts/wti-winter-seasonality]]", "[[concepts/completed-week-range-contraction]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-week-body-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, winter-premium, weekly-range-contraction, body-sign, symmetric-long-short, weekly-reversion, atr-hard-stop, time-stop, low-frequency]
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
magic: 414460000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 12-22 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 17
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3,4,5; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly less than prior; newest body close strictly above open sells and strictly below open buys; body equality is flat; 30 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02_READY
q01_status: PASS
q01_compile_work_item: 059f2358-40ad-4d84-bcd7-d7c3730e5b73
q01_build_report: D:/QM/reports/work_items/059f2358-40ad-4d84-bcd7-d7c3730e5b73/QM5_41446/COMPILE_EA/compile_evidence.json
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a WTI November-May range-contraction own-body reversion distinct from the certified XNG oscillator, outer-quartile CLV fade, opposite body continuation, two-same-sign-week fades, and intraweek excursion rejection. Verify exact weeks, strict inequalities, both contrarian sides, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, november_may_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_contraction, strict_own_body_sign, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed, governed reputable, and academic lineages with explicit translation risk; R2 exact mechanical WTI winter NR2/body symmetric reversion; R3 XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41446 WTI Winter NR2 Body Reversion

## Hypothesis

During the documented November-through-May WTI winter regime, a contracting completed week may
still carry a short-horizon overshoot in its own open-to-close body. Fade that completed body's
direction at the next normalized week boundary and hold one week. This exact Darwinex-CFD rule is
unproven and belongs to Q02.

## Source Traceability And Non-Duplicate Decision

The source packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-NR2-BODY-FADE-20260911/source.md`.
Burakov, Freidin, and Solovyev supply the WTI November-May calendar; Yang, Goncu, and Pantelous
supply commodity-futures reversal lineage; governed Crabel work supplies range-state lineage and
completed-week construction. None establishes this conjunction.

The canonical scan found no exact match. `QM5_41444` fades the same body sign only after strict
range expansion, the opposite volatility state. `QM5_41442` is also expansion-gated and trades
only strict outer-quartile close locations. `QM5_41445` uses the same contraction/body predicate
but follows instead of fading it, while `QM5_41441` waits for a later completed-close breakout
beyond the contraction box. Certified `QM5_12567` is an XNG cumulative-RSI pullback. The new
identity requires WTI, the full November-May clock, two-week range contraction, the newest week's
own body sign, symmetric reversion, and a one-week hold.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XTIUSD.DWX` D1 with EA 41446, slot zero, registered magic, and
   fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is November, December, January, February, March,
   April, or May and entry is within 180 elapsed minutes.
4. Reconstruct exactly the two immediately completed consecutive normalized weeks, each with
   three through five valid, unique, ordered D1 sessions.
5. Require positive finite ranges and require the newest range to be strictly less than the
   preceding range; equality is flat.
6. Sell only when the newest week's final close is strictly above its chronological first open;
   buy only when it is strictly below. Equality is flat. Close location is irrelevant.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, ineligible month, malformed packages, noncontracting range, zero body,
spread, quote, ATR, stop, sizing, or order state. Framework RNG, news, and Friday-close inputs
remain configurable and are never equality-pinned. Stress rejection is checked only for finiteness
and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop, take-profit-bearing,
future-dated, or invalid-volume owned exposure. No trail, break-even, partial close, scale-in,
pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

## Parameters To Test — No Q14 Optimization Proposal

Q02 has one locked baseline and no optimization surface. There is no Q14 optimization proposal:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1..7` | 11 / 12 / 1 / 2 / 3 / 4 / 5 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, strict range rank, body-sign orientation, carrier, stop, hold,
spread, or retry contract requires a new identity.

## Source-Defined Rules

Burakov et al. supply the November-May WTI interval. Yang et al. supply broad commodity-reversal
lineage, while the governed Crabel record supplies range-state lineage. They do not supply this
exact weekly conjunction or its two-week comparison.

## QM Interpretations

Monday anchors, two completed weeks, strict range contraction, weekly body mapping, boundary entry,
one-week hold, retry semantics, and every numeric threshold are QM choices.

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
| week clock, calendar, two packages, range, body fade, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify eligible and ineligible months, two exact weeks, session-count bounds, strict
range contraction, range tie, positive, negative, and zero body states, both contrarian sides,
current-week exclusion, durable attempt, frozen stop, next-week exit, card lint, resolver, PACER
audit, reference tests, and strict compile/build checks. Q02 retires on zero trades, fewer than five
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
| Q01 Build Validation | 059f2358-40ad-4d84-bcd7-d7c3730e5b73 | PASS | T3 compile and strict build check PASS; zero compiler errors/warnings; 11 reference tests; PACER audit zero hits |
| Q02 Baseline Screening | - | NOT_ENQUEUED | only after Q01 PASS and deterministic intake guards |
