---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913_S01
variant_id: EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913_S01
source_id: EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913
ea_id: QM5_41465
slug: xng-shoulder-hclv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41465_xng-shoulder-hclv-fade.md
execution_contract_status: APPROVED
created: 2026-09-13
created_by: Research+Development
last_updated: 2026-09-13
g0_status: APPROVED
g0_decision: decisions/2026-09-13_qm5_41465_xng_shoulder_upper_clv_fade_g0.md
source_approval: decisions/2026-09-13_xng_shoulder_upper_clv_fade_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "U.S. EIA natural-gas seasonal demand context; Moskowitz, Ooi and Pedersen (2012), Time Series Momentum; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures."
source_citations:
  - type: official_government_peer_reviewed_and_academic_bounded_mechanization
    citation: "Official EIA XNG shoulder-season context plus governed peer-reviewed XNG completed-week/close-location and academic commodity-reversal lineage."
    location: strategy-seeds/sources/EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913/source.md
    quality_tier: official_government_and_peer_reviewed_and_academic_lineages_with_translation_risk
    role: april_may_september_october_calendar_upper_tercile_weekly_close_reversion_lineage
strategy_mechanic: normalized-weekly-xng-april-may-september-october-one-completed-week-upper-tercile-close-location-short-only-reversion-one-week-hold
sources: ["[[sources/EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913]]"]
concepts: ["[[concepts/xng-shoulder-seasonality]]", "[[concepts/completed-week-close-location]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, shoulder-demand-lull, upper-tercile-close-location, short-only, weekly-reversion, atr-hard-stop, time-stop, low-frequency]
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
magic: 414650000
period: D1
timeframe: D1
direction: short_only
expected_trade_frequency: "Approximately 5-6 completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; months 4,5,9,10; exactly the immediately completed week with 3-5 sessions; CLV strictly above two thirds; short only; 20 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PENDING
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify an XNG April-May/September-October upper-tercile weekly-close reversion distinct from certified QM5_12567, the symmetric one-week sign fade, the two-week shoulder fade, and the SMA/stretch/wick failed-rally system. Verify exact completed week, strict CLV inequality, no return/range/body/wick/mean predicates, short-only side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, april_may_september_october_gate, normalized_week_clock, immediately_completed_week, bounded_week_sessions, strict_upper_tercile_close_location, no_return_sign_gate, no_range_rank, no_body_wick_or_mean_gate, short_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete official-government, peer-reviewed, and academic lineage with explicit translation risk; R2 exact mechanical XNG shoulder-season upper-tercile weekly-close short reversion; R3 XNGUSD.DWX D1; R4 deterministic non-ML; one expected WTI fuzzy match manually separated by carrier and calendar, and all XNG neighbors mechanically separated."
---

# QM5_41465 XNG Shoulder Upper-Tercile Weekly-Close Reversion

## Hypothesis

During the EIA-documented April-May and September-October natural-gas demand
lulls, a completed week settling in the upper third of its full range may be
a temporary rally that reverts over the next normalized broker week. Short at
the next week boundary and hold one week. This exact Darwinex-CFD rule is
unproven and belongs to Q02.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/EIA-MOP-YANG-XNG-SHOULDER-HCLV-FADE-20260913/source.md`.
EIA supplies the four shoulder months; the governed MOP-XNG packet supplies
completed-week and close-location lineage; Yang et al. supply commodity-
reversal lineage. None establishes this conjunction.

The canonical scan found no exact identity and one fuzzy match, `QM5_41462`,
which trades WTI in June-October. `QM5_41392` fades completed-week return sign
symmetrically; `QM5_41401` requires two same-sign weeks; `QM5_12595` requires
a D1 slow-mean stretch, channel high, and upper wick; and certified
`QM5_12567` is an all-year long-only two-day cumulative-RSI pullback. This card
uses one completed week, no return/range/body/wick/mean gate, and only the
shoulder-season upper-tercile short. The exact mechanic is distinct.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on setfile-bound `XNGUSD.DWX` D1 with EA 41465, slot zero,
   registered magic, and fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist
   the attempt before calendar, history, signal, news, spread, quote, ATR,
   sizing, or order gates. Never retry.
3. Continue only when the Monday anchor month is April, May, September, or
   October and entry is within 180 elapsed minutes.
4. Reconstruct exactly the immediately completed normalized week with three
   through five valid, unique, ordered D1 sessions. Exclude every current-week
   bar.
5. Require a positive finite weekly range and compute
   `CLV=(final_close-low)/(high-low)`.
6. Sell only when `CLV > strategy_clv_cutoff`, locked to two thirds. Equality
   or a lower close is flat. There is no long side, range-rank test, or
   candle-body-sign test.
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
malformed completed-week package, non-upper-tercile settlement, spread,
quote, ATR, stop, sizing, or order state. Framework RNG, news, and
Friday-close inputs remain configurable and are never equality-pinned. Stress
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
| `strategy_symbol` | `XNGUSD.DWX` |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 20 |
| `strategy_shoulder_month_1` | 4 |
| `strategy_shoulder_month_2` | 5 |
| `strategy_shoulder_month_3` | 9 |
| `strategy_shoulder_month_4` | 10 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_clv_cutoff` | 0.666666666667 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, formation, CLV cutoff, orientation, carrier, stop,
hold, spread, or retry contract requires a new identity. The zero-offset label
is locked from existing Model-4 XNG decision-clock evidence before testing.

## Source-Defined Rules

EIA supplies the April-May and September-October natural-gas demand-lull
context. Yang et al. supply broad commodity reversal. The governed MOP-XNG
record supplies weekly close-location construction. They do not supply this
exact weekly conjunction.

## QM Interpretations

Monday anchors, one completed week, strict upper-tercile threshold, boundary
entry, one-week hold, retry semantics, and every numeric execution threshold
are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the weekly lifecycle
is intact. Those framework inputs and RNG seed remain configurable and
unpinned. Stress rejection receives only range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed owned-exposure repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties,
positions, deal history, ATR, and terminal-global attempt state only. No
weather, inventory, curve, volume, open-interest, file, API, optimizer,
trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
XNG gaps, roll/basis, financing, label sensitivity, sample scarcity, stop
slippage, source translation, and overlap with other XNG candidates can
dominate. Q02 owns economics; unchanged Q09 alone owns realized portfolio
correlation.

## Strategy Allowability Check

- [x] R1 reputable-source criteria satisfied with complete-read durable records.
- [x] R2 deterministic calendar, weekly OHLC, CLV, side, stop, and lifecycle.
- [x] R3 registered `XNGUSD.DWX` D1 native route only.
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

Q01 must verify eligible/ineligible months, exact completed week,
session-count bounds, strict CLV inequality and equality, absence of
range/body gates, short-only side, durable attempt, frozen stop, next-week
exit, card lint, resolver, PACER audit, reference tests, and strict
compile/build checks. Q02 retires on zero trades only after clock and entry
observability prove exercise; otherwise the run enters zero-trades recovery.
Fewer than five completed positions in a full scored year, nonpositive
governed economics, or contract mismatch also retires it. No weak result may
be tuned into survival.

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
| Q01 Build Validation | — | PENDING | build not yet submitted |
| Q02 Baseline Screening | — | NOT_ENQUEUED | requires Q01 PASS and CPU admission |
