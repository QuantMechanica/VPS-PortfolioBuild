---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-XNG-SHOULDER-W2AGREE-20260910_S01
variant_id: EIA-MOP-XNG-SHOULDER-W2AGREE-20260910_S01
source_id: EIA-MOP-XNG-SHOULDER-W2AGREE-20260910
ea_id: QM5_41420
slug: xng-shoulder-w2agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41420_xng-shoulder-w2agree_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41420_xng_shoulder_two_week_agreement_g0.md
source_approval: decisions/2026-09-10_xng_shoulder_two_week_agreement_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "EIA natural-gas shoulder-demand context; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_government_and_peer_reviewed_bounded_mechanization
    citation: "EIA natural-gas seasonal-demand context plus Moskowitz-Ooi-Pedersen own-return commodity momentum; QuantMechanica governed shoulder two-week continuation translation."
    location: strategy-seeds/sources/EIA-MOP-XNG-SHOULDER-W2AGREE-20260910/source.md
    quality_tier: A_lineages_with_cross_source_and_horizon_translation_risk
    role: shoulder_regime_context_and_directional_momentum_lineage
strategy_mechanic: normalized-weekly-xng-two-adjacent-completed-week-open-to-close-log-returns-strict-same-sign-continuation-only-april-may-september-october-one-week-hold
sources: ["[[sources/EIA-MOP-XNG-SHOULDER-W2AGREE-20260910]]"]
concepts: ["[[concepts/time-series-momentum]]", "[[concepts/natural-gas-shoulder-season]]", "[[concepts/two-week-sign-agreement]]"]
indicators: ["[[indicators/completed-week-open-close]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, shoulder-season, two-week-agreement, weekly-momentum, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
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
magic: 414200000
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-10 completed packages per full post-warm-up year after strict two-week sign agreement; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; eligible months 4,5,9,10; two immediately completed adjacent weeks; 3-5 sessions each; strict same-sign log returns; continuation side; 24 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
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
review_focus: "Falsify an XNG shoulder-season two-week continuation distinct from the incumbent RSI pullback, same-state shoulder fade, and disjoint summer/winter continuations. Verify exact week membership, strict agreement, same-sign side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xng_carrier, shoulder_month_gate, normalized_week_clock, two_completed_week_membership, strict_same_sign_agreement, continuation_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus complete-read peer-reviewed MOP context with disclosed translation risk; R2 exact mechanical two-week shoulder continuation; R3 registered XNGUSD.DWX D1; R4 deterministic non-ML; exact/fuzzy dedup CLEAN and expected family neighbors manually resolved."
---

# QM5_41420 XNG Shoulder-Season Two-Week Agreement Continuation

## Hypothesis

Natural gas has recurring spring and autumn shoulder periods between winter
heating and summer electric-generation demand. Within those transition
regimes, two consecutive same-direction completed weeks may identify a move
that persists for one further week. This exact price-only conjunction is
unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/EIA-MOP-XNG-SHOULDER-W2AGREE-20260910/source.md`.
EIA supports only the shoulder-demand context; MOP supports own-return
commodity momentum at longer horizons. Neither establishes this weekly XNG
CFD result.

The canonical checker returned `CLEAN`. Manual review separates `QM5_41401`,
which fades the identical state; `QM5_41396` and `QM5_41402`, which follow it
only in disjoint summer and winter regimes; and `QM5_12567`, which uses
cumulative RSI and a slow trend filter. Calendar, two-week sign state,
continuation side, and one-week lifecycle are jointly load-bearing.

## Rules

### Entry

1. Run only on the setfile-bound `XNGUSD.DWX` D1 host with EA 41420, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is April, May, September, or
   October and entry is within 180 elapsed session minutes.
4. Reconstruct exactly the two immediately completed adjacent normalized
   weeks; each must contain three through five valid, unique D1 sessions.
5. Compute `r = ln(final_close / first_open)` for each completed week.
6. If both returns are strictly positive, buy. If both are strictly negative,
   sell. Mixed signs, exact zero, malformed data, or nonfinite arithmetic stays
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
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, sample, agreement, direction, carrier, stop, hold,
spread, or retry contract requires a new identity.

## Risk And Data

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Runtime uses configured-symbol D1 OHLC/timestamps,
broker clock, quotes, symbol properties, positions, deal history, and
terminal-global attempt state only. No storage, weather, curve, volume, open
interest, file, API, trained output, optimizer result, or portfolio state is
read at runtime.

Natural-gas gaps, roll/basis/financing, label sensitivity, two-week sparsity,
hard-stop slippage, seasonal instability, source translation, and overlap
with other XNG sleeves can dominate. Q02 owns activity/economics; unchanged
Q09 alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk mode, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, shoulder gate, packages, agreement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Validation And Kill Conditions

Q01 must verify all four eligible months, ineligible boundaries, positive and
negative agreement, same-sign direction, mixed/zero flat states,
three-to-five-session weeks, adjacency, current-week exclusion, attempt
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
| Q01 Build Validation | - | NOT_BUILT | pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 and CPU ceiling |
