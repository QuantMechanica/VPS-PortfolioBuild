---
ea_id: QM5_12586
slug: eia-xng-winter-brk
type: strategy
source_id: EIA-XNG-WINTER-WITHDRAWAL-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report. URL https://www.eia.gov/naturalgas/storage/"
sources:
  - "[[sources/EIA-XNG-WINTER-WITHDRAWAL-2026]]"
concepts:
  - "[[concepts/natural-gas-storage-withdrawal-season]]"
  - "[[concepts/winter-heating-demand]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Winter withdrawal-season XNGUSD.DWX channel breakout; estimate 4-9 D1 trades/year after trend and spread filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA natural-gas storage/heating-demand lineage; R2 PASS deterministic D1 winter-window channel/SMA/ATR rules; R3 PASS XNGUSD.DWX in DWX symbol matrix; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.15
expected_dd_pct: 18.0
---

# EIA XNG Winter Withdrawal Breakout

## Source

- Source: [[sources/EIA-XNG-WINTER-WITHDRAWAL-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Natural Gas Storage Report", URL https://www.eia.gov/naturalgas/storage/.
- Structural supplement: U.S. Energy Information Administration natural-gas consumer/use material documenting weather-sensitive heating demand.

## Concept

Natural gas has a recurring winter withdrawal regime because heating demand
draws down stored gas and weather surprises can force directional repricing.
This card converts that structural winter stress period into a low-frequency
`XNGUSD.DWX` sleeve: trade only during November-March, require a D1 channel
breakout plus SMA confirmation, and flatten on opposite-channel failure, season
expiry, or time exit.

This is deliberately different from `QM5_12567_cum-rsi2-commodity`, which is a
short-horizon RSI pullback. It is also different from the existing XNG EIA
season map (`QM5_12575`), spring calendar (`QM5_12582`), and weekly storage
aftershock (`QM5_12584`) builds.

## Markets And Timeframe

- Target symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no weather feed, storage feed, futures
  curve, CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Eligible signal months: November, December, January, February, March.
- Compute prior closed D1 close, SMA(63), ATR(20), and the previous 30-bar
  Donchian high/low excluding the prior closed signal bar.
- Entry Long: prior D1 close is above the previous channel high and above SMA(63).
- Entry Short: prior D1 close is below the previous channel low and below SMA(63).
- No entry outside the winter withdrawal window.
- No entry if an open position already exists for the EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * `strategy_atr_sl_mult`.
- Exit Long if the prior D1 close falls below the previous 12-bar channel low.
- Exit Short if the prior D1 close rises above the previous 12-bar channel high.
- Exit any position outside the winter withdrawal window.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XNGUSD.DWX on D1.
- Skip entries when SMA, ATR, or channel values are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_channel
  default: 30
  sweep_range: [20, 30, 45, 55]
- name: strategy_exit_channel
  default: 12
  sweep_range: [8, 12, 20]
- name: strategy_trend_period
  default: 63
  sweep_range: [42, 63, 84, 126]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 5.0]
- name: strategy_max_hold_days
  default: 12
  sweep_range: [7, 12, 21]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is taken from EIA. EIA is used only for official structural
lineage around natural-gas storage and weather-sensitive winter demand. The edge
claim is tested by the QM Q02+ pipeline on Darwinex XNGUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-9 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA natural-gas storage/heating-demand lineage.
- [x] R2 mechanical: fixed winter calendar gate, D1 channel/SMA confirmation, ATR stop, deterministic exits.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.
- [x] No duplicate of QM5_12575/12582/12584: winter channel breakout, not monthly map, spring hold, or weekly event aftershock.

## Framework Alignment

- no_trade: D1 and XNGUSD.DWX guard, parameter guard, spread cap.
- trade_entry: winter withdrawal-window D1 Donchian breakout plus SMA confirmation.
- trade_management: season expiry, opposite-channel exit, and max-hold exit.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-26 | initial structural XNG winter withdrawal breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
