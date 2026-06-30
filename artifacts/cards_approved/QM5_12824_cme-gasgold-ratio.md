---
ea_id: QM5_12824
slug: cme-gasgold-ratio
type: strategy
source_id: CME-GAS-GOLD-RELVAL-2026
source_citation: "CME Group. Henry Hub Natural Gas Futures Overview. URL https://www.cmegroup.com/markets/energy/natural-gas/natural-gas.html; CME Group. Gold Futures Overview. URL https://www.cmegroup.com/markets/metals/precious/gold.html"
sources:
  - "[[sources/CME-GAS-GOLD-RELVAL-2026]]"
concepts:
  - "[[concepts/natural-gas-gold-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-zscore, market-neutral-basket, atr-hard-stop, mean-reversion-exit, low-frequency]
target_symbols: [XNGUSD.DWX, XAUUSD.DWX]
logical_symbol: QM5_12824_XNG_XAU_RATIO_D1
period: D1
expected_trade_frequency: "D1 natural-gas/gold ratio z-score basket; estimate 5-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-30
g0_approval_reasoning: "R1 PASS CME exchange product source packet for Henry Hub Natural Gas and Gold futures; R2 PASS deterministic D1 natural-gas/gold log-ratio z-score basket with ATR stops and mean-reversion exit; R3 PASS XNGUSD.DWX and XAUUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime data."
expected_pf: 1.12
expected_dd_pct: 20.0
---

# CME Natural Gas / Gold Ratio Reversion

## Source

- Source: [[sources/CME-GAS-GOLD-RELVAL-2026]]
- Primary citations: CME Group Henry Hub Natural Gas futures overview and CME
  Group Gold futures overview.

## Concept

Natural gas and gold carry different commodity risk premia: natural gas is a
weather, storage, production, and power-burn energy market, while gold is a
monetary and safe-haven metal. This card prices natural gas in gold terms and
tests a market-neutral D1 mean-reversion package when that relative price
reaches an extreme.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, or single-leg pullback.
- `QM5_12577_cme-xauxag-ratio` and `QM5_12724_cme-xauxag-brk`: not a metals
  ratio.
- `QM5_12578_eia-oilgas-ratio`, `QM5_12608_eia-oilgas-breakout`, and
  `QM5_12733_xti-xng-xmom`: no WTI leg and no oil/gas relationship.
- `QM5_12604_cme-oilgold-ratio` and `QM5_12605_cme-oilgold-brk`: the energy leg
  is natural gas rather than WTI crude.
- `QM5_12606_oil-silver-ratio` and `QM5_12797_oil-silver-brk`: no oil or silver.
- Existing XNG single-leg storage, weather, calendar, 52-week anchor, TSMOM,
  weekend, month-opening, and weekday sleeves: this is a two-leg
  natural-gas/gold relative-value basket.

## Markets And Timeframe

- Host symbol: `XNGUSD.DWX`.
- Hedge leg: `XAUUSD.DWX`.
- Logical symbol: `QM5_12824_XNG_XAU_RATIO_D1`.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, broker spread, ATR, and trade-session
  state only. No CME feed, futures curve, inventory feed, weather feed, macro
  CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate once per new D1 bar after the configured broker entry time and only
  when both legs are tradable.
- Compute `spread = ln(XNGUSD.DWX close) - beta * ln(XAUUSD.DWX close)` on prior
  completed D1 bars.
- Compute a rolling z-score over `strategy_z_lookback_d1`.
- Short ratio: if z-score is above `strategy_entry_z`, SELL `XNGUSD.DWX` and
  BUY `XAUUSD.DWX`.
- Long ratio: if z-score is below `-strategy_entry_z`, BUY `XNGUSD.DWX` and
  SELL `XAUUSD.DWX`.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Each leg receives a fixed hard stop at ATR(`strategy_atr_period_d1`) *
  `strategy_atr_sl_mult`.
- Close both legs when absolute spread z-score falls below `strategy_exit_z`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Parameters To Test

- name: strategy_z_lookback_d1
  default: 120
  sweep_range: [90, 120, 180, 252]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.6, 0.8, 1.0, 1.2]
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
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_xng_max_spread_pts
  default: 2500
  sweep_range: [1500, 2500, 3500]
- name: strategy_xau_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]
- name: strategy_entry_hour_broker
  default: 2
  sweep_range: [0, 2, 4]
- name: strategy_entry_minute_broker
  default: 0
  sweep_range: [0]

## Risk

- expected_pf: 1.12.
- expected_dd_pct: 20.
- expected_trade_frequency: approximately 5-10 D1 spread packages/year.
- risk_class: high for natural-gas volatility and broken-correlation shocks.
- gridding: false.
- scalping: false.
- ml_required: false.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and a logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Strategy Allowability Check

- [x] R1 reputable source: official CME product pages for the two futures
  markets represented by the Darwinex legs.
- [x] R2 mechanical: fixed log-ratio z-score entry, fixed mean-reversion exit,
  fixed ATR stops, spread caps, session checks, and broken-package close.
- [x] R3 testable: `XNGUSD.DWX` and `XAUUSD.DWX` exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  two-leg package per magic set.
- [x] Non-duplicate: not existing XAU/XAG, XTI/XNG, oil/gold, oil/silver, XNG
  single-leg, WTI seasonal/event, or commodity-RSI logic.

## Framework Alignment

- no_trade: D1 host guard, `XNGUSD.DWX` slot-0 guard, parameter guard, spread
  caps, both-leg trade-session checks.
- trade_entry: two-leg natural-gas/gold log-ratio z-score extremes.
- trade_management: mean-reversion exit, broken-package close, and Friday close.
- trade_close: hard ATR stop plus deterministic basket exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-30 | initial structural XNG/XAU relative-value basket | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-30 | APPROVED | this card |
| Q02 Baseline Screening | 2026-06-30 | QUEUED | work_item `c5620a63-779d-4e6a-b106-4f28ce91664c` |
