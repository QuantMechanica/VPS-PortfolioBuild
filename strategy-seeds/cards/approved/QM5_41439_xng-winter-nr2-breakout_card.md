---
card_schema_version: 2
type: strategy
strategy_id: EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911_S01
variant_id: EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911_S01
source_id: EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911
ea_id: QM5_41439
slug: xng-winter-nr2-breakout
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41439_xng-winter-nr2-breakout_card.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41439_xng_winter_nr2_breakout_g0.md
source_approval: decisions/2026-09-11_xng_winter_nr2_breakout_source_approval.md
source_author: "U.S. Energy Information Administration; Toby Crabel; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Toby Crabel; OpenAI Codex"
source_citation: "EIA winter-demand context; Crabel systematic range-contraction and expansion lineage."
source_citations:
  - type: official_government_and_reputable_bounded_mechanization
    citation: "EIA natural-gas seasonality context plus governed Crabel range-state lineage."
    location: strategy-seeds/sources/EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911/source.md
    quality_tier: A_lineages_with_cross_source_and_carrier_translation_risk
    role: winter_calendar_contraction_and_completed_close_breakout_lineage
strategy_mechanic: normalized-weekly-xng-november-march-winter-two-completed-weeks-newest-strict-narrower-range-than-prior-next-week-completed-d1-close-breakout-symmetric-one-week-hold
sources: ["[[sources/EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911]]"]
concepts: ["[[concepts/winter-heating-demand]]", "[[concepts/completed-week-volatility-contraction]]", "[[concepts/completed-close-breakout]]"]
indicators: ["[[indicators/completed-week-range]]", "[[indicators/completed-d1-close]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, winter-demand, weekly-contraction, completed-close-breakout, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
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
magic: 414390000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-12 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_CARRIER_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 11,12,1,2,3; two immediately completed consecutive weeks with 3-5 sessions each; newest range strictly less than prior; first current-week completed D1 close strictly outside newest completed-week high/low; 30 D1 history bars; 180-minute new-bar grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q01_compile_work_item: 790255b0-7bb6-41cd-9419-33daf5f14bc3
q01_build_report: D:/QM/reports/work_items/790255b0-7bb6-41cd-9419-33daf5f14bc3/QM5_41439/COMPILE_EA/compile_evidence.json
q02_status: BLOCKED_CPU_CEILING
q02_blocker: "Fresh five-sample whole-host CPU window peaked at 98.047568%, above the strict 97.0% ceiling; no Q02 row enqueued."
force_build: true
review_focus: "Falsify an XNG winter weekly contraction/completed-close breakout distinct from all-year NR7, range-expansion CLV momentum, WTI hurricane NR2, and incumbent XNG oscillator. Verify two exact completed weeks, strict range contraction without containment, current-week close chronology, both sides, durable first-breakout attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, winter_month_gate, normalized_week_clock, two_consecutive_completed_weeks, bounded_week_sessions, strict_range_contraction, frozen_breakout_box, completed_current_week_close_only, strict_breakout_inequality, weekly_attempt_after_signal, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete official/governed reputable lineage with explicit cross-source and carrier translation risk; R2 exact mechanical seasonal NR2/completed-close breakout; R3 XNGUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41439 XNG Winter NR2 Close Breakout

## Hypothesis

During November through March, a completed natural-gas week whose full range contracts relative
to the preceding week may form a structural reference box before renewed winter-demand repricing.
Trade only the direction of the first completed D1 close beyond that box during the next week. The
exact rule is unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The source packet is
`strategy-seeds/sources/EIA-CRABEL-XNG-WINTER-NR2-BREAKOUT-20260911/source.md`. EIA supports the
winter-demand calendar; governed Crabel work supplies range-contraction/expansion lineage. Neither
establishes this Darwinex CFD conjunction.

The canonical scan found no exact match. `QM5_41437` is the WTI August-October hurricane carrier.
`QM5_41063` requires the strict narrowest of seven XNG weeks all year. `QM5_41438` requires range
expansion and immediate outer-quartile close direction. Certified `QM5_12567` is a long-only two-
day cumulative-RSI pullback above a slow trend. This card requires two-week relative contraction,
no containment, a winter calendar, and a strict later completed-close breakout.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XNGUSD.DWX` D1 with EA 41439, slot zero, registered magic, and
   fixed-risk backtest mode.
2. Evaluate only on a new D1 bar and only inside a normalized Monday-anchored week whose anchor
   month is November, December, January, February, or March. Require entry within 180 elapsed
   minutes of that bar.
3. Require at least one completed D1 bar in the current week. Never use the current partial bar.
4. Reconstruct exactly the two immediately preceding consecutive completed normalized weeks, each
   with three through five valid, unique, ordered D1 sessions.
5. Require both full ranges positive and finite. Require the newest range strictly less than the
   preceding range; equality is flat. Do not require high-low containment.
6. Freeze the newest completed week's high and low as the box. Buy only when the just-completed
   current-week D1 close is strictly above the high; sell only when strictly below the low;
   equality is flat.
7. Persist the week attempt immediately after the first valid breakout is known and before news,
   spread, quote, ATR, sizing, margin, or order gates. Never retry the week.
8. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the normalized week after entry. Ten elapsed days is stale
repair. The broker hard stop and framework kill switch remain authoritative. There is no target,
signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late new-bar processing, consumed week, ineligible month, malformed packages, noncontracting range,
no completed current-week close, no strict breakout, spread, quote, ATR, stop, sizing, or order
state. Framework RNG, news, and Friday-close inputs remain configurable and are never equality-
pinned. Stress rejection is checked only for finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, side-invalid, missing-stop, take-profit-
bearing, future-dated, or invalid-volume owned exposure. No trail, break-even, partial close,
scale-in, pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XNGUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_winter_month_1..5` | 11 / 12 / 1 / 2 / 3 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, two-week formation, strict range relation, completed-close trigger, carrier,
stop, hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

EIA supplies winter-demand context. Governed Crabel records supply range-contraction and expansion
lineage. They do not supply this exact conjunction or its thresholds.

## QM Interpretations

November-March Monday anchors, two completed weeks, strict two-week range comparison, no
containment, completed-current-week-close triggering, one-week hold, retry semantics, and every
numeric threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the strategy-owned lifecycle is measured
intact. Those framework inputs and RNG seed remain configurable and unpinned. Stress rejection
receives range/finiteness validation only.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed owned-exposure repair;
3. first processed tick of the normalized week after entry;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties, positions, deal
history, ATR, and terminal-global attempt state only. No weather, storage, curve, volume, open-
interest, file, API, optimizer, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Natural-gas gaps,
roll/basis, financing, label sensitivity, sparse seasonal samples, delayed confirmation, false
breakout, stop slippage, source translation, and overlap with other XNG candidates can dominate.
Q02 owns economics; unchanged Q09 alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, calendar, two packages, contraction, completed-close breakout, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify eligible and ineligible months, two exact weeks, session-count bounds, strict
contraction, range tie, non-containment allowance, current-week exclusion from the box, completed-
close long/short/equality states, first-breakout durable attempt, frozen stop, next-week exit, card
lint, resolver, PACER audit, reference tests, and strict compile/build checks. Q02 retires on zero
trades, fewer than five completed positions in a full scored year, nonpositive governed economics,
or contract mismatch. No weak result may be tuned into survival.

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
| Q01 Build Validation | 2026-09-11 | PASS | compile `790255b0-7bb6-41cd-9419-33daf5f14bc3`; `COMPILE_OK`; build check PASS; 13 reference tests; PACER audit zero hits |
| Q02 Baseline Screening | 2026-09-11 | BLOCKED_CPU_CEILING | dry-run eligible after set repair; no Q02 row; CPU avg 93.187870%, max 98.047568% against strict 97.0% ceiling |
