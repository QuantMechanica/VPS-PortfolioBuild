---
strategy_id: OWNER-FTMO-SURVIVORS-20260711_S02
source_id: OWNER-FTMO-SURVIVORS-20260711
ea_id: QM5_13135
slug: xau-sma50-hold
status: REJECTED_DUPLICATE
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
g0_status: REJECTED
duplicate_of: QM5_10377_et-ma50-cross
source_citation: "OWNER FTMO survivor handoff dated 2026-07-11; immutable research evidence under .private/secret_strategy_lab/xau_sma50_impulse_hold/."
source_citations:
  - type: owner_originated_research
    citation: "OWNER FTMO survivor handoff, 2026-07-11"
    location: "strategy-seeds/sources/OWNER-FTMO-SURVIVORS-20260711/README.md"
    quality_tier: INTERNAL
    role: primary
target_symbols: [XAUUSD.DWX]
primary_target_symbols: [XAUUSD.DWX]
markets: [metals, gold]
timeframes: [D1]
period: D1
single_symbol_only: true
expected_trade_frequency: "Approximately 6-10 completed trades/year; 60 Python trades across 2018H2-2025."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.4
expected_dd_pct: 15.0
risk_class: high
ml_required: false
r1_track_record: PASS
r1_reasoning: "Exactly one OWNER source_id and an immutable local evidence trail."
r2_mechanical: PASS
r2_reasoning: "Completed-bar SMA50 crosses, next-open orders, reverse-cross exit and frozen ATR stop are deterministic at about eight trades/year."
r3_data_available: PASS
r3_reasoning: "XAUUSD.DWX D1 and ATR/SMA inputs are native and registered."
r4_ml_forbidden: PASS
r4_reasoning: "Long-only, one position per magic, no adaptive PnL logic, grid, martingale or ML."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [friday_close, multi_day_gap, current_ftmo_swap]
g0_approval_reasoning: "R1 single OWNER source; R2 frozen D1 SMA50 cross and ATR exit mechanics; R3 native XAUUSD.DWX; R4 deterministic one-position non-ML; dedup clean."
---

# XAU SMA50 Impulse Hold

## Hypothesis

Gold can sustain asymmetric upside regimes after crossing above a medium-term
price basis. A long-only SMA50 state change captures that trend while a wide
ATR stop limits a failed transition.

## G0 Duplicate Resolution

Rejected as a new EA after code-level dedup. `QM5_10377_et-ma50-cross`
already exposes MA period, ATR period/multiple, long-only mode and the required
XAU symbol slot. The idea proceeds as a D1 parameter-locked research set of
that existing EA; ID 13135 is permanently retired without a build.

## Source And Evidence Boundary

The single source is the OWNER handoff dated 2026-07-11. Source URL:
`local://OWNER-FTMO-SURVIVORS-20260711`. Research provenance is
`.private/secret_strategy_lab/xau_sma50_impulse_hold/`. The T_Export results
are priors only; the formal pipeline must reproduce the strategy independently.

## Markets And Timeframe

- Target symbol: `XAUUSD.DWX`, magic slot 0.
- Host and signal timeframe: D1.
- Expected frequency: 8 trades/year/symbol.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## 4. Entry Rules

- Evaluate once on the first tick of each new D1 bar.
- Read only completed D1 bars.
- Enter long when `Close[2] <= SMA50[2]` and `Close[1] > SMA50[1]`.
- Execute at the current D1 market open.
- Attach a hard stop at `entry - 3.0 * ATR(14)[1]`.
- Require valid prices, indicators, spread, framework risk clearance and no
  existing position for this magic.
- No short entry, boundary entry, same-state re-entry or scale-in is allowed.

## 5. Exit Rules

- Exit at the current D1 market open when `Close[2] > SMA50[2]` and
  `Close[1] <= SMA50[1]`.
- The broker hard stop remains authoritative between D1 bars.
- There is no take-profit, trailing stop or break-even rule.

## 6. Filters (No-Trade Module)

- Fail closed unless the host is exactly `XAUUSD.DWX` D1 and the registered
  magic slot resolves.
- Require at least 50 completed D1 bars plus ATR warm-up.
- Framework kill-switch and risk-mode checks remain authoritative.
- Friday flattening is disabled because it changes the frozen multi-day hold.

## 7. Trade Management Rules

- Exactly one position is allowed for the registered magic.
- Do not partially close, pyramid, recover, average, grid or adapt parameters.
- After a stop, a new entry requires a complete below-to-above SMA50 cross.

## Parameters To Test

| parameter | default | authorized range |
|---|---:|---|
| `strategy_ma_period_d1` | 50 | [50] |
| `strategy_atr_period_d1` | 14 | [14] |
| `strategy_stop_atr_mult` | 3.0 | [3.0] |

## Kill Criteria

Retire on Q02 PF below 1.20 after current FTMO XAU commission and swaps, zero
trades, nondeterminism, missing annual density, or unreconciled floating MAE.
No parameter rescue is authorized before the baseline verdict.
