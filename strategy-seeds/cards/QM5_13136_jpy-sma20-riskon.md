---
strategy_id: OWNER-FTMO-SURVIVORS-20260711_S03
source_id: OWNER-FTMO-SURVIVORS-20260711
ea_id: QM5_13136
slug: jpy-sma20-riskon
status: REJECTED_DUPLICATE
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
g0_status: REJECTED
duplicate_of: QM5_10377_et-ma50-cross
source_citation: "OWNER FTMO survivor handoff dated 2026-07-11; immutable research evidence under .private/secret_strategy_lab/jpy_cross_sma20_risk_on/."
source_citations:
  - type: owner_originated_research
    citation: "OWNER FTMO survivor handoff, 2026-07-11"
    location: "strategy-seeds/sources/OWNER-FTMO-SURVIVORS-20260711/README.md"
    quality_tier: INTERNAL
    role: primary
target_symbols: [AUDJPY.DWX, GBPJPY.DWX]
primary_target_symbols: [AUDJPY.DWX, GBPJPY.DWX]
markets: [forex, jpy_crosses]
timeframes: [D1]
period: D1
single_symbol_only: false
expected_trade_frequency: "Approximately 13-16 completed trades/year/symbol; each host chart is an independent equal-risk sleeve."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.3
expected_dd_pct: 15.0
risk_class: medium
ml_required: false
r1_track_record: PASS
r1_reasoning: "Exactly one OWNER source_id and an immutable local evidence trail."
r2_mechanical: PASS
r2_reasoning: "Per-symbol completed-bar SMA20 crosses, next-open orders, reverse-cross exits and ATR stops are deterministic at about 14 trades/year/symbol."
r3_data_available: PASS
r3_reasoning: "AUDJPY.DWX and GBPJPY.DWX D1 are native registered FX symbols."
r4_ml_forbidden: PASS
r4_reasoning: "One position per symbol-specific magic, no PnL adaptation, grid, martingale or ML."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [friday_close, correlated_jpy_legs, current_ftmo_swap]
g0_approval_reasoning: "R1 single OWNER source; R2 frozen per-symbol D1 SMA20 cross mechanics at defensible cadence; R3 native AUDJPY/GBPJPY; R4 separate one-position magics, non-ML; dedup clean."
---

# JPY-Cross SMA20 Risk-On Sleeves

## Hypothesis

AUDJPY and GBPJPY express persistent risk-on and JPY-funding expansions. A
fast D1 SMA20 state transition provides two related but separately measured
carriers for the FTMO book.

## G0 Duplicate Resolution

Rejected as a new EA after code-level dedup. `QM5_10377_et-ma50-cross`
already exposes MA period, ATR period/multiple and long-only mode. AUDJPY and
GBPJPY are added as registered D1 research sets of that existing EA; ID 13136
is permanently retired without a build.

## Source And Evidence Boundary

The single source is the OWNER handoff dated 2026-07-11. Source URL:
`local://OWNER-FTMO-SURVIVORS-20260711`. Research provenance is
`.private/secret_strategy_lab/jpy_cross_sma20_risk_on/`. Prior PF values do not
replace current FTMO commission, direction-swap or MAE gates.

## Markets And Timeframe

- Target symbols: `AUDJPY.DWX` slot 0 and `GBPJPY.DWX` slot 1.
- Each symbol runs the same EA on its own D1 chart and owns one magic.
- Expected frequency: 14 trades/year/symbol.
- Q02 runs `RISK_FIXED=1000` per symbol; equal-risk portfolio weighting is a
  later book decision and is not embedded into the signal.

## 4. Entry Rules

- Evaluate once on the first tick of each new D1 bar using completed bars only.
- Enter long when `Close[2] <= SMA20[2]` and `Close[1] > SMA20[1]`.
- Execute at the current D1 market open.
- Attach a hard stop at `entry - 3.0 * ATR(14)[1]`.
- Require the host to be one of the two declared symbols, valid indicators,
  framework risk clearance and no position for the host magic.
- No shorts, cross-symbol signal sharing, reweighting or same-state re-entry.

## 5. Exit Rules

- Exit at the current D1 market open when `Close[2] > SMA20[2]` and
  `Close[1] <= SMA20[1]`.
- The broker hard stop remains active between D1 bars.
- No take-profit, trail or break-even rule is permitted.

## 6. Filters (No-Trade Module)

- Fail closed outside `AUDJPY.DWX` or `GBPJPY.DWX`, outside D1, or when the
  symbol-to-slot mapping is invalid.
- Require SMA20 and ATR14 warm-up and valid positive prices.
- Framework kill-switch and risk-mode checks remain authoritative.
- Friday flattening is disabled to preserve the frozen multi-day trend hold.

## 7. Trade Management Rules

- Exactly one position per symbol-specific magic.
- Do not partially close, scale, recover, average, grid or adapt parameters.
- Portfolio construction must treat the legs as correlated JPY risk and cannot
  count them as two independent risk sources without measured evidence.

## Parameters To Test

| parameter | default | authorized range |
|---|---:|---|
| `strategy_ma_period_d1` | 20 | [20] |
| `strategy_atr_period_d1` | 14 | [14] |
| `strategy_stop_atr_mult` | 3.0 | [3.0] |

## Kill Criteria

Retire a symbol below current-cost PF 1.20, below five trades/year, on a
negative holdout, nondeterminism, or unreconciled MAE. No symbol substitution
or parameter rescue is authorized before baseline classification.
