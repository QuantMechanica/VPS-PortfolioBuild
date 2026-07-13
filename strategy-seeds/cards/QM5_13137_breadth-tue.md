---
strategy_id: OWNER-FTMO-SURVIVORS-20260711_S04
source_id: OWNER-FTMO-SURVIVORS-20260711
ea_id: QM5_13137
slug: breadth-tue
status: APPROVED
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
g0_status: APPROVED
source_citation: "OWNER FTMO survivor handoff dated 2026-07-11; immutable research evidence and disclosed gate amendment under .private/secret_strategy_lab/breadth_turnaround_tuesday/."
source_citations:
  - type: owner_originated_research
    citation: "OWNER FTMO survivor handoff, 2026-07-11"
    location: "strategy-seeds/sources/OWNER-FTMO-SURVIVORS-20260711/README.md"
    quality_tier: INTERNAL
    role: primary
target_symbols: [SP500.DWX, WS30.DWX, XAUUSD.DWX]
primary_target_symbols: [SP500.DWX, WS30.DWX, XAUUSD.DWX]
markets: [indices, metals, calendar_mean_reversion]
timeframes: [M30, D1]
period: M30
single_symbol_only: false
expected_trade_frequency: "Approximately 13-18 completed trades/year/symbol after the joint SP500/WS30 Monday breadth gate."
expected_trades_per_year_per_symbol: 16
expected_pf: 1.25
expected_dd_pct: 15.0
risk_class: high
ml_required: false
r1_track_record: PASS
r1_reasoning: "Exactly one OWNER source_id; the pre-C gate-unit amendment remains in the immutable evidence."
r2_mechanical: PASS
r2_reasoning: "Exact Monday cash-window breadth, fixed 23:00 entry/exit and prior-D1 ATR stop are deterministic at about 16 trades/year/symbol."
r3_data_available: PASS
r3_reasoning: "SP500.DWX, WS30.DWX and XAUUSD.DWX M30/D1 data are registered for backtest; SP500 remains backtest-only for live routing."
r4_ml_forbidden: PASS
r4_reasoning: "Each host symbol uses one independent magic; no ML, grid, martingale or PnL adaptation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [multi_symbol_history, broker_time_dst, correlated_index_legs, sp500_backtest_only]
g0_approval_reasoning: "R1 single OWNER source with amendment preserved; R2 exact joint Monday breadth and timed exit; R3 native SP500/WS30/XAU data; R4 separate deterministic magics; distinct from single-index Tuesday EAs."
---

# Breadth-Confirmed Turnaround Tuesday

## Hypothesis

When both SP500 and WS30 fall during the Monday US cash session, broad
inventory pressure can reverse into Tuesday. The joint breadth gate is the
distinct mechanic; it is not the existing single-index Turnaround Tuesday EA.

## Source And Evidence Boundary

The single source is the OWNER handoff dated 2026-07-11. Source URL:
`local://OWNER-FTMO-SURVIVORS-20260711`. The disclosed frequency-unit amendment
is preserved at `.private/secret_strategy_lab/breadth_turnaround_tuesday/`.
Global library contamination and correlated execution sleeves remain explicit
risks for the formal pipeline.

## Markets And Timeframe

- Host symbols: `SP500.DWX` slot 0, `WS30.DWX` slot 1, `XAUUSD.DWX` slot 2.
- Signal symbols are always both `SP500.DWX` and `WS30.DWX`.
- Host timeframe: M30; stop reference: completed D1 ATR14.
- Expected frequency: 16 trades/year/symbol.
- SP500 is backtest-only; future live promotion requires a separately approved
  routable composition.

## 4. Entry Rules

- Evaluate at broker Monday 23:00 on a new M30 bar.
- Read the exact Monday 16:30 M30 open and 22:30 M30 close for SP500 and WS30.
- Require `SP500 close < SP500 open` and `WS30 close < WS30 open`.
- If both are true, enter long on the current host symbol at market.
- Attach a hard stop at `entry - 1.0 * ATR(14, D1)[1]` of the host symbol.
- Require exact signal bars, valid synchronized history, risk clearance and no
  position for the host magic.
- There is no magnitude threshold, trend filter, short entry or re-entry.

## 5. Exit Rules

- Exit the host position at broker Tuesday 23:00 on the new M30 bar.
- The host broker hard stop remains authoritative before the timed exit.
- No take-profit, trail, break-even or Wednesday extension is permitted.

## 6. Filters (No-Trade Module)

- Fail closed outside the three host symbols, M30, or a registered host slot.
- `SP500.DWX` and `WS30.DWX` must both be selected and have exact M30 bars at
  the two required Monday timestamps.
- Require valid completed host D1 ATR14.
- Timed exits must run before any entry-only news gate.
- Framework kill switch and risk-mode checks remain authoritative.

## 7. Trade Management Rules

- Exactly one position per host-symbol magic.
- Each host is measured separately in Q02; equal one-third portfolio weighting
  is not assumed until joint book testing.
- No partial close, scale-in, grid, recovery, martingale or PnL adaptation.

## Parameters To Test

| parameter | default | authorized range |
|---|---:|---|
| `strategy_entry_hour` | 23 | [23] |
| `strategy_exit_hour` | 23 | [23] |
| `strategy_cash_open_hour` | 16 | [16] |
| `strategy_cash_open_minute` | 30 | [30] |
| `strategy_cash_close_hour` | 22 | [22] |
| `strategy_cash_close_minute` | 30 | [30] |
| `strategy_atr_period_d1` | 14 | [14] |
| `strategy_stop_atr_mult` | 1.0 | [1.0] |

## Kill Criteria

Retire if the joint signal timestamps are not stable in Model 4, any sleeve is
below current-cost PF 1.20, the 2024-2025 holdout is negative, or floating MAE
cannot be reconciled. The disclosed gate amendment authorizes no further
frequency or threshold changes.
