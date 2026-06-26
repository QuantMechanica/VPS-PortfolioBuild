---
ea_id: QM5_12577
slug: cme-xauxag-ratio
type: strategy
source_id: CME-GSR-SPREAD-2025
source_citation: "CME Group. Gold & Silver Ratio Spread. URL https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade"
sources:
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts:
  - "[[concepts/gold-silver-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_12577_XAU_XAG_RATIO_D1
period: D1
expected_trade_frequency: "D1 gold-silver ratio z-score basket; estimate 8-16 spread packages/year."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS CME exchange source; R2 PASS deterministic D1 XAU/XAG log-ratio z-score basket; R3 PASS XAUUSD.DWX and XAGUSD.DWX available; R4 PASS no ML/grid/martingale."
expected_pf: 1.2
expected_dd_pct: 16.0
---

# CME XAU/XAG Ratio Reversion

## Source

- Source: [[sources/CME-GSR-SPREAD-2025]]
- Primary citation: CME Group, "Gold & Silver Ratio Spread", URL https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade.
- Supplement: CME Group, "Spread Trading Opportunities with Precious Metals", URL https://www.cmegroup.com/education/articles-and-reports/spread-trading-opportunities-with-precious-metals.
- Supplement: CME Group, "Four Major Drivers of the Gold-Silver Price Ratio", URL https://www.cmegroup.com/insights/economic-research/2025/four-major-drivers-of-the-gold-silver-price-ratio.html.

## Concept

The gold-silver ratio is a structural precious-metals spread rather than a single
outright metal signal. Gold and silver share precious-metals beta, but their
drivers differ: gold is more monetary/safe-haven, while silver has more
industrial-cycle exposure. This card trades extreme deviations in the ratio as a
two-leg market-neutral basket and exits when the ratio mean-reverts.

This is deliberately different from the certified book's XAU outright sleeves
and from `QM5_12567_cum-rsi2-commodity`, which is a short-horizon RSI pullback
port across commodities. This card uses no RSI and never trades a standalone
metal leg.

## Markets And Timeframe

- Host symbol: XAUUSD.DWX.
- Basket leg symbols: XAUUSD.DWX and XAGUSD.DWX.
- Logical symbol: QM5_12577_XAU_XAG_RATIO_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no CME feed, futures curve, inventory feed, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XAUUSD.DWX close) - beta * ln(XAGUSD.DWX close)` on prior closed D1 bars.
- Compute a rolling z-score of the spread over `strategy_z_lookback_d1`.
- Entry Short Ratio: if z-score is above `strategy_entry_z`, SELL XAUUSD.DWX and BUY XAGUSD.DWX.
- Entry Long Ratio: if z-score is below `-strategy_entry_z`, BUY XAUUSD.DWX and SELL XAGUSD.DWX.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(20) * 2.5 from entry.
- Exit both legs when absolute spread z-score falls below `strategy_exit_z`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be XAUUSD.DWX on D1.
- Skip entries when XAU spread exceeds 500 points or XAG spread exceeds 200 points.
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
  default: 90
  sweep_range: [60, 90, 120, 180]
- name: strategy_beta
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
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
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0, 3.5]

## Author Claims

No performance claim is taken from CME sources. The sources are used only for
structural lineage: gold-silver ratio definition, spread tradability, and
differentiated gold/silver macro drivers.

## Initial Risk Profile

- expected_pf: 1.20
- expected_dd_pct: 16
- expected_trade_frequency: approximately 8-16 spread packages/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: CME exchange education/research URLs.
- [x] R2 mechanical: fixed log-ratio z-score entry/exit and ATR stops.
- [x] R3 testable: XAUUSD.DWX and XAGUSD.DWX exist in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.

## Framework Alignment

- no_trade: host chart guard, D1 guard, spread caps.
- trade_entry: two-leg basket entry on gold-silver log-ratio z-score extremes.
- trade_management: none beyond per-leg ATR stops.
- trade_close: package repair and ratio z-score reversion exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XAU/XAG ratio basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
