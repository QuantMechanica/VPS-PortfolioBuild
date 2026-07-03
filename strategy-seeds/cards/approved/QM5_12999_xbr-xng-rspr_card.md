---
ea_id: QM5_12999
slug: xbr-xng-rspr
type: strategy
strategy_id: EIA-OILGAS-RSPREAD-2026_XBR_XNG_RSPR
source_id: EIA-OILGAS-RSPREAD-2026
source_citation: "U.S. Energy Information Administration. An Analysis of Price Volatility in Natural Gas Markets, section on the relationship between crude oil and natural gas prices. https://www.eia.gov/naturalgas/articles/reloilgaspriindex.php; Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley."
source_citations:
  - type: article
    citation: "U.S. Energy Information Administration. An Analysis of Price Volatility in Natural Gas Markets."
    location: "section: relationship between crude oil and natural gas prices"
    quality_tier: A
    role: primary
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley."
    location: "pair-spread mean-reversion mechanics"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/EIA-OILGAS-RSPREAD-2026]]"
concepts:
  - "[[concepts/energy-relative-value]]"
  - "[[concepts/return-spread-reversion]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [market-neutral-basket, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XBRUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XBRUSD.DWX, XNGUSD.DWX]
markets: [XBRUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_12999_XBR_XNG_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XBR/XNG return-spread z-score reversion; estimate 8-16 paired packages/year after z-score, spread, max-hold, and ATR filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.10
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, basket_leg_atomicity, symbol_history_sufficiency]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS reputable EIA oil/gas relationship source plus Chan pair-spread implementation lineage; R2 PASS deterministic D1 two-leg return-spread z-score reversion with mean exit, max-hold exit, spread caps, and ATR hard stops; R3 PASS XNGUSD.DWX is in the DWX matrix and XBRUSD.DWX is routed by active Brent builds, with Q02 validating synchronized history sufficiency; R4 PASS no ML/grid/martingale/external runtime data. Non-duplicate versus existing commodity sleeves because this is XBR/XNG return-spread mean reversion, not XBR/XNG volatility breakout, XTI/XNG return-spread, oil/gas price-ratio z-score, raw ratio breakout, single-symbol XNG/Brent/WTI, metal ratio, index, or RSI commodity logic."
---

# XBR/XNG D1 Return-Spread Reversion

## Source

- Source: [[sources/EIA-OILGAS-RSPREAD-2026]]
- Primary citation: U.S. Energy Information Administration, "An Analysis of
  Price Volatility in Natural Gas Markets", relationship between crude oil and
  natural gas prices.
- Supplement: Ernest P. Chan, *Algorithmic Trading: Winning Strategies and
  Their Rationale*, Wiley, 2013, pair-spread mean-reversion mechanics.

## Concept

Crude oil and natural gas have a structural economic relationship, but the
relationship is unstable enough that fixed price-ratio ownership can be brittle.
This card trades temporary D1 return dislocations between Brent and natural gas:
when Brent's fixed-window return is unusually high versus natural gas, sell
Brent and buy gas; when Brent's return is unusually low versus gas, buy Brent
and sell gas.

This is deliberately different from:

- `QM5_12857_xbr-xng-vcb`: that is XBR/XNG Bollinger BandWidth compression
  breakout; this is return-spread z-score reversion.
- `QM5_12840_xti-xng-rspread`: that uses WTI versus natural gas; this uses the
  Brent benchmark proxy against natural gas.
- `QM5_12578_eia-oilgas-ratio` and `QM5_12608_eia-oilgas-breakout`: those trade
  XTI/XNG price-ratio level behavior; this trades XBR/XNG fixed-window return
  divergence.
- `QM5_12843_wti-brent-spread`, `QM5_12848_wti-brent-brk`, and
  `QM5_12860_wti-brent-rshock`: those are crude benchmark spread sleeves, not
  oil versus natural gas.
- XAU/XAG, oil/gold, oil/silver, gas/gold, and gas/silver baskets: this is an
  energy-only relative-value sleeve.
- `QM5_12567_cum-rsi2-commodity`: no RSI or short-horizon oscillator pullback.

## Markets And Timeframe

- Logical symbol: `QM5_12999_XBR_XNG_RSPREAD_D1`.
- Host symbol: `XBRUSD.DWX`.
- Basket legs: `XBRUSD.DWX` and `XNGUSD.DWX`.
- Period: `D1`.
- Expected package frequency: about 8-16 paired packages/year before Q02.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, ATR, broker calendar, and V5
  framework state only. No futures curve, EIA feed, volume, open interest, CSV,
  API, analyst forecast, alternative data, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar of the `XBRUSD.DWX` host chart.
- Copy completed D1 closes for `XBRUSD.DWX` and `XNGUSD.DWX`.
- Compute `return_spread = ln(XBR[t] / XBR[t-L]) - beta * ln(XNG[t] / XNG[t-L])`.
- Standardize the current return spread against the prior
  `strategy_z_lookback_d1` return-spread observations.
- If z-score is greater than `strategy_entry_z`, short the spread: sell Brent
  and buy natural gas.
- If z-score is less than negative `strategy_entry_z`, long the spread: buy
  Brent and sell natural gas.
- No entry when either leg exceeds its spread cap.
- No entry if any basket leg is already open for this EA magic.

## Exit Rules

- Exit both legs when absolute z-score falls below `strategy_exit_z`.
- Exit both legs when calendar hold exceeds `strategy_max_hold_days`.
- Exit both legs on framework Friday close.
- If only one leg is open, close the orphaned package immediately.
- Each leg carries a hard ATR stop at
  `strategy_atr_sl_mult * ATR(strategy_atr_period_d1)`.

## Filters

- Only run from the `XBRUSD.DWX` D1 host chart with `qm_magic_slot_offset=0`.
- Require positive prices, valid return-spread standard deviation, valid ATR,
  valid lot sizing, and allowed spreads for both legs.
- Framework kill-switch, symbol guard, magic resolver, news, and Friday-close
  controls remain active.

## Trade Management Rules

- Market-neutral two-leg package.
- Symmetric long/short spread.
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
- name: strategy_beta
  default: 1.0
  sweep_range: [0.5, 1.0, 1.5]
- name: strategy_entry_z
  default: 1.8
  sweep_range: [1.5, 1.8, 2.4]
- name: strategy_exit_z
  default: 0.4
  sweep_range: [0.2, 0.4, 0.8]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 25
  sweep_range: [15, 25, 35]
- name: strategy_xbr_max_spread_pts
  default: 1200
  sweep_range: [800, 1200, 1800]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

The sources establish structural oil/gas relationship and pair-spread
mean-reversion lineage only. This card imports no source performance number.
Q02 and later phases must validate or reject the `XBRUSD.DWX` / `XNGUSD.DWX`
basket on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.10.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 8-16 paired packages/year.
- risk_class: medium-high for energy-ratio gap and leg-basis risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: U.S. government EIA source plus established Chan
  pair-spread mean-reversion implementation lineage.
- [x] R2 mechanical: fixed D1 return-spread z-score, spread caps, max-hold exit,
  mean-reversion exit, and ATR hard stops.
- [x] R3 testable: `XNGUSD.DWX` exists in the DWX matrix and `XBRUSD.DWX` is
  routed by active Brent builds; Q02 validates synchronized history sufficiency.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, and
  no pyramiding.
- [x] Non-duplicate: this is XBR/XNG return-spread mean reversion, not XBR/XNG
  volatility breakout, XTI/XNG return-spread, XTI/XNG price-ratio z-score,
  raw ratio breakout, relative momentum, fixed seasonal switch, single-symbol
  XNG or crude logic, metal/index exposure, or commodity RSI.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: host/timeframe guard, magic-slot guard, parameter guard, spread
  caps, ratio data sufficiency, and valid lot/ATR checks.
- trade_entry: D1 standardized XBR/XNG return-spread reversion.
- trade_management: mean-reach exit, max-hold stale-package exit, orphan leg
  cleanup, and Friday close.
- trade_close: hard ATR stop plus deterministic package close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial XBR/XNG return-spread basket build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12999_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | work item `e38708b0-22d3-45fd-ab74-f045d8e29ad2` in `D:\QM\strategy_farm\state\farm_state.sqlite` |
