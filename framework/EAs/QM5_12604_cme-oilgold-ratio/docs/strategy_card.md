---
ea_id: QM5_12604
slug: cme-oilgold-ratio
type: strategy
source_id: CME-OIL-GOLD-RATIO-2024
source_citation: "CME Group. Through the Lens of Gold. 2024. URL https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html"
sources:
  - "[[sources/CME-OIL-GOLD-RATIO-2024]]"
concepts:
  - "[[concepts/oil-gold-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-zscore, market-neutral-basket, atr-hard-stop, mean-reversion-exit, low-frequency]
target_symbols: [XTIUSD.DWX, XAUUSD.DWX]
logical_symbol: QM5_12604_XTI_XAU_RATIO_D1
period: D1
expected_trade_frequency: "D1 oil/gold ratio z-score basket; estimate 6-12 spread packages/year."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS CME exchange source; R2 PASS deterministic D1 oil/gold log-ratio z-score basket; R3 PASS XTIUSD.DWX and XAUUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.15
expected_dd_pct: 18.0
---

# CME Oil/Gold Ratio Reversion

## Source

- Source: [[sources/CME-OIL-GOLD-RATIO-2024]]
- Primary citation: CME Group, "Through the Lens of Gold", 2024, URL
  https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html.

## Concept

The oil/gold ratio expresses crude oil value in monetary-metal terms instead of
as an outright WTI direction call. Oil carries energy-growth and supply-shock
exposure, while gold carries monetary and safe-haven exposure. This card trades
extreme deviations in that relative price as a two-leg basket and exits when the
ratio mean-reverts.

This is deliberately different from the certified book's outright XAU sleeve,
the existing XNG sleeve, the `QM5_12577` XAU/XAG metals ratio, the `QM5_12578`
XTI/XNG energy ratio, and `QM5_12567_cum-rsi2-commodity`, which is an RSI
pullback port. This card uses no RSI and never holds a standalone WTI or gold
leg intentionally.

## Markets And Timeframe

- Host symbol: XTIUSD.DWX.
- Basket leg symbols: XTIUSD.DWX and XAUUSD.DWX.
- Logical symbol: QM5_12604_XTI_XAU_RATIO_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no CME feed, futures curve, inventory
  feed, macro CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(XAUUSD.DWX close)` on prior
  closed D1 bars.
- Compute a rolling z-score of the spread over `strategy_z_lookback_d1`.
- Entry Short Ratio: if z-score is above `strategy_entry_z`, SELL XTIUSD.DWX and
  BUY XAUUSD.DWX.
- Entry Long Ratio: if z-score is below `-strategy_entry_z`, BUY XTIUSD.DWX and
  SELL XAUUSD.DWX.
- The daily entry attempt is delayed until `strategy_entry_hour_broker` /
  `strategy_entry_minute_broker` and both basket legs report an open trade
  session, so the XTI leg is not opened before XAUUSD.DWX is tradable.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

## Exit Rules

- Stop loss: each leg receives a fixed hard SL at ATR(`strategy_atr_period_d1`)
  * `strategy_atr_sl_mult` from entry.
- Exit both legs when absolute spread z-score falls below `strategy_exit_z`.
- If only one basket leg is open, close it immediately as a broken package.
- Friday close remains enabled by the V5 framework and closes both basket legs.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- Skip entries when XTI spread exceeds `strategy_xti_max_spread_pts`.
- Skip entries when XAU spread exceeds `strategy_xau_max_spread_pts`.
- Skip entries before the configured broker entry time or while either basket
  leg is outside its trade session.
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
- name: strategy_xti_max_spread_pts
  default: 1000
  sweep_range: [700, 1000, 1500]
- name: strategy_xau_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_deviation_points
  default: 20
  sweep_range: [10, 20, 50]
- name: strategy_entry_hour_broker
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_entry_minute_broker
  default: 0
  sweep_range: [0]

## Author Claims

No performance claim is imported from the CME source. The source is used only
for structural lineage around viewing crude oil through gold as a relative-value
ratio.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-12 spread packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: CME exchange article with single-source lineage.
- [x] R2 mechanical: fixed log-ratio z-score entry/exit and ATR stops.
- [x] R3 testable: XTIUSD.DWX and XAUUSD.DWX exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] Non-duplicate: not the existing XAU/XAG, XTI/XNG, XNG, WTI calendar/news,
  or RSI commodity logic.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: two-leg basket entry on oil/gold log-ratio z-score extremes.
- trade_management: none beyond per-leg ATR stops.
- trade_close: package repair and ratio z-score reversion exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v2 | 2026-06-28 | delayed daily entry until XAU trade session is open | Q04 repair | pending |
| v1 | 2026-06-27 | initial structural XTI/XAU oil/gold ratio basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
