---
ea_id: QM5_13090
slug: xti-xcu-rspread
type: strategy
strategy_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
source_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
source_citation: "U.S. Energy Information Administration crude-oil price driver explainer, CME Copper Futures, USGS Copper Statistics, and Chan pair-spread implementation lineage."
source_citations:
  - type: government_explainer
    citation: "U.S. Energy Information Administration. What drives crude oil prices: Spot Prices."
    location: "https://www.eia.gov/finance/markets/crudeoil/spot_prices.php"
    quality_tier: A
    role: primary
  - type: exchange_reference
    citation: "CME Group. Copper Futures."
    location: "https://www.cmegroup.com/markets/metals/base/copper.html"
    quality_tier: A
    role: primary
  - type: government_reference
    citation: "U.S. Geological Survey. Copper Statistics and Information."
    location: "https://www.usgs.gov/centers/national-minerals-information-center/copper-statistics-and-information"
    quality_tier: A
    role: supplement
  - type: book
    citation: "Chan, Ernest P. Algorithmic Trading: Winning Strategies and Their Rationale. Wiley, 2013."
    location: "pair-spread mean-reversion implementation lineage"
    quality_tier: B
    role: supplement
sources:
  - "[[sources/EIA-CME-USGS-XTI-XCU-RSPREAD-2026]]"
concepts:
  - "[[concepts/energy-base-metal-relative-value]]"
  - "[[concepts/return-spread-reversion]]"
indicators:
  - "[[indicators/log-return-spread]]"
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, commodity-relative-value, energy-base-metal, return-spread-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
basket_symbols: [XTIUSD.DWX, XCUUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
markets: [commodities, energy, base-metals]
timeframes: [D1]
logical_symbol: QM5_13090_XTI_XCU_RSPREAD_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 WTI/copper return-spread z-score reversion; estimate 6-14 paired packages/year after spread, ATR, and framework filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.06
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, basket_manifest]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA crude-oil source, official CME/USGS copper references, and Chan pair-spread implementation lineage; R2 PASS deterministic D1 XTI/XCU fixed-window return-spread z-score reversion with ATR hard stops, max-hold exit, spread caps, and broken-package repair; R3 PASS XTIUSD.DWX is in the DWX matrix and existing V5 builds use XCUUSD.DWX, with synchronized XTI/XCU history left to Q02; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because it is WTI versus copper relative-return reversion, not XTI/AUD, XTI/CAD, XTI/XNG, oil/gold, oil/silver, XCU solo, WTI event/seasonal/inventory/roll/COT, or commodity-RSI logic."
---

# XTI/XCU D1 Return-Spread Reversion

## Source

- Source: [[sources/EIA-CME-USGS-XTI-XCU-RSPREAD-2026]]
- Primary citations:
  - U.S. Energy Information Administration, "What drives crude oil prices:
    Spot Prices."
  - CME Group, "Copper Futures."
  - U.S. Geological Survey, "Copper Statistics and Information."
- Implementation lineage: Chan, Ernest P., Algorithmic Trading: Winning
  Strategies and Their Rationale, Wiley, 2013.

## Concept

WTI crude and copper both carry global growth and physical-commodity risk, but
their short-run drivers differ: crude oil is strongly affected by energy supply,
demand, and disruption risk, while copper reflects base-metal industrial demand
and supply-chain conditions. This card expresses temporary D1 relative-return
dislocations between the two commodities as a market-neutral basket rather than
another directional XAU, index, XNG, or single-symbol WTI sleeve.

The EA computes:

`return_spread = log(XTI[t] / XTI[t-L]) - beta_xcu * log(XCU[t] / XCU[t-L])`

The current spread is standardized against a rolling D1 window. High positive
z-scores sell WTI and buy copper; high negative z-scores buy WTI and sell
copper. Runtime uses only MT5 OHLC/spread/ATR data and V5 framework state.

This is deliberately different from:

- `QM5_13073_xti-audusd-rspr`, `QM5_13034_xti-audcad-rspr`, and other
  commodity-FX baskets: no AUD, CAD, JPY, CHF, NZD, GBP, or EUR leg.
- `QM5_13080_xcu-donchian55` and `QM5_13081_xcu-4w-reversal`: this is a
  two-leg package, not solo copper trend or reversal.
- `QM5_12863_oilgold-rspread`, `QM5_12864_oilsilver-rspr`, and
  `QM5_13053_brentsilver-rspr`: this is WTI/copper, not oil versus precious
  metals or Brent/silver.
- `QM5_12840_xti-xng-rspread` and `QM5_13089_xti-xng-carry`: no natural-gas
  leg, no swap-carry ranking.
- WTI event, calendar, WPSR, refinery, Cushing, SPR, COT, OPEC, IEA, JODI,
  roll-window, commodity-RSI, and intraday breakout sleeves.

## Markets And Timeframe

- Logical symbol: `QM5_13090_XTI_XCU_RSPREAD_D1`.
- Host symbol: `XTIUSD.DWX`.
- Basket legs: `XTIUSD.DWX` and `XCUUSD.DWX`.
- Period: `D1`.
- Expected package frequency: approximately 6-14 paired packages/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 closes, ATR, spread, and framework state only.

## Entry Rules

- Evaluate only on a new D1 bar of the `XTIUSD.DWX` host chart.
- Copy completed D1 closes for `XTIUSD.DWX` and `XCUUSD.DWX`.
- Compute each leg's fixed-window log return over
  `strategy_return_lookback_d1`.
- Compute `return_spread = xti_return - strategy_beta_xcu * xcu_return`.
- Standardize the latest return spread over `strategy_z_lookback_d1`.
- If z-score is above `strategy_entry_z`, sell `XTIUSD.DWX` and buy
  `XCUUSD.DWX`.
- If z-score is below `-strategy_entry_z`, buy `XTIUSD.DWX` and sell
  `XCUUSD.DWX`.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when `abs(zscore) < strategy_exit_z`.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from the `XTIUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, synchronized D1 history, valid ATR, valid lot sizing,
  and allowed spreads for both legs.
- Framework kill-switch, symbol guard, magic resolver, entry-only news blackout,
  and Friday-close controls remain active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short commodity basket.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_return_lookback_d1
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [80, 120, 180]
- name: strategy_beta_xcu
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: strategy_entry_z
  default: 1.9
  sweep_range: [1.6, 1.9, 2.2]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.25, 0.4, 0.6]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 30
  sweep_range: [20, 30, 45]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xcu_max_spread_pts
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

No performance claim is imported into QM. The sources establish structural
lineage for WTI and copper as distinct physical-commodity risk legs and for
pair-spread mean-reversion implementation; Q02+ must validate the deterministic
Darwinex XTI/XCU basket port.

## Initial Risk Profile

- expected_pf: 1.06.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 6-14 paired packages/year.
- risk_class: high for commodity spread volatility, gap risk, and XCU history
  depth uncertainty.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA crude-oil source, official CME/USGS
  copper references, and Chan pair-spread implementation lineage.
- [x] R2 mechanical: fixed lookback D1 return spread, rolling z-score entry and
  exit, paired basket orders, ATR hard stops, spread caps, max-hold exit, and
  orphan repair.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix and existing V5
  builds use `XCUUSD.DWX`; Q02 must validate synchronized XTI/XCU bars/fills.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  feed, or multiple packages per magic.
- [x] Non-duplicate: WTI/copper relative-return basket, not commodity-FX,
  XTI/XNG, oil/gold, oil/silver, solo copper, WTI calendar/event/inventory, or
  commodity-RSI logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "XTIUSD.DWX D1 host only, slot 0, valid parameters, synchronized history, spread caps, framework kill-switch, symbol guard, news, and Friday close."
  trade_entry:
    used: true
    notes: "D1 XTI-minus-XCU fixed-window return-spread z-score extremes open a two-leg basket against the dislocation."
  trade_management:
    used: true
    notes: "Orphan leg cleanup, max-hold stale-package guard, and z-score normalization exit."
  trade_close:
    used: true
    notes: "Per-leg ATR hard stop plus deterministic package close rules."
hard_rules_at_risk:
  - friday_close
  - magic_schema
  - risk_mode_dual
  - basket_manifest
```

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-09 | initial XTI/XCU market-neutral return-spread build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PASS | `artifacts/qm5_13090_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `c135bd93-a7f2-4cd8-b5ca-9ec4d5a11f2b`; evidence `artifacts/qm5_13090_q02_enqueue_20260709.json` |
