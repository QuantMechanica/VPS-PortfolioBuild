---
card_schema_version: 2
type: strategy
strategy_id: EIA-YANG-XNG-WINTER-W2FADE-20260910_S01
variant_id: EIA-YANG-XNG-WINTER-W2FADE-20260910_S01
source_id: EIA-YANG-XNG-WINTER-W2FADE-20260910
ea_id: QM5_41408
slug: xng-winter-w2fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41408_xng-winter-w2fade_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41408_xng_winter_two_week_fade_g0.md
source_approval: decisions/2026-09-10_xng_winter_two_week_fade_source_approval.md
source_author: "U.S. Energy Information Administration; Hongbing Yang; Ahmet Goncu; Athanasios Pantelous; OpenAI Codex"
source_citation: "U.S. Energy Information Administration natural-gas seasonal-demand context; Yang, Goncu and Pantelous (2017), SSRN 3069253."
source_citations:
  - type: official_government_and_academic_bounded_mechanization
    citation: "EIA natural-gas winter-demand context plus Yang-Goncu-Pantelous commodity reversal lineage; QuantMechanica governed weekly interaction."
    location: strategy-seeds/sources/EIA-YANG-XNG-WINTER-W2FADE-20260910/source.md
    quality_tier: B_lineages_with_horizon_and_interaction_translation_risk
    role: winter_regime_and_contrarian_direction_lineage
strategy_mechanic: normalized-weekly-xng-two-adjacent-completed-week-open-to-close-log-returns-strict-same-sign-contrarian-only-november-december-january-february-march-one-week-hold
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, winter-demand, two-week-exhaustion, weekly-reversal, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
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
magic: 414080000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 8-16 winter weekly packages per full year after strict two-week sign agreement; Q02 must prove at least five completed trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_HORIZON_AND_INTERACTION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; native zero-offset D1 labels; normalized Monday week anchor; eligible months 11,12,1,2,3; two immediately completed adjacent weeks; 3-5 sessions each; ln(final close/first open); strict same-sign agreement; exact-zero epsilon; contrarian side; 24 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: G0
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify an XNG winter two-week exhaustion fade distinct from certified QM5_12567, same-regime continuation, disjoint shoulder fade, one-week winter momentum, and WTI winter relatives. Verify native label clock, exact weekly membership, strict agreement, inverse orientation, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, november_march_gate, native_d1_label_clock, two_completed_week_membership, strict_same_sign_agreement, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus academic commodity-reversal context with disclosed horizon/interaction translation risk; R2 exact mechanical winter two-week fade; R3 registered XNGUSD.DWX D1; R4 deterministic non-ML; fuzzy family matches manually resolved."
---

# QM5_41408 XNG Winter Two-Week Exhaustion Fade

## Hypothesis

Natural gas has a recurring November-through-March heating-demand regime. When
the two immediately completed weeks both moved in the same direction, their
agreement may identify a short-lived extension that partially reverses during
the following week. This is an untested price-only interaction, not a source-
authored trading rule, profitability claim, or decorrelation claim.

## Source Traceability And Non-Duplicate Decision

The source of record is
`strategy-seeds/sources/EIA-YANG-XNG-WINTER-W2FADE-20260910/source.md`. Its
governed parents preserve complete reads of official EIA seasonality context
and an academic commodity-reversal source. Neither tests this exact weekly
conjunction.

The canonical screen found no exact collision and returned expected family
matches while the Strategy Wiki root was unavailable. `QM5_41402` follows the
same XNG winter state; this card fades it. `QM5_41403` fades WTI across a
different seven-month window. `QM5_41401` is disjoint shoulder-season XNG.
`QM5_41395` follows one winter week. Certified `QM5_12567` is a long-only
two-day cumulative-RSI pullback above a slow trend. This card uniquely fixes
XNG, November-March, two adjacent complete weeks, strict same-sign agreement,
inverse direction, and a one-week lifecycle together.

## Rules

### Entry

1. Run only on preset-bound `XNGUSD.DWX` D1 with EA 41408, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the attempt before calendar, history, signal, news, spread, quote,
   ATR, sizing, or order gates. Never retry that week.
3. Use native zero-offset D1 labels. Continue only when the Monday anchor
   month is November, December, January, February, or March and entry is
   within 180 elapsed session minutes.
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
| `strategy_winter_month_1..5` | 11 / 12 / 1 / 2 / 3 |
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
- R2: pass; all signal and lifecycle rules are mechanical.
- R3: pass with continuous-CFD basis risk on registered XNG D1 history.
- R4: pass; deterministic native arithmetic only.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk mode, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, winter gate, packages, agreement, inverse side, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all five eligible months, ineligible boundaries, positive and
negative agreement, inverse direction, mixed/zero flat states, three-to-five
sessions per week, adjacency, current-week exclusion, attempt persistence,
frozen stop, next-week exit, card lint, magic resolver, PACER audit, reference
tests, and strict compile/build checks. Q02 retires on zero positions, fewer
than five completed positions in any full scored year, nonpositive governed
economics, or any contract mismatch. No weak result may be rescued by tuning.

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
| Q01 Build Validation | - | NOT_BUILT | pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 and CPU ceiling |

