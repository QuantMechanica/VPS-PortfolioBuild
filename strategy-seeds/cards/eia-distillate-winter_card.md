---
ea_id: QM5_12583
slug: eia-distillate-winter
type: strategy
source_id: EIA-WTI-SEASON-2024
source_citation: "U.S. Energy Information Administration petroleum seasonality sources captured under EIA-WTI-SEASON-2024."
sources:
  - "[[sources/EIA-WTI-SEASON-2024]]"
concepts:
  - "[[concepts/distillate-seasonality]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12583_XTI_DISTILLATE_WINTER_D1
period: D1
expected_trade_frequency: "D1 WTI winter distillate-demand breakout sleeve; estimate 3-7 trades/year under Friday-close segmentation."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA petroleum seasonality source; R2 PASS deterministic winter date window with channel breakout/ATR exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# EIA Distillate Winter Breakout

## Source

- Source: [[sources/EIA-WTI-SEASON-2024]]
- Primary citation: U.S. Energy Information Administration petroleum seasonality source packet captured under `EIA-WTI-SEASON-2024`.

## Concept

Crude oil has multiple petroleum-demand seasonal components. `QM5_12576` uses
a broad monthly WTI season map with SMA and momentum confirmation. This card
extracts a narrower distillate/heating-season sleeve: trade only upside WTI D1
breakouts during the winter petroleum-demand window, then flatten outside that
window.

Runtime data stays Darwinex MT5 OHLC-only. The EA does not read EIA inventory,
weather, refinery, futures-spread, or external data at runtime.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: broad monthly two-sided WTI SMA/ROC seasonality.
- `QM5_12579_eia-wti-aftershock`: post-WPSR event-day aftershock continuation.
- `QM5_12567_cum-rsi2-commodity`: short-horizon cumulative RSI pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Eligible calendar window: November 1 through February 15, inclusive.
- Long only.
- Skip if an open XTIUSD.DWX position already exists for this EA magic.
- Skip if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.
- Entry: BUY XTIUSD.DWX when the prior closed D1 close breaks above the highest high of the previous `strategy_entry_channel` completed D1 bars.
- The V5 Friday-close guard remains enabled; re-entry is allowed during the same winter window if Friday close flattened the position and the breakout condition is again true.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit when the current date is outside the winter window.
- Exit when prior closed D1 close breaks below the lowest low of the previous `strategy_exit_channel` completed bars.
- Exit when the position has been held for more than `strategy_max_hold_days`.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XTIUSD.DWX on D1.
- No short entries.
- No pyramiding, grid, martingale, partial close, or trailing stop.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_entry_channel
  default: 20
  sweep_range: [15, 20, 30, 40]
- name: strategy_exit_channel
  default: 10
  sweep_range: [7, 10, 15, 20]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0, 5.0]
- name: strategy_max_hold_days
  default: 15
  sweep_range: [10, 15, 25]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from EIA. The source provides structural
lineage for petroleum demand seasonality only.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 3-7 entries/year under Friday-close segmentation.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA source packet.
- [x] R2 mechanical: fixed date window, channel breakout entry, channel/date/time exits, ATR stop.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.

## Framework Alignment

- no_trade: D1/XTIUSD.DWX guard, date-window gate, spread cap.
- trade_entry: winter distillate-demand long breakout.
- trade_management: date-window/channel/time exits.
- trade_close: framework Friday close plus strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial XTI distillate winter breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
