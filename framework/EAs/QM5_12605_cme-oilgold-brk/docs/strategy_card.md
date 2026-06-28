---
ea_id: QM5_12605
slug: cme-oilgold-brk
type: strategy
source_id: CME-OIL-GOLD-RATIO-2024
source_citation: "CME Group. Through the Lens of Gold. 2024. URL https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html"
sources:
  - "[[sources/CME-OIL-GOLD-RATIO-2024]]"
concepts:
  - "[[concepts/oil-gold-ratio]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-breakout, market-neutral-basket, atr-hard-stop, channel-exit, low-frequency]
target_symbols: [XTIUSD.DWX, XAUUSD.DWX]
logical_symbol: QM5_12605_XTI_XAU_BRK_D1
period: D1
expected_trade_frequency: "D1 oil/gold ratio channel-breakout basket; estimate 4-10 spread packages/year."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS CME exchange source; R2 PASS deterministic D1 oil/gold ratio breakout and channel exit; R3 PASS XTIUSD.DWX and XAUUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 20.0
---

# CME Oil/Gold Ratio Breakout

## Source

- Source: [[sources/CME-OIL-GOLD-RATIO-2024]]
- Primary citation: CME Group, "Through the Lens of Gold", 2024, URL
  https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html.

## Concept

The oil/gold ratio expresses crude oil value in monetary-metal terms instead of
as an outright WTI direction call. This card trades sustained ratio expansion
or compression as a market-neutral breakout package: long oil/short gold when
the ratio breaks above its long D1 channel, and short oil/long gold when it
breaks below.

This is deliberately different from `QM5_12604_cme-oilgold-ratio`, which is a
z-score mean-reversion rule on the same economic pair. This card is a channel
continuation rule with channel exits. It is also not the XAU/XAG metals ratio,
the XTI/XNG energy ratio, any standalone WTI calendar/news sleeve, or the
`QM5_12567` RSI commodity pullback port.

## Markets And Timeframe

- Host symbol: XTIUSD.DWX.
- Basket leg symbols: XTIUSD.DWX and XAUUSD.DWX.
- Logical symbol: QM5_12605_XTI_XAU_BRK_D1.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no CME feed, futures curve, inventory
  feed, macro CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Compute `spread = ln(XTIUSD.DWX close) - beta * ln(XAUUSD.DWX close)` on prior
  closed D1 bars.
- Compute the highest and lowest spread over `strategy_entry_lookback_d1`,
  excluding the most recent closed spread.
- Entry Long Ratio: if the most recent closed spread is above the entry-channel
  high, BUY XTIUSD.DWX and SELL XAUUSD.DWX.
- Entry Short Ratio: if the most recent closed spread is below the entry-channel
  low, SELL XTIUSD.DWX and BUY XAUUSD.DWX.
- The daily entry attempt is delayed until `strategy_entry_hour_broker` /
  `strategy_entry_minute_broker` and both basket legs report an open trade
  session, so the XTI leg is not opened before XAUUSD.DWX is tradable.
- No entry if either basket leg already has an open position for this EA magic.
- No entry if either symbol's current spread exceeds its configured spread cap.

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

- expected_pf: 1.12
- expected_dd_pct: 20
- expected_trade_frequency: approximately 4-10 spread packages/year.
- risk_class: high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: CME exchange article with single-source lineage.
- [x] R2 mechanical: fixed log-ratio channel breakout, channel exit, and ATR stops.
- [x] R3 testable: XTIUSD.DWX and XAUUSD.DWX exist in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] Non-duplicate: not the existing oil/gold z-score reversion, XAU/XAG,
  XTI/XNG, XNG, WTI calendar/news, or RSI commodity logic.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: two-leg basket entry on oil/gold ratio channel breakout.
- trade_management: none beyond per-leg ATR stops.
- trade_close: package repair and channel-exit reversal.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v2 | 2026-06-28 | delayed daily entry until XAU trade session is open | Q04 repair | pending |
| v1 | 2026-06-27 | initial structural XTI/XAU oil/gold ratio breakout basket build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
