---
ea_id: QM5_13094
slug: xti-xcu-brk
type: strategy
strategy_id: EIA-CME-USGS-XTI-XCU-BRK-2026
source_id: EIA-CME-USGS-XTI-XCU-BRK-2026
source_citation: "U.S. Energy Information Administration crude-oil price driver explainer, CME Copper Futures, USGS Copper Statistics, and Donchian/Turtle channel-breakout implementation lineage."
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
sources:
  - "[[sources/EIA-CME-USGS-XTI-XCU-BRK-2026]]"
concepts:
  - "[[concepts/energy-base-metal-relative-value]]"
  - "[[concepts/spread-channel-breakout]]"
indicators:
  - "[[indicators/log-price-spread]]"
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, commodity-relative-value, energy-base-metal, spread-channel-breakout, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
basket_symbols: [XTIUSD.DWX, XCUUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
markets: [commodities, energy, base-metals]
timeframes: [D1]
logical_symbol: QM5_13094_XTI_XCU_BRK_D1
single_symbol_only: false
period: D1
expected_trade_frequency: "D1 WTI/copper log-spread channel breakout; estimate 4-10 paired packages/year after channel, spread, and framework filters."
expected_trades_per_year_per_symbol: 7
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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: R1 PASS official EIA crude-oil source, official CME/USGS copper references, and channel-breakout implementation lineage; R2 PASS deterministic D1 XTI/XCU log-price spread channel breakout with exit channel, ATR hard stops, max-hold exit, spread caps, and broken-package repair; R3 PASS XTIUSD.DWX is in the DWX matrix and existing V5 builds use XCUUSD.DWX, with synchronized XTI/XCU history left to Q02; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate because it is price-level log-spread continuation, not the QM5_13090 return-spread z-score reversion basket, WTI event/seasonal/inventory/roll/COT logic, commodity-FX residual spread, oil/gold, oil/silver, XTI/XNG, solo copper, or commodity-RSI logic."
---

# XTI/XCU D1 Channel Breakout Basket

## Source

- Source: [[sources/EIA-CME-USGS-XTI-XCU-BRK-2026]]
- Primary citations: EIA crude-oil price drivers, CME Copper Futures, and USGS
  Copper Statistics and Information.
- Implementation lineage: Donchian/Turtle-style channel breakout on a
  deterministic spread series.

## Concept

WTI crude and copper both carry global growth and physical-commodity risk, but
their driver mix can diverge for structural reasons. Crude oil is sensitive to
energy supply, spare capacity, refinery demand, and geopolitical shocks; copper
is a base-metal industrial-demand and supply-chain leg. This card expresses
persistent divergence between the two as a market-neutral basket instead of
another directional XAU, index, XNG, or single-symbol WTI sleeve.

The EA computes:

`spread = log(XTIUSD.DWX close) - strategy_beta_xcu * log(XCUUSD.DWX close)`

An upside channel break buys WTI and sells copper. A downside channel break
sells WTI and buys copper. Runtime uses only MT5 OHLC, spread, ATR, broker
calendar, and V5 framework state.

This is deliberately different from `QM5_13090_xti-xcu-rspread`, which fades
fixed-window return-spread z-score extremes. This card follows price-level
log-spread channel continuation and exits on a shorter channel reversal or
time stop.

## Markets And Timeframe

- Logical symbol: `QM5_13094_XTI_XCU_BRK_D1`.
- Host symbol: `XTIUSD.DWX`.
- Basket legs: `XTIUSD.DWX` and `XCUUSD.DWX`.
- Period: `D1`.
- Expected package frequency: approximately 4-10 paired packages/year.
- Backtest risk mode: `RISK_FIXED`.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 with magic slot 0.
- Compute the latest completed-bar log-price spread.
- Compute the highest and lowest spread over
  `strategy_entry_lookback_d1`, excluding the latest completed spread.
- If the latest spread is above the entry channel high, buy `XTIUSD.DWX` and
  sell `XCUUSD.DWX`.
- If the latest spread is below the entry channel low, sell `XTIUSD.DWX` and
  buy `XCUUSD.DWX`.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when the spread crosses the opposite
  `strategy_exit_lookback_d1` channel.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from the `XTIUSD.DWX` D1 host chart with
  `qm_magic_slot_offset=0`.
- Require positive prices, synchronized D1 history, valid ATR, valid lot
  sizing, and allowed spreads for both legs.
- Framework kill-switch, symbol guard, magic resolver, entry-only news
  blackout, and Friday-close controls remain active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short commodity basket.
- No pyramiding, gridding, martingale, partial close, or trailing stop in v1.
- One package per EA magic.

## Parameters To Test

- name: strategy_entry_lookback_d1
  default: 120
  sweep_range: [90, 120, 180, 252]
- name: strategy_exit_lookback_d1
  default: 40
  sweep_range: [20, 40, 60]
- name: strategy_beta_xcu
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 65]
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xcu_max_spread_pts
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

No performance claim is imported into QM. The sources establish structural
lineage for WTI and copper as distinct physical-commodity risk legs and for
mechanical spread breakout implementation. Q02+ must validate the deterministic
Darwinex XTI/XCU basket port.

## Initial Risk Profile

- expected_pf: 1.06.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 4-10 paired packages/year.
- risk_class: high for commodity spread volatility, gap risk, and XCU history
  depth uncertainty.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA crude-oil source, official CME/USGS
  copper references, and channel-breakout implementation lineage.
- [x] R2 mechanical: fixed lookback D1 log spread, channel entry and exit,
  paired basket orders, ATR hard stops, spread caps, max-hold exit, and orphan
  repair.
- [x] R3 testable: `XTIUSD.DWX` exists in the DWX symbol matrix and existing
  V5 builds use `XCUUSD.DWX`; Q02 must validate synchronized XTI/XCU bars and
  fills.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  feed, or multiple packages per magic.
- [x] Non-duplicate: XTI/XCU channel continuation, not `QM5_13090` return-spread
  reversion, not commodity-FX, XTI/XNG, oil/gold, oil/silver, solo copper, WTI
  calendar/event/inventory, or commodity-RSI logic.

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
    notes: "D1 XTI-minus-XCU log-price spread channel break opens a two-leg basket in the breakout direction."
  trade_management:
    used: true
    notes: "Orphan leg cleanup and max-hold stale-package guard."
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
|---|---|---|---|---|
| v1 | 2026-07-09 | initial XTI/XCU market-neutral channel-breakout build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PENDING | `artifacts/qm5_13094_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | PENDING | `artifacts/qm5_13094_q02_enqueue_20260709.json` |
