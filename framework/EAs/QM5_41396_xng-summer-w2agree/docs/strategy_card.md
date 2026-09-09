---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-XNG-SUMMER-W2AGREE-2026_S01
variant_id: EIA-MOP-XNG-SUMMER-W2AGREE-2026_S01
source_id: EIA-MOP-XNG-SUMMER-W2AGREE-2026
ea_id: QM5_41396
slug: xng-summer-w2agree
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41396_xng-summer-w2agree_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41396_xng_summer_two_week_agreement_g0.md
source_approval: decisions/2026-09-09_xng_summer_two_week_agreement_source_approval.md
source_author: U.S. Energy Information Administration; Moskowitz, Ooi and Pedersen
source_authors: U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex
source_citation: "EIA natural-gas summer-demand context; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104, 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_government_and_peer_reviewed_bounded_mechanization
    citation: "EIA natural-gas seasonal-demand context plus Moskowitz-Ooi-Pedersen own-return commodity momentum; QuantMechanica governed summer two-week agreement translation."
    location: strategy-seeds/sources/EIA-MOP-XNG-SUMMER-W2AGREE-2026/source.md
    quality_tier: A_lineages_with_cross_source_and_horizon_translation_risk
    role: summer_regime_context_and_directional_momentum_lineage
strategy_mechanic: normalized-weekly-xng-two-adjacent-completed-week-open-to-close-log-returns-strict-same-sign-continuation-only-june-july-august-one-week-hold
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, summer-demand, two-week-agreement, weekly-momentum, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 413960000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 6-12 summer weekly packages per full year after strict two-week sign agreement; Q02 must prove at least four completed trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 9
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02_ZERO_TRADES
q01_status: PASS
q02_status: ZERO_TRADES
parameters_to_test: "Locked Q02 baseline only: D1; normalized Monday week anchor; eligible months 6,7,8; two immediately completed adjacent weeks; 3-5 sessions each; ln(final close/first open); strict same-sign agreement; exact-zero epsilon; continuation side; 24 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify a summer-only XNG two-week agreement continuation distinct from the incumbent RSI pullback and one-week seasonal sleeves. Verify anchor-month eligibility, exact adjacent completed-week membership, strict agreement, continuation orientation, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, summer_month_gate, normalized_week_clock, two_adjacent_completed_weeks, strict_same_sign_agreement, continuation_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 governed EIA plus complete-read peer-reviewed MOP child lineage with translation risk; R2 exact summer two-week sign-agreement mechanic; R3 registered native XNG D1; R4 deterministic native arithmetic without ML or banned signals; fuzzy seasonal neighbors manually separated by two-week agreement "
---

# QM5_41396 XNG Summer Two-Week Agreement Momentum

## Hypothesis

Natural gas has recurring summer electric-generation demand. During June
through August, directional persistence across two adjacent completed weeks may
identify a sustained demand-driven move that continues for one further week.
This exact price-only seasonal conjunction is unproven and belongs to Q02
onward.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/EIA-MOP-XNG-SUMMER-W2AGREE-2026/source.md`. EIA
supports only the summer-demand context; MOP supports own-return commodity
momentum at monthly horizons. Neither establishes this weekly XNG CFD result.

The canonical checker raised only the expected `QM5_41392` and `QM5_41395`
fuzzy family neighbors. Manual review separates the shoulder one-week fade and
winter unconditional one-week continuation from this summer two-adjacent-week
strict-agreement rule. `QM5_12567` instead uses cumulative RSI and a slow trend
filter. Existing XNG weekly agreement systems use price-flow components,
return acceleration, range migration, close location, or event-week endpoints;
none owns this exact seasonal two-week sign state.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XNGUSD.DWX`; D1 only.
- Decision: first tradable D1 bar of each normalized Monday-anchored week.
- Eligible anchor months: June, July, and August only.
- History: exactly the two immediately prior adjacent normalized broker weeks,
  each containing three through five valid D1 sessions.
- Formula for each week: `r = ln(final_close / first_open)`.
- Direction: both `r > 0` buys; both `r < 0` sells; disagreement, exact zero,
  or invalid state is flat.
- Lifecycle: close at the next normalized week; ten elapsed days is stale
  repair.

## Rules

### 4. Entry Rules

Repair malformed or stale owned exposure first. Require configured symbol, D1,
EA 41396, slot zero, fixed-risk mode, a genuine new-week transition, and a
summer anchor month. Persist the weekly attempt before fallible gates. Use only
the two immediately completed adjacent three-to-five-session weeks. Follow the
shared strict sign only when both agree. Require spread no greater than 1,500
points and completed ATR(20,D1). Open at most one fixed-risk position with a
frozen `3.5*ATR` stop and no target.

### 5. Exit Rules

Close at the first processed tick in a later normalized broker week. Broker
hard stop and framework kill switch remain authoritative; ten elapsed days is
stale repair. No signal flip, target, trail, break-even, partial close,
scale-in, pyramid, grid, martingale, or discretionary exit.

### 6. Filters (No-Trade Module)

Fail closed for wrong symbol/period/ID/slot/risk mode, invalid strategy inputs,
consumed week, owned position, prior same-week deal, late restart, ineligible
anchor month, malformed/nonadjacent completed weeks, current-week leakage,
nonfinite return, disagreement, exact zero, excess spread, or invalid
quote/ATR/stop. News and Friday inputs remain framework-governed and are not
pinned.

### 7. Trade Management Rules

Maintain at most one owned XNG position and one durable attempt per normalized
week. Flatten duplicate, wrong-symbol, wrong-magic, invalid-side, stopless,
take-profit-bearing, future-dated, or stale exposure. Close a valid package at
the next week boundary before considering replacement.

## Parameters To Test

No optimization surface is approved. Locked baseline: `strategy_symbol` from
the setfile; label offset 86400; grace 180 minutes; history 24 D1 bars; summer
months 6, 7, and 8; two required weeks; three-to-five sessions per week;
return epsilon zero; ATR period 20; stop multiple 3.5; maximum hold ten days;
maximum spread 1,500 points.

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker calendar, symbol metadata, executable quotes,
completed ATR, framework position/deal history, and terminal-global attempt
state only. No EIA/storage/weather/power-load/futures-curve feed, file, API,
volume, optimizer output, trained artifact, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
Principal risks are natural-gas gaps, futures/CFD basis and roll, financing,
week-label sensitivity, hard-stop slippage, seasonal instability, source
translation, and overlap with other XNG sleeves.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK | One governed child packet preserves official EIA context and complete-read peer-reviewed MOP lineage; exact conjunction untested. |
| R2 | PASS | Calendar, two weekly packages, sign agreement, side, attempt, stop, and rollover fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XNGUSD.DWX` D1 history. |
| R4 | PASS | Deterministic native arithmetic without trained or prohibited logic. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than four completed trades
in any full post-warm-up year, nonpositive governed economics, wrong calendar
eligibility, wrong weekly endpoints, current-week leakage, disagreement entry,
repeated/skipped attempt, missing stop, wrong exit, or nondeterminism. Changing
months, formation, agreement, direction, carrier, stop, risk, spread, or retry
policy requires a new identity and Q00/Q01.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| identity, risk, stress range, and strategy inputs | No-Trade | `Strategy_NoTradeFilter` |
| week clock, summer gate, two packages, strict agreement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and bounded helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping | Trade Close | `Strategy_ExitSignal` |
| framework-governed news and Friday inputs | No-Trade | framework hooks, never locked by strategy guard |

## Validation And Kill Conditions

Q01 must verify eligible/ineligible anchors, positive/negative/disagreeing/zero
weekly pairs, continuation reflection, three-to-five-session packages,
adjacency, current-week exclusion, attempt persistence, next-week closure,
frozen stop, card lint, resolver, PACER audit, and strict compile/build checks.
Q02 owns activity/economics. Q09 alone may establish decorrelation.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build, Q01, and one
paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests,
optimization, portfolio-gate edits, correlation waivers, admission, deploy or
live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | `decisions/2026-09-09_xng_summer_two_week_agreement_source_approval.md` |
| G0 Research Intake | 2026-09-09 | APPROVED | `decisions/2026-09-09_qm5_41396_xng_summer_two_week_agreement_g0.md` |
| Q01 Build Validation | 2026-09-09 | PASS | strict build check and compile: `ec0c4f42-df9f-4372-a4c6-84d9dd06be79`; reference vectors: 14 PASS; PACER audit: zero findings |
| Q02 Baseline Screening | 2026-09-09 | ZERO_TRADES | fleet-dispatched canary `bd47f2f3-b8e2-461a-8a41-84a4092d0a1c`; valid bound run, not PASS or strategy rejection; recovery evidence: `docs/ops/evidence/2026-09-09_qm5_41396_zero_trades_recovery_investigation.md` |
