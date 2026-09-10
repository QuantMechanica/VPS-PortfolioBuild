---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910_S01
variant_id: EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910_S01
source_id: EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910
ea_id: QM5_41422
slug: wti-refrestart-posweek-cont
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41422_wti-refrestart-posweek-cont_card.md
execution_contract_status: APPROVED
created: 2026-09-10
created_by: Research+Development
last_updated: 2026-09-10
g0_status: APPROVED
g0_decision: decisions/2026-09-10_qm5_41422_wti_refinery_restart_positive_week_continuation_g0.md
source_approval: decisions/2026-09-10_wti_refinery_restart_positive_week_continuation_source_approval.md
source_author: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_authors: "U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex"
source_citation: "EIA refinery-outage and pre-summer utilization context; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_government_and_peer_reviewed_bounded_mechanization
    citation: "EIA refinery-maintenance/restart seasonality plus Moskowitz-Ooi-Pedersen own-return commodity momentum; QuantMechanica governed positive-week WTI translation."
    location: strategy-seeds/sources/EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910/source.md
    quality_tier: A_lineages_with_cross_source_and_horizon_translation_risk
    role: post_maintenance_utilization_context_and_directional_momentum_lineage
strategy_mechanic: normalized-weekly-wti-one-immediately-completed-week-open-to-close-strict-positive-log-return-long-continuation-only-april-may-one-week-hold
sources: ["[[sources/EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910]]"]
concepts: ["[[concepts/time-series-momentum]]", "[[concepts/refinery-utilization-ramp]]", "[[concepts/positive-week-continuation]]"]
indicators: ["[[indicators/completed-week-open-close]]", "[[indicators/log-return-sign]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, energy, crude-oil, structural-seasonality, refinery-restart, positive-week, weekly-momentum, long-only, atr-hard-stop, time-stop, low-frequency]
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
magic: 414220000
period: D1
timeframe: D1
direction: long_only
expected_trade_frequency: "Approximately 4-7 completed positions per full post-warm-up year after the positive-week gate; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; Monday anchor; eligible months 4,5; one immediately completed week with 3-5 sessions; strictly positive open-to-close log return; long-only continuation; 16 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify a long-only WTI post-maintenance positive-week continuation distinct from maintenance-season negative-week continuation, May-July daily compression breakout/pullback, unconditional weekly momentum, and XNG shoulder rules. Verify exact week membership, positive-only side, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, refinery_restart_month_gate, normalized_week_clock, immediately_completed_week_membership, strict_positive_sign, long_only_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 official EIA plus complete-read peer-reviewed MOP context with disclosed translation risk; R2 exact mechanical long-only positive-week post-maintenance continuation; R3 registered XTIUSD.DWX D1; R4 deterministic non-ML; no exact duplicate and three fuzzy family neighbors manually resolved."
---

# QM5_41422 WTI Refinery-Restart Positive-Week Continuation

## Hypothesis

Planned refinery maintenance generally peaks in late February and March before
utilization rises heading into summer. In April and May, a completed positive
WTI week may identify demand recovery that persists for one further week. This
exact long-only price translation is unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/EIA-MOP-WTI-REFRESTART-POSWEEK-CONT-20260910/source.md`.
EIA supports only the post-maintenance utilization calendar context; MOP
supports own-return commodity momentum at broader horizons. Neither
establishes this weekly WTI CFD result.

The canonical checker found no exact identity and surfaced three fuzzy family
neighbors. `QM5_41392` is an XNG contrarian shoulder rule; `QM5_41420` is an
XNG two-week agreement rule; `QM5_41421` trades WTI but shorts negative weeks
during February-March/September-October maintenance. `QM5_12763` and
`QM5_12869` require daily compression/breakout or pullback/rebound states in
May-July. Calendar, one-week formation, positive-only gate, long side, and
one-week lifecycle are jointly load-bearing.

## Rules

The numbered execution sections below are the locked mechanical contract.

## 4. Entry Rules

1. Run only on the setfile-bound `XTIUSD.DWX` D1 host with EA 41422, slot zero,
   registered magic, and fixed-risk backtest mode.
2. On the first tradable D1 bar of a genuine normalized Monday-anchored week,
   persist the week attempt before calendar, history, signal, news, spread,
   quote, ATR, sizing, or order gates. Never retry that week.
3. Continue only when the Monday anchor month is April or May and entry is
   within 180 elapsed session minutes.
4. Reconstruct exactly the immediately completed normalized week; it must
   contain three through five valid, unique D1 sessions.
5. Compute `r = ln(final_close / first_open)`.
6. If `r > 0`, buy. Negative, exact zero, malformed, stale, or nonfinite
   history stays flat and consumes the week. Never sell.
7. Require spread in `[0,1500]`, executable quotes, completed ATR(20,D1), valid
   symbol metadata, and one normalized frozen `3.5*ATR` hard stop.

## 5. Exit Rules

Close on the first processed tick in the next normalized broker week. Ten
elapsed days is stale repair. The broker stop and framework kill switch are
authoritative. There is no target or intraweek signal-flip exit.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked strategy
configuration, late restart, consumed week, ineligible month, bad package,
nonpositive return, spread, quote, ATR, stop, sizing, or order state.
Framework RNG, news, and Friday-close inputs remain configurable and are never
equality-pinned by the EA. Stress rejection is checked only for finiteness and
inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten duplicate, wrong-symbol, wrong-magic, non-long,
missing-stop, take-profit-bearing, future-dated, or invalid-volume owned
exposure. No trail, break-even, partial close, scale-in, pyramid, grid,
martingale, or discretionary exit is allowed.

## Locked Q02 Baseline

Q02 has one locked baseline and no optimization surface:

| Input | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` via setfile |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 16 |
| `strategy_restart_month_1..2` | 4 / 5 |
| `strategy_required_weeks` | 1 |
| `strategy_min_week_bars` / `strategy_max_week_bars` | 3 / 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` / `strategy_atr_sl_mult` | 20 / 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

Changing the calendar, sample, sign, direction, carrier, stop, hold, spread,
or retry contract requires a new identity.

## Source-Defined Rules

- EIA supports a broad post-maintenance transition toward higher pre-summer
  refinery utilization, not the exact April-May rule or its direction.
- Moskowitz-Ooi-Pedersen supports own-return commodity momentum at materially
  broader horizons, not this weekly continuous-CFD implementation.

## QM Interpretations

- April and May Monday anchors translate the broad refinery-restart regime
  into an exact, testable calendar.
- One strictly positive completed week, a long-only continuation, the one-week
  hold, retry semantics, and all numeric thresholds are QM choices.

## Framework Execution Overrides

- Q02 keeps news temporal/compliance modes off and Friday close disabled so
  the strategy-owned normalized-week exit is measured intact.
- Those framework inputs and the RNG seed remain configurable and are not
  equality-pinned. Stress rejection receives range/finiteness validation only.

## Exit Precedence

1. framework kill switch and broker hard stop;
2. malformed or non-long owned-exposure repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale-state repair.

## Runtime Data Dependencies

Runtime uses configured-symbol D1 OHLC/timestamps, broker clock, quotes,
symbol properties, positions, deal history, and terminal-global attempt state
only. No refinery, inventory, curve, volume, open-interest, file, API, trained
output, optimizer result, or portfolio state is read at runtime.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

WTI gaps, roll/basis/financing, label sensitivity, sparse seasonal samples,
hard-stop slippage, regime instability, source translation, and overlap with
other WTI sleeves can dominate. Q02 owns activity/economics; unchanged Q09
alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk mode, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, restart gate, package, positive sign, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stop | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify both eligible months, ineligible boundaries, positive long
entry, negative/zero flat states, three-to-five-session weeks, current-week
exclusion, attempt persistence, frozen stop, next-week exit, card lint, magic
resolver, PACER audit, reference tests, and strict compile/build checks. Q02
retires on zero positions, fewer than five completed positions in any full
scored year, nonpositive governed economics, or any contract mismatch. No weak
result may be rescued by tuning; a material rule change requires a new
identity and G0 review. Q09 alone may establish realized portfolio
diversification.

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
| Q01 Build Validation | 2026-09-10 | PASS | governed compile `12e67cc1-25b0-4007-a132-6b6febebdefd`; 12 reference tests; PACER audit clean |
| Q02 Baseline Screening | 2026-09-10 | NOT_ENQUEUED_CPU_CEILING | eligible dry run; CPU sample max 98.34% exceeded exclusive 97% ceiling |
