---
card_schema_version: 2
type: strategy
strategy_id: EIA-YANG-XNG-SUMMER-W2FADE-20260910_S01
variant_id: EIA-YANG-XNG-SUMMER-W2FADE-20260910_S01
source_id: EIA-YANG-XNG-SUMMER-W2FADE-20260910
ea_id: QM5_41409
slug: xng-summer-w2fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41409_xng-summer-w2fade_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41409_xng_summer_two_week_fade_g0.md
source_approval: decisions/2026-09-10_xng_summer_two_week_fade_source_approval.md
source_author: "U.S. Energy Information Administration; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "U.S. Energy Information Administration natural-gas seasonal-demand context; Yang, Goncu and Pantelous (2017), SSRN 3069253."
source_citations:
  - type: official_government_and_academic_bounded_mechanization
    citation: "EIA natural-gas summer-demand context plus Yang-Goncu-Pantelous commodity reversal lineage; QuantMechanica governed weekly interaction."
    location: strategy-seeds/sources/EIA-YANG-XNG-SUMMER-W2FADE-20260910/source.md
    quality_tier: B_lineages_with_horizon_and_interaction_translation_risk
    role: summer_regime_and_contrarian_direction_lineage
strategy_mechanic: normalized-weekly-xng-two-adjacent-completed-week-open-to-close-log-returns-strict-same-sign-contrarian-only-june-july-august-one-week-hold
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, summer-demand, two-week-exhaustion, weekly-reversal, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
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
magic: 414090000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-10 summer weekly packages per full year after strict two-week sign agreement; Q02 must prove at least five completed trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; native zero-offset D1 labels; normalized Monday week anchor; eligible months 6,7,8; two immediately completed adjacent weeks; 3-5 sessions each; ln(final close/first open); strict same-sign agreement; exact-zero epsilon; contrarian side; 24 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: COMPILE_ENQUEUED_PENDING
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify an XNG summer two-week exhaustion fade distinct from certified QM5_12567, same-regime continuation, disjoint shoulder/winter fades, year-round volatility-gated weekly reversal, and WTI summer relatives. Verify native label clock, exact weekly membership, strict agreement, inverse orientation, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, june_august_gate, native_d1_label_clock, two_completed_week_membership, strict_same_sign_agreement, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus academic commodity-reversal context with disclosed horizon/interaction translation risk; R2 exact mechanical summer two-week fade; R3 registered XNGUSD.DWX D1; R4 deterministic non-ML; fuzzy family matches manually resolved."
---

# QM5_41409 XNG Summer Two-Week Exhaustion Fade

## Hypothesis

Natural gas has a recurring June-through-August electric-generation demand
regime. When the two immediately completed weeks both moved in the same
direction, their agreement may identify a short-lived extension that partially
reverses during the following week. This is an untested price-only interaction,
not a source-authored trading rule, profitability claim, or decorrelation claim.

## Source Traceability And Non-Duplicate Decision

The source of record is
`strategy-seeds/sources/EIA-YANG-XNG-SUMMER-W2FADE-20260910/source.md`. Its
governed parents preserve complete reads of official EIA seasonality context
and an academic commodity-reversal source. Neither tests this exact weekly
conjunction.

The canonical screen found no exact collision and returned expected family
matches while the Strategy Wiki root was unavailable. `QM5_41396` follows the
same XNG summer state; this card fades it. `QM5_41407` fades WTI over a broader
June-October window. `QM5_41401` and `QM5_41408` are disjoint shoulder and
winter XNG fades. `QM5_13102` is a year-round one-week reversal with a
volatility gate. Certified `QM5_12567` is a long-only two-day cumulative-RSI
pullback above a slow trend. This card uniquely fixes XNG, June-August, two
adjacent complete weeks, strict same-sign agreement, inverse direction, and a
one-week lifecycle together.

## Rules

### Entry

1. Run only on preset-bound `XNGUSD.DWX` D1 with EA 41409, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the attempt before calendar, history, signal, news, spread, quote,
   ATR, sizing, or order gates. Never retry that week.
3. Use native zero-offset D1 labels. Continue only when the Monday anchor
   month is June, July, or August and entry is within 180 elapsed session
   minutes.
4. Reconstruct exactly the two immediately completed adjacent normalized
   weeks; each must contain three through five valid, unique D1 sessions.
5. Compute `r = ln(final_close / first_open)` for each completed week.
6. If both returns are strictly positive, sell. If both are strictly negative,
   buy. Mixed signs, exact zero, malformed data, or nonfinite arithmetic stays
   flat and consumes the week.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid
   symbol metadata, and one normalized frozen `3.5*ATR` hard stop.

### Exit And Management

Close on the first processed tick in the next normalized broker week. Ten
elapsed days is stale repair. Immediately flatten duplicate, wrong-symbol,
wrong-magic, invalid-side, missing-stop, take-profit-bearing, future-dated, or
invalid-volume owned exposure. The broker stop and framework kill switch are
authoritative. No target, intraweek signal flip, trail, break-even, partial
close, scale-in, pyramid, grid, martingale, or discretionary exit is allowed.

### No-Trade And Framework Inputs

Fail closed on wrong host/period/identity/slot/risk mode, unlocked
`strategy_*` configuration, late restart, consumed week, ineligible month,
bad packages, nonagreement, spread, quote, ATR, stop, sizing, or order state.
Framework RNG, news, and Friday-close inputs remain configurable and are never
equality-pinned. Stress rejection is checked only for finiteness and inclusive
`0..1` range.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XNGUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 0 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 24 |
| `strategy_summer_month_1..3` | 6 / 7 / 8 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, sample, agreement, direction, carrier, stop, hold,
spread, label contract, or retry contract requires a new identity.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Natural-gas gaps, continuous-CFD roll/basis and
financing, weekly label sensitivity, reversal crashes, hard-stop slippage, and
overlap with other XNG sleeves can dominate. Q02 owns activity/economics;
unchanged Q09 alone owns realized portfolio correlation.

## Data Requirements

Native configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol
properties, positions, deal history, and terminal-global attempt state only.
No EIA/storage/weather/curve/volume/open-interest/file/API/trained output,
optimizer result, or portfolio state is read at runtime.

## Strategy Allowability Check

- R1: pass with the source and translation boundaries above.
- R2: pass; every rule and lifecycle is deterministic.
- R3: pass with explicit continuous-CFD basis risk.
- R4: pass; no ML or banned indicator is used.

## Framework Alignment

| Card rule | Module | Implementation target |
|---|---|---|
| identity, carrier, period, risk, locked strategy configuration | No-Trade | `Strategy_NoTradeFilter`, `OnInit` validation |
| week clock, summer gate, packages, agreement, inverse side, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| invariant repair and duplicate flattening | Trade Management | `Strategy_ManageOpenPosition` |
| next-week close and ten-day stale repair | Trade Close | `Strategy_ExitSignal` |
| framework news delegation | News hook | `Strategy_NewsFilterHook` |

## Validation Plan

1. Schema lint and exact/fuzzy duplicate evidence.
2. Static reference harness for week keys, package formation, month gate,
   inverse map, attempt ordering, invariant repair, and guard scope.
3. Mandatory PACER framework-input pin audit after source generation and
   before compile enqueue; any nonzero exit or finding refuses the build.
4. Governed compile with zero errors/warnings and strict build checks.
5. One Q02 intake dry run, then CPU ceiling check. Enqueue only if eligible and
   under the ceiling; otherwise stop and record the refusal.

## Promotion And Safety Boundary

G0 authorizes only allocation, branch build, Q01, and paced non-live Q02. It
does not authorize a manual test, optimization, portfolio admission,
correlation waiver, portfolio-gate edit, deployment, live manifest change,
`T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Status

| Gate | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-10 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-10 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-10 | COMPILE_ENQUEUED_PENDING | governed item `42a891ea-be6b-4c40-bece-52f923c70713`; pin audit PASS; static build check PASS; 15/15 reference tests PASS |
| Q02 Baseline Screening | 2026-09-10 | NOT_ENQUEUED_CPU_CEILING | intake dry run refused pending compile; CPU samples `91,88,97,90,97`, exclusive 97% ceiling reached |
