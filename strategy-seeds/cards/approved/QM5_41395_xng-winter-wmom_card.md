---
card_schema_version: 2
type: strategy
strategy_id: EIA-MOP-XNG-WINTER-WMOM-2026_S01
variant_id: EIA-MOP-XNG-WINTER-WMOM-2026_S01
source_id: EIA-MOP-XNG-WINTER-WMOM-2026
ea_id: QM5_41395
slug: xng-winter-wmom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41395_xng-winter-wmom_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41395_xng_winter_weekly_momentum_g0.md
source_approval: decisions/2026-09-09_xng_winter_weekly_momentum_source_approval.md
source_author: U.S. Energy Information Administration; Moskowitz, Ooi and Pedersen
source_authors: U.S. Energy Information Administration; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; OpenAI Codex
source_citation: "EIA natural-gas seasonality context; Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104, 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_government_and_peer_reviewed_bounded_mechanization
    citation: "EIA natural-gas seasonal-demand context plus Moskowitz-Ooi-Pedersen own-return commodity momentum; QuantMechanica governed winter-week translation."
    location: strategy-seeds/sources/EIA-MOP-XNG-WINTER-WMOM-2026/source.md
    quality_tier: A_lineages_with_cross_source_and_horizon_translation_risk
    role: winter_regime_context_and_directional_momentum_lineage
strategy_mechanic: normalized-weekly-xng-immediately-completed-week-open-to-close-log-return-sign-continuation-only-november-december-january-february-march-one-week-hold
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, winter-demand, weekly-momentum, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 413950000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 20-22 winter weekly packages per full year before invalid/zero-return gates; Q02 must prove at least five completed trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 21
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED_BUILD_PENDING
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED
parameters_to_test: "Locked Q02 baseline only: D1; normalized Monday week anchor; eligible months 11,12,1,2,3; one immediately completed adjacent week; 3-5 sessions; ln(final close/first open); exact-zero epsilon; continuation side; 16 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify a winter-only XNG prior-week continuation distinct from the incumbent RSI pullback and shoulder reversal. Verify anchor-month eligibility, completed-week membership, continuation orientation, durable attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, winter_month_gate, normalized_week_clock, completed_week_membership, continuation_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-09 and durable source/G0 decisions: R1-R4 pass with conjunction, horizon-translation, and CFD risks disclosed. Canonical repository dedup raised only the expected shoulder-week fuzzy neighbor; the Wiki root was unavailable and manual review separates winter continuation from shoulder reversal and RSI pullback."
---

# QM5_41395 XNG Winter-Demand Weekly Momentum

## Hypothesis

Natural gas has recurring winter heating demand. During November-through-March
weeks, the immediately completed week's direction may persist for one further
week more often than it reverses. This exact price-only seasonal conjunction is
unproven and belongs to Q02 onward.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/EIA-MOP-XNG-WINTER-WMOM-2026/source.md`. EIA supports
only the winter-demand context; MOP supports own-return commodity momentum at
monthly horizons. Neither establishes this weekly XNG CFD result.

The canonical checker raised only `QM5_41392` as a fuzzy family neighbor and
could not read the configured Wiki root. Manual review separates that
April/May/September/October contrarian rule from this
November/December/January/February/March continuation. `QM5_12567` instead
uses cumulative RSI and a slow trend filter.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XNGUSD.DWX`; D1 only.
- Decision: first tradable D1 bar of each normalized Monday-anchored week.
- Eligible anchor months: November, December, January, February, and March.
- History: exactly the immediately prior adjacent normalized broker week,
  containing three through five valid D1 sessions.
- Formula: `r = ln(final_close / first_open)`.
- Direction: `r > 0` buys; `r < 0` sells; exact zero or invalid state is flat.
- Lifecycle: close at the next normalized week; ten elapsed days is stale repair.

## Rules

### 4. Entry Rules

Repair malformed or stale owned exposure first. Require configured symbol, D1,
EA 41395, slot zero, fixed-risk mode, a genuine new-week transition, and a
winter anchor month. Persist the weekly attempt before fallible gates. Use only
the immediately completed adjacent three-to-five-session week. Follow its
strict log-return sign. Require spread no greater than 1,500 points and
completed ATR(20,D1). Open at most one fixed-risk position with a frozen
`3.5*ATR` stop and no target.

### 5. Exit Rules

Close at the first processed tick in a later normalized broker week. Broker
hard stop and framework kill switch remain authoritative; ten elapsed days is
stale repair. No signal flip, target, trail, break-even, partial close,
scale-in, pyramid, grid, martingale, or discretionary exit.

### 6. Filters (No-Trade Module)

Fail closed for wrong symbol/period/ID/slot/risk mode, invalid strategy inputs,
consumed week, owned position, prior same-week deal, late restart, ineligible
anchor month, malformed/nonadjacent completed week, current-week leakage,
nonfinite return, exact zero, excess spread, or invalid quote/ATR/stop. News
and Friday inputs remain framework-governed and are not pinned.

### 7. Trade Management Rules

Maintain at most one owned XNG position and one durable attempt per normalized
week. Flatten duplicate, wrong-symbol, wrong-magic, invalid-side, stopless,
take-profit-bearing, future-dated, or stale exposure. Close a valid package at
the next week boundary before considering replacement.

## Parameters To Test

No optimization surface is approved. Locked baseline: `strategy_symbol` from
the setfile; label offset 86400; grace 180 minutes; history 16 D1 bars; winter
months 11, 12, 1, 2, 3; one required week; three-to-five sessions; return
epsilon zero; ATR period 20; stop multiple 3.5; maximum hold ten days; maximum
spread 1,500 points.

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker calendar, symbol metadata, executable quotes,
completed ATR, framework position/deal history, and terminal-global attempt
state only. No EIA/storage/weather/futures-curve feed, file, API, volume,
optimizer output, trained artifact, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
Principal risks are natural-gas gaps, futures/CFD basis and roll, financing,
week-label sensitivity, hard-stop slippage, seasonal instability, source
translation, and overlap with other XNG sleeves.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK | Official EIA context plus complete-read peer-reviewed MOP lineage; exact conjunction untested. |
| R2 | PASS | Calendar, weekly package, sign, side, attempt, stop, and rollover fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XNGUSD.DWX` D1 history. |
| R4 | PASS | Deterministic native arithmetic without trained or prohibited logic. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong calendar
eligibility, wrong weekly endpoints, current-week leakage, repeated/skipped
attempt, missing stop, wrong exit, or nondeterminism. Changing months,
formation, direction, carrier, stop, risk, spread, or retry policy requires a
new identity and Q00/Q01.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| identity, risk, stress range, and strategy inputs | No-Trade | `Strategy_NoTradeFilter` |
| week clock, winter gate, package, return, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and bounded helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping | Trade Close | `Strategy_ExitSignal` |
| framework-governed news and Friday inputs | No-Trade | framework hooks, never locked by strategy guard |

## Validation And Kill Conditions

Q01 must verify eligible/ineligible anchors, positive/negative/zero returns,
continuation reflection, three-to-five-session packages, adjacency,
current-week exclusion, attempt persistence, next-week closure, frozen stop,
card lint, resolver, PACER audit, and strict compile/build checks. Q02 owns
activity/economics. Q09 alone may establish decorrelation.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build, Q01, and one
paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests,
optimization, portfolio-gate edits, correlation waivers, admission, deploy or
live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | `decisions/2026-09-09_xng_winter_weekly_momentum_source_approval.md` |
| G0 Research Intake | 2026-09-09 | APPROVED | `decisions/2026-09-09_qm5_41395_xng_winter_weekly_momentum_g0.md` |
| Q01 Build Validation | - | NOT_STARTED | pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 and CPU ceiling |

