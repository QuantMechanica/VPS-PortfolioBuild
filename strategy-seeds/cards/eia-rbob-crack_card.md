---
ea_id: QM5_12581
slug: eia-rbob-crack
type: strategy
source_id: EIA-RBOB-CRACK-SEASON-2025
source_citation: "U.S. Energy Information Administration. Gasoline crack spreads rise ahead of the summer driving season. This Week in Petroleum, 2025-03-12. URL https://www.eia.gov/petroleum/weekly/archive/2025/250312/includes/analysis_print.php"
sources:
  - "[[sources/EIA-RBOB-CRACK-SEASON-2025]]"
concepts:
  - "[[concepts/gasoline-crack-spread]]"
  - "[[concepts/energy-seasonality]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_12581_XTI_RBOB_CRACK_D1
period: D1
expected_trade_frequency: "D1 WTI breakout sleeve restricted to gasoline crack-spread windows; estimate 3-8 trades/year."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA source; R2 PASS deterministic D1 seasonal channel breakout/exit rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.15
expected_dd_pct: 18.0
---

# EIA RBOB Crack Spread Seasonal Breakout

## Source

- Source: [[sources/EIA-RBOB-CRACK-SEASON-2025]]
- Primary citation: U.S. Energy Information Administration, "Gasoline crack spreads rise ahead of the summer driving season", This Week in Petroleum, March 12, 2025.

## Concept

EIA describes gasoline crack spreads as a proxy for refinery margins between
crude oil and finished gasoline. The article documents a seasonal structure:
RBOB gasoline crack spreads often rise in March as refiners prepare for
summer-grade gasoline, remain supported during the summer driving season, and
fall after the September 1 switch to winter-grade gasoline.

This card converts that structural gasoline-demand/refiner-margin setup into a
low-frequency XTIUSD.DWX sleeve. Runtime data stays Darwinex MT5 OHLC-only:
the EA trades WTI D1 breakouts only during crack-spread support/decline windows.
It does not read external EIA, RBOB, refinery, inventory, or futures-spread data.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: monthly WTI SMA/ROC seasonality with winter and summer long windows.
- `QM5_12579_eia-wti-aftershock`: post-WPSR event-day aftershock continuation.
- `QM5_12567_cum-rsi2-commodity`: short-horizon RSI pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Skip if an open XTIUSD.DWX position already exists for this EA magic.
- Skip if the XTIUSD.DWX spread exceeds `strategy_max_spread_points`.
- Long regime: March through August.
- Short regime: September through October.
- Long entry: during the long regime, BUY XTIUSD.DWX when the prior closed D1 close breaks above the highest high of the previous `strategy_entry_channel` completed D1 bars.
- Short entry: during the short regime, SELL XTIUSD.DWX when the prior closed D1 close breaks below the lowest low of the previous `strategy_entry_channel` completed D1 bars.
- No trade in all other months.

## Exit Rules

- Stop loss: ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Long exit: close if the active month leaves the long regime, if prior close breaks below the lowest low of the previous `strategy_exit_channel` completed bars, or if max hold days is exceeded.
- Short exit: close if the active month leaves the short regime, if prior close breaks above the highest high of the previous `strategy_exit_channel` completed bars, or if max hold days is exceeded.
- Friday close remains enabled by the V5 framework.

## Filters

- Host chart must be XTIUSD.DWX on D1.
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
  default: 70
  sweep_range: [45, 70, 95]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from the EIA source. The source is used only for
structural lineage: gasoline crack-spread definition and seasonality.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official EIA This Week in Petroleum source.
- [x] R2 mechanical: fixed month windows, channel breakout entries, channel/time exits, ATR stop.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.

## Framework Alignment

- no_trade: D1/XTIUSD.DWX guard and spread cap.
- trade_entry: D1 crack-spread seasonal channel breakout.
- trade_management: channel/time exits.
- trade_close: framework Friday close and strategy channel/time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XTI gasoline crack-spread seasonal breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
