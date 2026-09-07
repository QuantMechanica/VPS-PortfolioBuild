---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_K6H2_S33
variant_id: MOP-TSMOM-2012_XTI_K6H2_S33
source_id: MOP-WTI-TSMOM6-H2-2026
ea_id: QM5_41382
slug: wti-tsmom6-h2
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41382_wti-tsmom6-h2_card.md
execution_contract_status: APPROVED
created: 2026-09-07
created_by: Research+Development
last_updated: 2026-09-07
g0_status: APPROVED
g0_decision: decisions/2026-09-07_qm5_41382_wti_tsmom6_h2_g0.md
source_approval: decisions/2026-09-07_wti_six_month_momentum_two_month_hold_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read parent strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-TSMOM6-H2-2026/source.md"
    quality_tier: A
    role: primary_own_return_formation_holding_family_and_wti_membership
strategy_mechanic: bimonthly-wti-sign-of-exact-six-completed-broker-month-log-return-two-month-hold-odd-month-epoch
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, time-series-momentum, six-month-return, two-month-hold, symmetric-long-short, atr-hard-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413820000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately six non-overlapping WTI packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01_BUILD
q01_status: PENDING
q02_status: NOT_ENQUEUED
parameters_to_test: "Locked Q02 baseline only: D1; seven consecutive completed month-end closes; exact six-month log-return sign; odd-month decisions; two-month hold; 300 D1 bars; 3.5*ATR(20,D1) frozen stop; 70-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify the source-bounded WTI k=6,h=2 stream. Verify seven exact completed-month endpoints, odd-month-only attempts, no even-month rollover, fixed risk, frozen stop, and next-odd-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [exact_symbol_period, completed_month_reconstruction, exact_six_month_orientation, odd_month_epoch, bimonthly_attempt_state, two_month_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
---

# QM5_41382 WTI Six-Month Momentum / Two-Month Hold

## Hypothesis

A six-completed-month WTI own-return direction may persist when held as a
fixed non-overlapping two-month package, reducing monthly renewal sensitivity.
This is a pre-result structural test. The peer-reviewed source defines the
time-series-momentum formation/holding family and includes WTI, but does not
publish a standalone WTI `k=6, h=2` result or continuous-CFD evidence.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-TSMOM6-H2-2026/source.md`; its complete-read
parent is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The published
paper hash is
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The checker found no exact identity and expected family matches only.
`QM5_20059` uses the same six-month return with monthly renewal;
`QM5_20281` uses the same two-month clock with a twelve-month return, while
`QM5_41379`, `QM5_41380`, and `QM5_41381` use three-, one-, and nine-month
returns. This card
requires both exact `k=6` endpoints and the fixed odd-month `h=2` lifecycle.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XTIUSD.DWX`; D1 only.
- Decision: first processed D1 bar of January, March, May, July, September, or November.
- History: seven consecutive completed broker-month-end closes `C[0]..C[6]`,
  oldest to newest; newest is the immediately prior completed month.
- Formula: `r6 = ln(C[6] / C[0])`; positive buys, negative sells, equality or invalid state stays flat.
- Lifecycle: close and reconsider only at the next eligible odd-month edge; 70 elapsed days is stale repair.

## Rules

### Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require configured symbol, D1, EA 41382, slot 0, and fixed-risk backtest mode.
3. At a genuine odd-month transition, persist the month attempt before history,
   signal, spread, quote, ATR, sizing, news, or order gates.
4. Reconstruct exactly seven positive finite consecutive completed month-end
   closes with strictly increasing timestamps and no current-month price.
5. Compute `ln(C[6]/C[0])`; buy strict positive and sell strict negative.
6. Require spread from 0 through 1,500 points and completed ATR(20,D1). Open at
   most one fixed-risk position with a frozen `3.5*ATR` stop and no target.

### Exit Rules

Close the prior package at the first processed D1 bar of the next eligible odd
month before any replacement. Do nothing at even-month transitions. Broker
hard stop and framework kill switch remain authoritative; 70 days is stale
repair. No target, signal flip, trail, break-even, partial close, Friday
flatten, scale-in, pyramid, grid, martingale, or discretionary exit.

### Filters

Fail closed for wrong symbol/period/ID/slot/risk mode, invalid strategy inputs,
ineligible month, consumed attempt, owned position, prior deal, malformed or
nonconsecutive endpoints, current-month leakage, nonfinite return, equality,
excess spread, invalid quote/ATR/stop, or failed persistence. News and Friday
inputs remain framework-governed and are not pinned by the strategy guard.

### Trade Management

Maintain at most one owned WTI position and one durable attempt per eligible
odd month. Flatten duplicate, wrong-symbol, wrong-magic, wrong-side,
missing-stop, take-profit-bearing, future-dated, or stale exposure. Preserve a
valid package through the intervening even month and close it at the next odd
month boundary.

## Parameters To Test

No optimization surface is approved. The locked Q02 baseline is:

| Parameter | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_return_months` | 6 |
| `strategy_hold_months` | 2 |
| `strategy_rebalance_month_parity` | 1 |
| `strategy_history_bars_d1` | 300 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 70 |
| `strategy_max_spread_points` | 1500 |

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker calendar time, symbol metadata, executable
quotes, completed ATR, framework position/deal history, and terminal-global
attempt state only. No futures chain, inventory, curve, volume, open interest,
file, API, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
Principal risks are futures/CFD roll and basis, financing, WTI gaps, fixed
phase sensitivity, slow reversal response, hard-stop slippage, weak
carrier-specific evidence, and portfolio correlation.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN | Peer-reviewed complete-read JFE source defines the family and includes WTI; no standalone result is imported. |
| R2 | PASS | Endpoints, formula, clock, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Native registered XTIUSD.DWX D1 history supplies runtime inputs. |
| R4 | PASS | Deterministic native arithmetic without trained or prohibited logic. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong endpoints,
month leakage, even-month action, repeated attempt, missing stop, wrong exit,
or nondeterminism. Changing formation, hold, phase, direction, carrier, stop,
risk, spread, or retry policy requires a new identity and Q00/Q01.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact period, odd-month clock, endpoints, return, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-odd-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| no independent signal close | Trade Close | `Strategy_ExitSignal` returns false |
| kill switch, ownership, magic, fixed risk | Framework No-Trade | standard orchestration |

## Validation Plan

Q01 must prove month adjacency and year boundaries, exact seven endpoints,
positive/negative/equality states, no current-month leakage, odd-month-only
attempts, even-month preservation, persistent attempts, fixed-risk stops,
next-odd-month/stale repair, card lint, resolver identity, PACER pin audit, and
governed strict compile. Q02 alone measures density and economics; Q09 alone
establishes realized correlation.

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
fixed-risk backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It excludes manual backtests, terminal control,
live/demo/shadow/stress/optimization presets, AutoTrading, `T_Live`, deploy or
live manifests, portfolio-gate changes, admission, and correlation waivers.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-07 | APPROVED | `decisions/2026-09-07_qm5_41382_wti_tsmom6_h2_g0.md` |
| Q01 Build Validation | 2026-09-07 | PENDING | Build not yet compiled. |
| Q02 Baseline Screening | 2026-09-07 | NOT_ENQUEUED | Requires Q01 PASS and fresh CPU admission. |
