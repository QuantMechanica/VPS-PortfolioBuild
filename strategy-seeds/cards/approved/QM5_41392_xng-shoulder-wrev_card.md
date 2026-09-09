---
card_schema_version: 2
type: strategy
strategy_id: EIA-XNG-SHOULDER-WREV-2026_S01
variant_id: EIA-XNG-SHOULDER-WREV-2026_S01
source_id: EIA-XNG-SHOULDER-WREV-2026
ea_id: QM5_41392
slug: xng-shoulder-wrev
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41392_xng-shoulder-wrev_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41392_xng_shoulder_weekly_reversal_g0.md
source_approval: decisions/2026-09-09_xng_shoulder_weekly_reversal_source_approval.md
source_author: U.S. Energy Information Administration
source_authors: U.S. Energy Information Administration; OpenAI Codex
source_citation: "U.S. Energy Information Administration natural-gas seasonality packet; governed XNG shoulder-week reversal extraction."
source_citations:
  - type: official_government_source_bounded_mechanization
    citation: "U.S. Energy Information Administration natural-gas seasonal demand context; QuantMechanica governed completed-week reversal translation."
    location: strategy-seeds/sources/EIA-XNG-SHOULDER-WREV-2026/source.md
    quality_tier: A_context_with_translation_risk
    role: shoulder_season_context_and_exact_governed_mechanization
strategy_mechanic: normalized-weekly-xng-immediately-completed-week-open-to-close-log-return-sign-contrarian-only-april-may-september-october-one-week-hold
strategy_type_flags: [commodity, energy, natural-gas, structural-seasonality, shoulder-season, weekly-reversal, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, natural_gas]
timeframes: [D1]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: XNGUSD.DWX
symbol: XNGUSD.DWX
host_symbol: XNGUSD.DWX
symbol_slot: 0
magic: 413920000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 16-18 shoulder-season weekly packages per full year before invalid/zero-return gates; Q02 must prove at least five completed trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 17
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED_BUILD_PENDING
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED
parameters_to_test: "Locked Q02 baseline only: D1; normalized Monday week anchor; eligible months 4,5,9,10; one immediately completed adjacent week; 3-5 sessions; ln(final close/first open); exact-zero epsilon; contrarian side; 16 D1 history bars; 180-minute entry grace; 3.5*ATR(20,D1) frozen stop; 10-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify an XNG shoulder-season prior-week return fade distinct from the incumbent RSI pullback. Verify Monday-anchor month eligibility, exact completed-week membership, contrarian orientation, durable weekly attempt, fixed risk, frozen stop, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, shoulder_month_gate, normalized_week_clock, completed_week_membership, contrarian_orientation, weekly_attempt_state, one_week_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-09 and durable source/G0 decisions: R1-R4 pass with source-policy and translation risks disclosed. Canonical dedup across 4,872 registry rows, 1,485 cards, and 45 Wiki nodes returned CLEAN; manual review separates RSI, high-volatility reversal, and directional shoulder families."
---

# QM5_41392 XNG Shoulder-Season Weekly Reversal

## Hypothesis

Natural gas has recurring spring and autumn shoulder periods between winter
heating and summer power-demand peaks. In these lower-demand transition
regimes, the immediately completed week's directional move may be more prone
to reversal than continuation. This is an unproven price-only translation,
not an imported EIA trading result.

## Source Traceability And Non-Duplicate Decision

The approved bounded packet is
`strategy-seeds/sources/EIA-XNG-SHOULDER-WREV-2026/source.md`. Its local parent
preserves official EIA seasonal-demand context. Fresh generic-web retrieval
was refused by the mandatory reader and is not used as evidence.

The canonical checker returned `CLEAN`. `QM5_12567` uses cumulative RSI and a
slow trend filter. `QM5_13102` uses an all-year five-D1 return threshold plus
an elevated realized-volatility rank and neutral-return exit. Existing
shoulder sleeves are directional trend, failed-rally, or breakout strategies.
This card's exact four-month Monday-anchor gate, immediately completed week,
unconditional strict sign fade, and one-week lifecycle are jointly load-bearing.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XNGUSD.DWX`; D1 only.
- Decision: first tradable D1 bar of each normalized Monday-anchored broker week.
- Eligible anchor months: April, May, September, and October only.
- History: exactly the immediately prior adjacent normalized broker week,
  containing three through five valid D1 sessions.
- Formula: `r = ln(final_close / first_open)`.
- Direction: `r < 0` buys; `r > 0` sells; exact zero or invalid state is flat.
- Lifecycle: close at the next normalized week; ten elapsed days is stale repair.

## Rules

### 4. Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require configured symbol, D1, EA 41392, slot zero, and fixed-risk mode.
3. At a genuine new-week transition, persist the attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates.
4. Require the normalized current-week Monday anchor month to be one of
   `{4,5,9,10}`; ineligible weeks are consumed flat.
5. Reconstruct only the immediately completed adjacent three-to-five-session
   week with strictly ordered unique normalized session dates.
6. Compute `ln(final_close/first_open)` and trade its strict opposite sign.
7. Require spread from zero through 1,500 points and completed ATR(20,D1).
   Open at most one fixed-risk position with a frozen `3.5*ATR` stop and no target.

### 5. Exit Rules

Close the package at the first processed tick in a later normalized broker
week. Broker hard stop and framework kill switch remain authoritative; ten
elapsed days is stale repair. No signal flip, target, trail, break-even,
partial close, scale-in, pyramid, grid, martingale, or discretionary exit.

### 6. Filters (No-Trade Module)

Fail closed for wrong symbol/period/ID/slot/risk mode, invalid strategy
inputs, consumed week, owned position, prior same-week deal, late restart,
ineligible anchor month, malformed/nonadjacent completed week, current-week
leakage, nonfinite return, exact zero, excess spread, or invalid quote/ATR/stop.
News and Friday inputs remain framework-governed and are not pinned by the
strategy guard.

### 7. Trade Management Rules

Maintain at most one owned XNG position and one durable attempt per normalized
week. Flatten duplicate, wrong-symbol, wrong-magic, invalid-side, stopless,
take-profit-bearing, future-dated, or stale exposure. Close a valid package at
the next week boundary before considering replacement.

## Parameters To Test

No optimization surface is approved. The locked Q02 baseline is:

| Parameter | Value |
|---|---:|
| `strategy_symbol` | `XNGUSD.DWX` |
| `strategy_label_offset_seconds` | 86400 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_history_bars` | 16 |
| `strategy_spring_month_1` | 4 |
| `strategy_spring_month_2` | 5 |
| `strategy_autumn_month_1` | 9 |
| `strategy_autumn_month_2` | 10 |
| `strategy_required_weeks` | 1 |
| `strategy_min_week_bars` | 3 |
| `strategy_max_week_bars` | 5 |
| `strategy_return_epsilon` | 0 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 10 |
| `strategy_max_spread_points` | 1500 |

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker calendar, symbol metadata, executable
quotes, completed ATR, framework position/deal history, and terminal-global
attempt state only. No EIA or storage feed, weather, power load, futures curve,
file, API, volume, optimizer output, trained artifact, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. Principal risks are natural-gas gaps, futures/CFD basis
and roll, financing, week-label sensitivity, hard-stop slippage, weak
carrier-specific evidence, and overlap with the incumbent XNG sleeve.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_TRANSLATION_RISK | One governed official-source lineage; reader limitation and untested translation are explicit. |
| R2 | PASS | Calendar, weekly package, sign, side, attempt, stop, and rollover are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Registered native `XNGUSD.DWX` D1 history supplies runtime inputs. |
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
| exact period, week clock, shoulder gate, package, return, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and bounded helpers |
| malformed, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping | Trade Close | `Strategy_ExitSignal` |
| framework-governed news and Friday inputs | No-Trade | framework hooks, never locked by strategy guard |

## Validation And Kill Conditions

Q01 must verify fixtures for eligible/ineligible anchor months, positive,
negative and zero returns, contrarian reflection, three-to-five session
packages, adjacency, current-week exclusion, attempt persistence, next-week
closure, frozen stop, card lint, resolver, PACER audit, and strict compile/build
checks. Q02 owns activity/economics. Q09 alone may establish decorrelation.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build, Q01, and
one paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests,
optimization, portfolio-gate edits, correlation waivers, admission, deploy or
live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | `decisions/2026-09-09_xng_shoulder_weekly_reversal_source_approval.md` |
| G0 Research Intake | 2026-09-09 | APPROVED | `decisions/2026-09-09_qm5_41392_xng_shoulder_weekly_reversal_g0.md` |
| Q01 Build Validation | - | NOT_STARTED | pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | pending Q01 and CPU ceiling |
