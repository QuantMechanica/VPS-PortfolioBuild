---
card_schema_version: 2
type: strategy
strategy_id: EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911_S01
variant_id: EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911_S01
source_id: EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911
ea_id: QM5_41429
slug: wti-refmaint-wclv-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41429_wti-refmaint-wclv-fade_card.md
execution_contract_status: APPROVED
created: 2026-09-11
created_by: Research+Development
last_updated: 2026-09-11
g0_status: APPROVED
g0_decision: decisions/2026-09-11_qm5_41429_wti_refinery_maintenance_weekly_close_location_reversion_g0.md
source_approval: decisions/2026-09-11_wti_refinery_maintenance_weekly_close_location_reversion_source_approval.md
source_author: "U.S. Energy Information Administration; Cheng Yang; Aydin Goncu; Athanasios A. Pantelous; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Cheng Yang; Aydin Goncu; Athanasios A. Pantelous; OpenAI Codex"
source_citation: "EIA refinery-maintenance and pre-summer utilization context; Yang, Goncu and Pantelous (2017), Momentum and Reversal in Commodity Futures, SSRN 3069253."
source_citations:
  - type: official_government_and_academic_bounded_mechanization
    citation: "EIA refinery-utilization-ramp context plus Yang-Goncu-Pantelous commodity-futures reversal lineage."
    location: strategy-seeds/sources/EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911/source.md
    quality_tier: A_lineages_with_cross_source_calendar_and_weekly_translation_risk
    role: refinery_ramp_context_and_directional_reversal_lineage
strategy_mechanic: normalized-weekly-wti-refinery-maintenance-february-march-september-october-two-completed-weeks-parent-close-to-newest-close-strict-positive-return-newest-week-upper-tercile-close-location-short-reversion-one-week-hold
sources: ["[[sources/EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911]]"]
concepts: ["[[concepts/commodity-reversal]]", "[[concepts/refinery-utilization-ramp]]", "[[concepts/completed-week-close-location]]"]
indicators: ["[[indicators/completed-week-ohlc]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, refinery-maintenance, completed-week-close-location, weekly-reversion, short-only, atr-hard-stop, time-stop, low-frequency]
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
magic: 414290000
period: D1
timeframe: D1
direction: short_only
expected_trade_frequency: "Approximately 5-8 completed positions per full post-warm-up year after the positive-return and upper-tercile gates; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_CALENDAR_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; eligible months 2,3,9,10; two immediately completed adjacent weeks with 3-5 sessions each; strictly positive parent-close to newest-close log return; newest close location strictly above 2/3; short-only reversion; 30 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PENDING
q02_status: PENDING
q01_build_report: pending
force_build: true
review_focus: "Falsify a short-only WTI refinery-maintenance completed-week close-location reversion distinct from the mutually exclusive negative/lower-tercile continuation and the one-week open-to-close fade. Verify exact two-week membership, parent-close endpoint, upper-tercile gate, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, refinery_maintenance_month_gate, normalized_week_clock, two_completed_week_membership, parent_close_to_newest_close_endpoint, strict_positive_sign, strict_upper_tercile_close_location, short_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 one canonical governed child source with complete official EIA and academic commodity-reversal lineage plus explicit translation risk; R2 exact mechanical short-only February/March/September/October two-week endpoint/range reversion; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate and three fuzzy family neighbors manually resolved."
---

# QM5_41429 WTI Refinery-Maintenance Weekly Close-Location Reversion

## Hypothesis

Recurring refinery maintenance and autumn turnarounds can temporarily weaken
crude runs and physical demand. During February, March, September, or October,
a positive two-week close-to-close move that also settles in the newest week's
upper tercile may identify an overextended rally that reverses for one week.
This exact price-only interaction is unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The single source of record is
`strategy-seeds/sources/EIA-YANG-WTI-REFMAINT-WCLV-FADE-20260911/source.md`.
EIA supports only refinery-maintenance context; the governed Yang packet supports
broader commodity-futures reversal. Neither establishes this WTI CFD result.

The canonical checker found no exact identity and surfaced three fuzzy family
neighbors. `QM5_41427` sells only negative/lower-tercile states as continuation;
this card sells only positive/upper-tercile states as reversion, so their states
are mutually exclusive. `QM5_41424` uses one completed week's open-to-close
sign without a range-location gate. This card uses two adjacent completed
packages and a parent-close endpoint; an opening gap can make their signs
disagree. `QM5_41428` trades April-July and buys negative/lower-tercile states.

## Rules

### Entry

1. Run only on the setfile-bound `XTIUSD.DWX` D1 host with EA 41429, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is February, March, September,
   or October and
   entry is within 180 elapsed session minutes.
4. Reconstruct exactly the two immediately completed adjacent normalized
   weeks; each must contain three through five valid, unique D1 sessions.
5. Compute `r = ln(newest_final_close / parent_final_close)` and
   `clv = (newest_final_close-newest_low)/(newest_high-newest_low)`.
6. If `r > 0` and `clv > 2/3`, sell. Equality, a nonpositive return, a lower
   close location, zero range, malformed/stale history, or nonfinite arithmetic
   stays flat and consumes the week. Never buy.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid
   symbol metadata, and one normalized frozen `3.5*ATR` hard stop.

### Exit And Management

Close on the first processed tick in the next normalized broker week. Ten
elapsed days is stale repair. Immediately flatten duplicate, wrong-symbol,
wrong-magic, non-short, missing-stop, take-profit-bearing, future-dated, or
invalid-volume owned exposure. The broker stop and framework kill switch are
authoritative. No target, intraweek signal flip, trail, break-even, partial
close, scale-in, pyramid, grid, martingale, or discretionary exit is allowed.

### No-Trade And Framework Inputs

Fail closed on wrong host/period/identity/slot/risk mode, unlocked
`strategy_*` configuration, late restart, consumed week, ineligible month,
bad packages, nonpositive return, non-upper-tercile close, spread, quote, ATR,
stop, sizing, or order state. Framework RNG, news, and Friday-close inputs
remain configurable and are never equality-pinned by the EA. Stress rejection
is checked only for finiteness and inclusive `0..1` range.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 30 |
| `strategy_maintenance_month_1..4` | 2 / 3 / 9 / 10 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_clv_upper` | 0.6666666666666667 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, packages, endpoint, threshold, direction, carrier,
stop, hold, spread, or retry contract requires a new identity.

## Risk And Data

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Runtime uses configured-symbol D1 OHLC/timestamps,
broker clock, quotes, symbol properties, positions, deal history, and terminal-
global attempt state only. No refinery, inventory, curve, volume, open-
interest, file, API, trained output, optimizer result, or portfolio state is
read at runtime.

WTI gaps, roll/basis/financing, label sensitivity, sparse seasonal samples,
hard-stop slippage, regime instability, source translation, and overlap with
other WTI sleeves can dominate. Q02 owns activity/economics; unchanged Q09
alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk mode, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, ramp gate, packages, endpoint, close location, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all four eligible months, ineligible boundaries, qualifying
short entry, negative/zero/equality/lower-location flat states, three-to-five
sessions per week, adjacency, current-week exclusion, attempt persistence,
frozen stop, next-week exit, card lint, magic resolver, PACER audit, reference
tests, and strict compile/build checks. Q02 retires on zero positions, fewer
than five completed positions in any full scored year, nonpositive governed
economics, or any contract mismatch. No weak result may be rescued by tuning;
a material rule change requires a new identity and G0 review. Q09 alone may
establish realized portfolio diversification.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build/Q01, one
fixed-risk backtest set, and one paced Q02 enqueue below the CPU ceiling.
Forbidden: manual backtests, optimization, portfolio-gate edits or admission,
correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-11 | APPROVED_SOURCE | `decisions/2026-09-11_wti_refinery_maintenance_weekly_close_location_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-11 | APPROVED | decision above |
| Q01 Build Validation | 2026-09-11 | PENDING | governed build not yet executed |
| Q02 Baseline Screening | 2026-09-11 | PENDING | fixed-risk XTIUSD.DWX D1 canary not yet enqueued |
