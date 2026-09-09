---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_K10H1_S41
variant_id: MOP-TSMOM-2012_XTI_K10H1_S41
source_id: MOP-WTI-TSMOM10-H1-2026
ea_id: QM5_41391
slug: wti-tsmom10-h1
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41391_wti-tsmom10-h1_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41391_wti_tsmom10_h1_g0.md
source_approval: decisions/2026-09-09_wti_ten_month_momentum_one_month_hold_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read parent strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-TSMOM10-H1-2026/source.md"
    quality_tier: A
    role: primary_own_return_formation_holding_family_and_wti_membership
strategy_mechanic: monthly-wti-sign-of-exact-ten-completed-broker-month-log-return-one-month-hold
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, time-series-momentum, ten-month-return, one-month-hold, symmetric-long-short, atr-hard-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 413910000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately twelve monthly WTI packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: BUILD_PENDING
q01_status: PENDING
q02_status: NOT_STARTED
parameters_to_test: "Locked Q02 baseline only: D1; eleven consecutive completed month-end closes; exact ten-month log-return sign; every-month decisions; one-month hold; 300 D1 bars; 3.5*ATR(20,D1) frozen stop; 40-day stale repair; 1500-point spread ceiling."
review_focus: "Falsify the source-bounded WTI k=10,h=1 stream. Verify eleven exact completed-month endpoints, every-month attempts, fixed risk, frozen stop, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [exact_symbol_period, completed_month_reconstruction, exact_ten_month_orientation, monthly_attempt_state, one_month_rollover, risk_mode_dual, hard_stop_present, q02_frequency_floor, portfolio_correlation]
---

# QM5_41391 WTI Ten-Month Momentum / One-Month Hold

## Hypothesis

A ten-completed-month WTI own-return direction may persist over the next
month, providing an energy return driver absent from the current index/metal/
XNG book. This is a pre-result structural test. The peer-reviewed source
defines the time-series-momentum formation/holding family and includes WTI,
but does not publish a standalone WTI `k=10, h=1` or continuous-CFD result.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/MOP-WTI-TSMOM10-H1-2026/source.md`; its complete-read
parent is `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The published
paper hash is
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The canonical checker found no exact identity and expected family matches
only. `QM5_41388` uses the same ten-month formation but a fixed odd-month,
two-month package. Monthly-renewal WTI systems use other exact horizons or
additional composite/filter/statistic logic. This card requires both exact
`k=10` endpoints and the every-month `h=1` lifecycle.

## Market, Clock, And Formula

- Host and traded symbol: setfile-bound `XTIUSD.DWX`; D1 only.
- Decision: first processed D1 bar of every new broker month.
- History: eleven consecutive completed broker-month-end closes `C[0]..C[10]`,
  oldest to newest; newest is the immediately prior completed month.
- Formula: `r10 = ln(C[10] / C[0])`; positive buys, negative sells, equality or invalid state stays flat.
- Lifecycle: close and reconsider at the next month edge; 40 elapsed days is stale repair.

## Rules

### 4. Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require configured symbol, D1, EA 41391, slot 0, and fixed-risk backtest mode.
3. At a genuine month transition, persist the month attempt before history,
   signal, spread, quote, ATR, sizing, news, or order gates.
4. Reconstruct exactly eleven positive finite consecutive completed month-end
   closes with strictly increasing timestamps and no current-month price.
5. Compute `ln(C[10]/C[0])`; buy strict positive and sell strict negative.
6. Require spread from 0 through 1,500 points and completed ATR(20,D1). Open at
   most one fixed-risk position with a frozen `3.5*ATR` stop and no target.

### 5. Exit Rules

Close the prior package at the first processed D1 bar of the next broker month
before any replacement. Broker hard stop and framework kill switch remain
authoritative; 40 days is stale repair. No target, signal flip, trail,
break-even, partial close, Friday flatten, scale-in, pyramid, grid, martingale,
or discretionary exit.

### 6. Filters (No-Trade Module)

Fail closed for wrong symbol/period/ID/slot/risk mode, invalid strategy inputs,
consumed month, owned position, prior deal, malformed or nonconsecutive
endpoints, current-month leakage, nonfinite return, equality, excess spread,
invalid quote/ATR/stop, or failed persistence. News and Friday inputs remain
framework-governed and are not pinned by the strategy guard.

### 7. Trade Management Rules

Maintain at most one owned WTI position and one durable attempt per broker
month. Flatten duplicate, wrong-symbol, wrong-magic, wrong-side, missing-stop,
take-profit-bearing, future-dated, or stale exposure. Close a valid package at
the next broker-month boundary before considering replacement.

## Parameters To Test

No optimization surface is approved. The locked Q02 baseline is:

| Parameter | Value |
|---|---:|
| `strategy_symbol` | `XTIUSD.DWX` |
| `strategy_return_months` | 10 |
| `strategy_hold_months` | 1 |
| `strategy_history_bars_d1` | 300 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 40 |
| `strategy_max_spread_points` | 1500 |

## Runtime Data Dependencies

Configured-symbol D1 OHLC, broker calendar time, symbol metadata, executable
quotes, completed ATR, framework position/deal history, and terminal-global
attempt state only. No futures chain, inventory, curve, volume, open interest,
file, API, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
Principal risks are futures/CFD roll and basis, financing, WTI gaps, monthly
endpoint sensitivity, hard-stop slippage, weak carrier-specific evidence, and
portfolio correlation.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WTI_SPECIFIC_EFFICACY_UNPROVEN | Peer-reviewed complete-read JFE source defines the family and includes WTI; no standalone result is imported. |
| R2 | PASS | Endpoints, formula, monthly clock, side, attempt, risk, stop, and lifecycle are fixed. |
| R3 | PASS_WITH_CONTINUOUS_CFD_BASIS_RISK | Native registered XTIUSD.DWX D1 history supplies runtime inputs. |
| R4 | PASS | Deterministic native arithmetic without trained or prohibited logic. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed trades
in any full post-warm-up year, nonpositive governed economics, wrong endpoints,
month leakage, repeated/skipped attempt, missing stop, wrong exit, or
nondeterminism. Changing formation, hold, direction, carrier, stop, risk,
spread, or retry policy requires a new identity and Q00/Q01.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact period, month clock, endpoints, return, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed, next-month, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping | Trade Close | `Strategy_ExitSignal` |
| framework-governed news and Friday inputs | No-Trade | framework hooks, never locked by strategy guard |

## Validation And Kill Conditions

Q01 must verify fixtures for positive, negative, equality, endpoint order,
month continuity, current-month exclusion, consumed attempts, next-month
closure, frozen stop, and stale repair; card lint; resolver; PACER audit; and
strict compile/build checks. Q02 owns density/economics. Q09 alone may establish
realized decorrelation.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build, Q01, and one
paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests,
optimization, portfolio-gate edits, correlation waivers, admission, deploy or
live manifests, `T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | `decisions/2026-09-09_wti_ten_month_momentum_one_month_hold_source_approval.md` |
| G0 Research Intake | 2026-09-09 | APPROVED | `decisions/2026-09-09_qm5_41391_wti_tsmom10_h1_g0.md` |
| Q01 Build Validation | — | PENDING | Requires source-fresh PACER audit, reference vectors, and governed strict compile. |
| Q02 Baseline Screening | — | NOT_STARTED | Enqueue exactly one XTIUSD.DWX D1 row only after Q01 and a fresh CPU admission check. |
