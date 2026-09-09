---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-XNG-SHOULDER-W2FADE-20260909_S01
variant_id: EIA-MOP-XNG-SHOULDER-W2FADE-20260909_S01
source_id: EIA-MOP-XNG-SHOULDER-W2FADE-20260909
ea_id: QM5_41401
slug: xng-shoulder-w2fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41401_xng-shoulder-w2fade_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41401_xng_shoulder_two_week_fade_g0.md
source_approval: decisions/2026-09-09_xng_shoulder_two_week_fade_source_approval.md
source_author: "U.S. Energy Information Administration; OpenAI Codex"
source_citation: "QuantMechanica governed XNG shoulder-season two-week exhaustion translation preserving official EIA seasonality and peer-reviewed commodity persistence context."
source_citations:
  - type: governed_mechanization
    citation: "QuantMechanica (2026). XNG shoulder-season two-week exhaustion fade."
    location: strategy-seeds/sources/EIA-MOP-XNG-SHOULDER-W2FADE-20260909/source.md
    quality_tier: governed_source_with_translation_risk
    role: exact_calendar_weekly_package_direction_risk_and_lifecycle_contract
strategy_mechanic: normalized-weekly-xng-two-adjacent-completed-week-open-to-close-log-returns-strict-same-sign-contrarian-only-april-may-september-october-one-week-hold
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, shoulder-season, two-week-exhaustion, weekly-reversal, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
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
magic: 414010000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-10 completed packages per full year after two-week agreement; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; eligible months 4,5,9,10; two immediately completed adjacent weeks; 3-5 sessions each; strict same-sign log returns; contrarian side; 24 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify a shoulder-season two-week XNG exhaustion fade distinct from the incumbent RSI pullback, one-week fade, and summer continuation. Verify exact week membership, strict agreement, inverse side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, shoulder_month_gate, normalized_week_clock, two_completed_week_membership, strict_same_sign_agreement, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus complete-read peer-reviewed parent context with disclosed translation risk; R2 exact mechanical two-week shoulder fade; R3 registered XNGUSD.DWX D1; R4 deterministic non-ML; expected fuzzy neighbors manually resolved."
---

# QM5_41401 XNG Shoulder-Season Two-Week Exhaustion Fade

## Hypothesis

Natural gas has recurring spring and autumn shoulder periods between winter
heating and summer electric-generation demand. Two consecutive same-direction
weeks inside those lower-demand transition regimes may represent a temporarily
extended move that partially reverses over the following week. This is an
untested price-only translation, not an EIA trading result or a decorrelation
claim.

## Source Traceability And Non-Duplicate Decision

The single source of record is
`strategy-seeds/sources/EIA-MOP-XNG-SHOULDER-W2FADE-20260909/source.md`.
Its governed parents preserve complete reads of official EIA seasonal context
and Moskowitz, Ooi, and Pedersen (2012). Neither parent tests this exact fade.

The pre-allocation receipt found no exact identity and two expected fuzzy
neighbors while reporting the Strategy Wiki root unavailable. `QM5_41392`
fades one week without two-week exhaustion confirmation. `QM5_41396` requires
two-week agreement but follows it only in June-August. `QM5_12567` is a
long-only cumulative-RSI pullback with a slow trend filter. This card fixes a
four-month shoulder gate, two adjacent same-sign weekly packages, inverse
direction, and a one-week lifecycle together.

## Rules

### Entry

1. Run only on the setfile-bound `XNGUSD.DWX` D1 host with EA 41401, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is April, May, September, or
   October and the entry is within 180 elapsed session minutes.
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
authoritative. No target, intrawweek signal flip, trail, break-even, partial
close, scale-in, pyramid, grid, martingale, or discretionary exit is allowed.

### No-Trade And Framework Inputs

Fail closed on wrong host/period/identity/slot/risk mode, unlocked strategy
configuration, late restart, consumed week, ineligible month, bad packages,
nonagreement, spread, quote, ATR, stop, sizing, or order state. Framework RNG,
news, and Friday-close inputs remain configurable and are never equality-pinned
by the EA. Stress rejection is checked only for finiteness and inclusive
`0..1` range.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XNGUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 24 |
| `strategy_shoulder_month_1..4` | 4 / 5 / 9 / 10 |
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
`PORTFOLIO_WEIGHT=1`. Natural-gas gaps, roll/basis/financing, label sensitivity,
two-week sparsity, hard-stop slippage, and overlap with the incumbent XNG sleeve
can dominate. Q02 owns activity/economics; unchanged Q09 alone owns realized
portfolio correlation.

## Data Requirements

Native configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol
properties, positions, deal history, and terminal-global attempt state only.
No storage, weather, curve, volume, open interest, file, API, trained output,
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
| week clock, shoulder gate, packages, agreement, inverse side, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all four eligible months, ineligible boundaries, positive and
negative agreement, inverse direction, mixed/zero flat states, three-to-five
session weeks, adjacency, current-week exclusion, attempt persistence, frozen
stop, next-week exit, card lint, magic resolver, PACER audit, reference tests,
and strict compile/build checks. Q02 retires on zero positions, fewer than five
completed positions in any full scored year, nonpositive governed economics,
or any contract mismatch. No weak result may be rescued by tuning.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build/Q01, one
fixed-risk backtest set, and one paced Q02 enqueue below the CPU ceiling.
Forbidden: manual backtests, optimization, portfolio-gate edits or admission,
correlation waivers, deploy/live manifests, `T_Live`, AutoTrading, terminal
control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-09 | APPROVED | G0 decision above |
| Q01 Build Validation | - | NOT_BUILT | pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 and CPU ceiling |
