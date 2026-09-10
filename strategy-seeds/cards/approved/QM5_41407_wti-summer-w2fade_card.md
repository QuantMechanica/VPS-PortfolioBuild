---
card_schema_version: 2
type: strategy
strategy_id: BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910_S01
variant_id: BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910_S01
source_id: BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910
ea_id: QM5_41407
slug: wti-summer-w2fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41407_wti-summer-w2fade_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41407_wti_summer_two_week_fade_g0.md
source_approval: decisions/2026-09-10_wti_summer_two_week_fade_source_approval.md
source_author: "Dmitry Burakov; Max Freidin; Yuriy Solovyev; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "Burakov, Freidin and Solovyev (2018), International Journal of Energy Economics and Policy 8(2), 121-126; Yang, Goncu and Pantelous (2017), SSRN 3069253."
source_citations:
  - type: peer_reviewed_bounded_mechanization
    citation: "WTI June-October seasonality plus commodity fixed-horizon reversal lineage; QuantMechanica governed weekly interaction."
    location: strategy-seeds/sources/BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910/source.md
    quality_tier: B_lineages_with_horizon_and_interaction_translation_risk
    role: summer_regime_and_contrarian_direction_lineage
strategy_mechanic: normalized-weekly-wti-two-adjacent-completed-week-open-to-close-log-returns-strict-same-sign-contrarian-only-june-july-august-september-october-one-week-hold
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, summer-regime, two-week-exhaustion, weekly-reversal, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
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
magic: 414070000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 7-12 completed summer weekly packages per full year after strict two-week sign agreement; Q02 must prove at least five completed trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; normalized Monday week anchor; eligible months 6,7,8,9,10; two immediately completed adjacent weeks; 3-5 sessions each; ln(final close/first open); strict same-sign agreement; exact-zero epsilon; contrarian side; 24 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a WTI summer two-week exhaustion fade distinct from the incumbent RSI pullback, same-regime continuation, disjoint winter fade, year-round one-week relatives, and XNG relatives. Verify anchor-month eligibility, exact adjacent completed-week membership, strict agreement, inverse orientation, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, june_october_gate, normalized_week_clock, two_completed_week_membership, strict_same_sign_agreement, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed WTI seasonality plus academic commodity-reversal context with disclosed horizon/interaction translation risk; R2 exact mechanical summer two-week fade; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; expected fuzzy family matches manually resolved."
---

# QM5_41407 WTI Summer Two-Week Exhaustion Fade

## Hypothesis

WTI has a documented June-through-October seasonal regime. When the two
immediately completed weeks both moved in the same direction, that agreement
may identify a short-lived extension that partially reverses during the structural summer regime.
This is an untested price-only interaction, not a source-authored rule,
profitability claim, or decorrelation claim.

## Source Traceability And Non-Duplicate Decision

The source of record is
`strategy-seeds/sources/BURAKOV-YANG-WTI-SUMMER-W2FADE-20260910/source.md`.
Its governed parents preserve complete reads of a peer-reviewed WTI seasonal
paper and an academic commodity-reversal paper. Neither parent tests
this exact weekly conjunction.

The canonical screen found no exact identity and the expected fuzzy family
members while reporting the Strategy Wiki root unavailable. `QM5_41406` uses
the same summer WTI information object but follows rather than fades it.
`QM5_41403` fades the same WTI information object only in the disjoint
November-May window. `QM5_41401` is an XNG shoulder-season fade, and
`QM5_41396` is XNG June-August summer agreement. `QM5_41375` follows one completed WTI week year-round, and
`QM5_41022` follows two segments inside one week year-round. `QM5_12567` is a
long-only cumulative-RSI pullback. This card uniquely fixes WTI,
June-October, two adjacent complete weeks, strict same-sign agreement,
inverse direction, and a one-week lifecycle together.

## Rules

### Entry

1. Run only on the setfile-bound `XTIUSD.DWX` D1 host with EA 41407, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is June, July, August,
   September, or October and entry is within 180 elapsed session minutes.
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
equality-pinned by the EA. Stress rejection is checked only for finiteness and
inclusive `0..1` range.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 24 |
| `strategy_summer_month_1..5` | 6 / 7 / 8 / 9 / 10 |
| `strategy_required_weeks` | 2 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, sample, agreement, direction, carrier, stop, hold,
spread, or retry contract requires a new identity.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, continuous-CFD roll/basis and financing,
weekly label sensitivity, reversal crashes, hard-stop slippage, and overlap
with other energy sleeves can dominate. Q02 owns activity/economics; unchanged
Q09 alone owns realized portfolio correlation.

## Data Requirements

Native configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol
properties, positions, deal history, and terminal-global attempt state only.
No futures curve, inventory, volume, open interest, file, API, trained output,
optimizer result, or portfolio state is read at runtime.

## Strategy Allowability Check

- R1: pass with the source and translation boundaries above.
- R2: pass; all signal and lifecycle rules are mechanical.
- R3: pass with continuous-CFD basis risk on registered WTI D1 history.
- R4: pass; deterministic native arithmetic only.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk mode, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, summer gate, packages, agreement, inverse side, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all five eligible months, ineligible boundaries, positive and
negative agreement, inverse direction, mixed/zero flat states,
three-to-five sessions per week, adjacency, current-week exclusion, attempt
persistence, frozen stop, next-week exit, card lint, magic resolver, PACER
audit, reference tests, and strict compile/build checks. Q02 retires on zero
positions, fewer than five completed positions in any full scored year,
nonpositive governed economics, or any contract mismatch. No weak result may
be rescued by tuning.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build/Q01, one
fixed-risk backtest set, and one paced Q02 enqueue below the CPU ceiling.
Forbidden: manual backtests, optimization, portfolio-gate edits or admission,
correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-10 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-10 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-10 | PASS | governed compile `4810479a-091e-4c02-b778-2578b06d7f3d`; 0 errors/warnings; build check PASS; 15 reference tests; PACER pin audit clean |
| Q02 Baseline Screening | 2026-09-10 | NOT_ENQUEUED_CPU_CEILING | intake dry-run eligible after exact symbol binding; apply skipped at CPU 96/97/99/100/97% |

