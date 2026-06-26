---
ea_id: QM5_12578
slug: eia-oilgas-ratio
type: strategy
source_id: EIA-OILGAS-RATIO-2026
source_citation: "EIA Energy Explained crude oil and natural gas market fundamentals; Baker Institute oil-natural-gas price relationship research."
sources:
  - "[[sources/EIA-ENERGY-EXPLAINED-CRUDE-OIL]]"
  - "[[sources/EIA-ENERGY-EXPLAINED-NATURAL-GAS]]"
  - "[[sources/BAKER-OIL-GAS-PRICE-RATIO]]"
concepts:
  - "[[concepts/oil-gas-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_12578_XTI_XNG_RATIO_D1
period: D1
expected_trade_frequency: "D1 oil-gas ratio z-score basket; estimate 4-12 spread packages/year."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS EIA official source plus Baker Institute research; R2 PASS deterministic D1 XTI/XNG log-ratio z-score basket; R3 PASS XTIUSD.DWX and XNGUSD.DWX available; R4 PASS no ML/grid/martingale."
expected_pf: 1.15
expected_dd_pct: 18.0
---

# EIA Oil/Gas Ratio Reversion

## Source

- Source: [[sources/EIA-ENERGY-EXPLAINED-CRUDE-OIL]]
- Source: [[sources/EIA-ENERGY-EXPLAINED-NATURAL-GAS]]
- Supplement: [[sources/BAKER-OIL-GAS-PRICE-RATIO]]
- Primary EIA URLs:
  - https://www.eia.gov/energyexplained/oil-and-petroleum-products/
  - https://www.eia.gov/energyexplained/natural-gas/
- Supplemental Baker Institute URL:
  - https://www.bakerinstitute.org/research/the-relationship-between-crude-oil-and-natural-gas-prices

## Concept

Crude oil and natural gas are distinct energy markets, but they share broad
energy-demand and substitution links. This card trades extreme deviations in the
oil/gas price relationship as a two-leg basket, using only Darwinex MT5 D1 OHLC
series. It is designed to add energy relative-value exposure rather than another
outright commodity trend or seasonal sleeve.

This is deliberately different from `QM5_12567_cum-rsi2-commodity`, which is a
short-horizon RSI pullback port across commodities. It is also different from
`QM5_12575_eia-xng-season` and `QM5_12576_eia-wti-season`: those are standalone
seasonal sleeves, while this card always trades a paired XTI/XNG package.

## Markets And Timeframe

- Host symbol: XTIUSD.DWX.
- Basket leg symbols: XTIUSD.DWX and XNGUSD.DWX.
- Logical symbol: QM5_12578_XTI_XNG_RATIO_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no EIA feed, futures curve, inventory feed, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(XNGUSD.DWX close)` on prior closed D1 bars.
- Compute a rolling z-score of the spread over `strategy_z_lookback_d1`.
- Entry Short Ratio: if z-score is above `strategy_entry_z`, SELL XTIUSD.DWX and BUY XNGUSD.DWX.
- Entry Long Ratio: if z-score is below `-strategy_entry_z`, BUY XTIUSD.DWX and SELL XNGUSD.DWX.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(20) * 3.0 from entry.
- Exit both legs when absolute spread z-score falls below `strategy_exit_z`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- Skip entries when XTI spread exceeds 1000 points or XNG spread exceeds 2500 points.
- Skip entries when either close series or either ATR series is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open basket package at a time.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [90, 120, 180, 252]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.5, 0.8, 1.0, 1.2, 1.5]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 3.5, 4.5]

## Author Claims

No performance claim is taken from EIA or Baker Institute sources. The sources
are used only for structural lineage: oil and gas are economically related
energy markets with historically changing relative-price relationships.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-12 spread packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: EIA official energy market sources plus Baker Institute research.
- [x] R2 mechanical: fixed log-ratio z-score entry/exit and ATR stops.
- [x] R3 testable: XTIUSD.DWX and XNGUSD.DWX exist in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.
- [x] No duplicate of QM5_12575/QM5_12576: this is paired energy relative value, not standalone seasonality.

## Framework Alignment

- no_trade: host chart guard, D1 guard, spread caps.
- trade_entry: two-leg basket entry on oil/gas log-ratio z-score extremes.
- trade_management: none beyond per-leg ATR stops.
- trade_close: package repair and ratio z-score reversion exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-26 | initial structural XTI/XNG ratio basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
