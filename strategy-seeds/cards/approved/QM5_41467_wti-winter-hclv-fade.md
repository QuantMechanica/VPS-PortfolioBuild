---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913_S01
variant_id: BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913_S01
source_id: BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913
ea_id: QM5_41467
slug: wti-winter-hclv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41467_wti-winter-hclv-fade.md
execution_contract_status: APPROVED
created: 2026-09-13
created_by: Research+Development
last_updated: 2026-09-13
g0_status: APPROVED
g0_decision: decisions/2026-09-13_qm5_41467_wti_winter_upper_clv_reversion_g0.md
source_approval: decisions/2026-09-13_wti_winter_upper_clv_reversion_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_authors: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Toby Crabel; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin & Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Yang, Goncu & Pantelous (2017), SSRN 3069253; governed Crabel completed-week/close-location lineage."
source_citations:
  - type: peer_reviewed_reputable_and_academic_bounded_mechanization
    citation: "Peer-reviewed WTI winter evidence, governed reputable close-location lineage, and academic commodity reversal evidence."
    location: strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913/source.md
    quality_tier: B_and_academic_lineages_with_cross_source_horizon_counter_seasonal_and_cfd_translation_risk
    role: wti_winter_regime_weekly_upper_close_reversion_lineage
strategy_mechanic: normalized-weekly-wti-november-through-may-one-completed-week-upper-tercile-close-location-short-only-reversion-one-week-hold
sources: ["[[sources/BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913]]"]
concepts: ["[[concepts/wti-winter-seasonality]]", "[[concepts/completed-week-close-location]]", "[[concepts/commodity-reversal]]"]
indicators: ["[[indicators/completed-week-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, weekly-close-location, mean-reversion, short-only, atr-hard-stop, time-stop, low-frequency]
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
magic: 414670000
period: D1
timeframe: D1
direction: short_only
expected_trade_frequency: "Approximately eight to twelve completed positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_HORIZON_AND_COUNTER_SEASONAL_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; November-May; one immediately completed week with 3-5 sessions; final close strictly above two thirds of full range; short only; 20 D1 history bars; 180-minute grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a counter-seasonal WTI November-May upper-close weekly reversion stream distinct from the certified XNG oscillator, winter upper-close continuation, summer upper-close fade, and range-ranked weekly siblings. Verify exact completed week, strict upper-tercile inequality, short-only side, durable attempt, fixed risk, frozen stop, and next-week lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, november_may_calendar_gate, normalized_week_clock, immediately_preceding_completed_week, bounded_week_sessions, strict_upper_tercile_close, short_only_reversion, persistent_week_attempt, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed, governed reputable, and academic lineage with explicit counter-seasonal and CFD translation risk; R2 exact mechanical one-week upper-close fade; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41467 WTI Winter Upper-CLV Reversion

## Hypothesis

During the November-May WTI winter regime, an immediately completed week that settles in the
upper third of its own range may represent a short-lived relative overextension. Sell WTI for the
following normalized week. The direction is counter to the source regime's positive average and
is therefore an explicitly unproven reversal hypothesis, not a transferred source result.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/BURAKOV-CRABEL-YANG-WTI-WINTER-HCLV-FADE-20260913/source.md`. Burakov et
al. supply the winter WTI regime, governed Crabel work supplies completed-week and close-location
lineage, and Yang et al. supply commodity-reversal lineage. None validates this conjunction.

The canonical scan found no exact identity and raised five expected fuzzy relatives. `QM5_41442`
and `QM5_41456` require two completed weeks, range expansion/contraction, and symmetric outer-
quartile signals; `QM5_41444` and `QM5_41446` use body sign with two-week range state. `QM5_41462`
uses the same upper-tercile short only in June-October, while `QM5_41463` buys the same winter
upper-tercile state. The winter clock, one-week package, upper-tercile state, and short-only
reversion side are jointly load-bearing.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only on the setfile-bound `XTIUSD.DWX` D1 host with EA 41467, slot zero, registered magic,
   and fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   calendar, history, signal, news, spread, quote, ATR, sizing, margin, or order gates. Never retry.
3. Enter only within 180 elapsed minutes and only when the anchor month is November, December,
   January, February, March, April, or May.
4. Reconstruct exactly the immediately completed week, requiring three through five valid,
   unique, ordered D1 sessions and excluding every current-week bar.
5. Require positive finite full range. Compute `CLV=(final_close-low)/(high-low)`. Sell only when
   `CLV > 2/3`; equality and all lower states are flat. Do not require weekly return sign, range
   rank, candle body, wick, stretch, containment, or a moving average.
6. Require allowed spread, executable quotes, completed ATR(20,D1), valid metadata, and one
   normalized frozen `3.5*ATR` hard stop. There is no take profit.

## 5. Exit Rules

Close on the first processed tick in the normalized week after entry. Ten elapsed calendar days
is stale repair. Broker hard stop and framework kill switch remain authoritative. There is no
target, signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, ineligible month, malformed package, nonpositive range, a non-upper-
tercile close, spread, quote, ATR, stop, sizing, margin, or order state. Framework RNG, news, and
Friday-close inputs remain configurable and are never equality-pinned. Stress rejection is
checked only for finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, non-short, missing-stop, take-profit-
bearing, future-dated, or invalid-volume owned exposure. No trail, break-even, partial close,
scale-in, pyramid, grid, martingale, hedge, reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 20 |
| `strategy_winter_month_1..7` | 11 / 12 / 1 / 2 / 3 / 4 / 5 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_clv_cutoff` | 0.666666666667 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the carrier, calendar, week construction, threshold, direction, stop, hold, spread, or
retry contract requires a new identity.

## Source-Defined Rules

The sources supply the WTI winter regime and broad weekly close-location/reversal lineage. They
do not supply the exact conjunction, direction, thresholds, risk, or execution contract.

## QM Interpretations

Monday anchors, one completed week, strict upper-tercile comparison, short-only side, one-week
hold, retry semantics, and every numeric execution threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the strategy-owned lifecycle is measured
intact. Those framework inputs and RNG seed remain configurable and unpinned. Stress rejection
receives only range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed owned-exposure repair;
3. first processed tick of the normalized week after entry;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties, positions, deal
history, ATR, and terminal-global attempt state only. No futures curve, inventory, volume, open
interest, file, API, optimizer, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Counter-seasonal drift,
WTI gaps, roll/basis, financing, label sensitivity, sparse seasonal samples, stop slippage, and
overlap with other WTI candidates can dominate. Q02 owns economics; unchanged Q09 alone owns
realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, calendar, package, CLV, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed exposure, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify month eligibility, completed-week adjacency, three-to-five-session bounds, current-
week exclusion, positive range, strict upper-tercile/equality states, body-sign irrelevance, short-
only entry, durable attempt, frozen stop, next-week exit, card lint, resolver, PACER audit,
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
| G0 Source Approval | 2026-09-13 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-13 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-13 | PENDING | build not yet generated |
| Q02 Baseline Screening | 2026-09-13 | NOT_ENQUEUED | Q01 and CPU admission required |
