---
ea_id: QM5_12724
slug: cme-xauxag-brk
type: strategy
source_id: CME-GSR-SPREAD-2025
source_citation: "CME Group. Gold & Silver Ratio Spread. URL https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade"
sources:
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts:
  - "[[concepts/gold-silver-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-breakout, market-neutral-basket, atr-hard-stop, channel-exit, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_12724_XAU_XAG_BRK_D1
period: D1
expected_trade_frequency: "D1 gold/silver ratio channel-breakout basket; estimate 4-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS CME exchange source; R2 PASS deterministic D1 gold/silver ratio breakout and channel exit; R3 PASS XAUUSD.DWX and XAGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# CME XAU/XAG Ratio Breakout

## Source

- Source: [[sources/CME-GSR-SPREAD-2025]]
- Primary citation: CME Group, "Gold & Silver Ratio Spread", URL https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.
- Supplement: CME Group, "Spread Trading Opportunities with Precious Metals", URL https://www.cmegroup.com/education/articles-and-reports/spread-trading-opportunities-with-precious-metals.
- Supplement: CME Group, "Four Major Drivers of the Gold-Silver Price Ratio", URL https://www.cmegroup.com/insights/economic-research/2025/four-major-drivers-of-the-gold-silver-price-ratio.html.

## Concept

The gold-silver ratio is a structural precious-metals spread rather than an
outright metals direction call. CME documents the ratio and the tradability of
gold/silver spread packages, while also noting that gold and silver have
different macro drivers: gold is more monetary and safe-haven sensitive, while
silver carries more industrial-cycle exposure.

This card trades sustained ratio expansion or compression as a market-neutral
breakout package: long gold/short silver when the ratio breaks above its long
D1 channel, and short gold/long silver when it breaks below. It is deliberately
different from `QM5_12577_cme-xauxag-ratio`, which fades z-score extremes and
exits on mean reversion. This card uses channel continuation and channel exits.

## hypothesis

If gold and silver begin diverging strongly enough to push their D1 log ratio
outside a long channel, the driver mix behind monetary gold and industrial
silver can persist long enough for a multi-week continuation move. Trading both
legs reduces dependence on standalone XAU direction and creates a logical
spread sleeve rather than another outright metal entry.

This is deliberately different from:

- `QM5_12577_cme-xauxag-ratio`: this card follows D1 channel breakouts; 12577
  fades z-score extremes and exits on mean reversion.
- `QM5_12604`, `QM5_12605`, and `QM5_12606`: not oil/gold or oil/silver.
- `QM5_12608`: not XTI/XNG energy ratio logic.
- WTI/XNG seasonal and event sleeves: no calendar, weather, inventory, or
  energy-event trigger.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Host symbol: XAUUSD.DWX.
- Basket leg symbols: XAUUSD.DWX and XAGUSD.DWX.
- Logical symbol: QM5_12724_XAU_XAG_BRK_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no CME feed, futures curve, inventory
  feed, macro CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XAUUSD.DWX close) - beta * ln(XAGUSD.DWX close)` on
  prior closed D1 bars.
- Compute the highest and lowest spread over `strategy_entry_lookback_d1`,
  excluding the most recent closed spread.
- Entry Long Ratio: if the most recent closed spread is above the entry-channel
  high, BUY XAUUSD.DWX and SELL XAGUSD.DWX.
- Entry Short Ratio: if the most recent closed spread is below the entry-channel
  low, SELL XAUUSD.DWX and BUY XAGUSD.DWX.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## rules

- Signal series: `ln(XAUUSD.DWX) - strategy_beta * ln(XAGUSD.DWX)`.
- Entry channel excludes the most recent closed spread.
- Upside channel break opens BUY XAUUSD.DWX plus SELL XAGUSD.DWX.
- Downside channel break opens SELL XAUUSD.DWX plus BUY XAGUSD.DWX.
- Exit channel, broken-package repair, Friday close, and ATR hard stops are
  deterministic and use MT5-native data only.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  * `strategy_atr_sl_mult` from entry.
- For a long-ratio package, exit both legs when the most recent closed spread
  falls below the `strategy_exit_lookback_d1` channel low.
- For a short-ratio package, exit both legs when the most recent closed spread
  rises above the `strategy_exit_lookback_d1` channel high.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be XAUUSD.DWX on D1.
- Skip entries when XAU spread exceeds `strategy_xau_max_spread_pts`.
- Skip entries when XAG spread exceeds `strategy_xag_max_spread_pts`.
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

- name: strategy_entry_lookback_d1
  default: 120
  sweep_range: [90, 120, 180, 252]
- name: strategy_exit_lookback_d1
  default: 40
  sweep_range: [20, 40, 60]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.6, 0.8, 1.0, 1.2]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_xau_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_xag_max_spread_pts
  default: 200
  sweep_range: [100, 200, 400]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]

## Author Claims

No performance claim is imported from CME sources. The sources are used only for
structural lineage around the gold-silver ratio, spread tradability, and the
different macro drivers of gold and silver.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-10 spread packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical basket
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, or the portfolio gate.

## Strategy Allowability Check

- [x] R1 reputable source: CME exchange education/research URLs.
- [x] R2 mechanical: fixed log-ratio channel breakout, channel exit, and ATR stops.
- [x] R3 testable: XAUUSD.DWX and XAGUSD.DWX exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] Non-duplicate: not the existing XAU/XAG z-score reversion basket,
  oil/gold, oil/silver, XTI/XNG, XNG, WTI calendar/news, or RSI commodity logic.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: two-leg basket entry on gold/silver ratio channel breakout.
- trade_management: none beyond per-leg ATR stops.
- trade_close: package repair and channel-exit reversal.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural XAU/XAG gold-silver ratio breakout basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
