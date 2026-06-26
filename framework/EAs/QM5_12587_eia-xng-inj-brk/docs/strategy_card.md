---
ea_id: QM5_12587
slug: eia-xng-inj-brk
type: strategy
source_id: EIA-XNG-INJECTION-SEASON-2026
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report. URL https://www.eia.gov/naturalgas/storage/"
sources:
  - "[[sources/EIA-XNG-INJECTION-SEASON-2026]]"
concepts:
  - "[[concepts/natural-gas-storage-injection-season]]"
  - "[[concepts/channel-breakdown]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Injection-season XNGUSD.DWX breakdown sleeve; estimate 3-8 D1 trades/year after trend and spread filters."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-26
g0_approval_reasoning: "R1 PASS official EIA natural-gas storage/seasonality lineage; R2 PASS deterministic April-October D1 channel/SMA/ATR short-only rules; R3 PASS XNGUSD.DWX in DWX symbol matrix; R4 PASS no ML/grid/martingale and one magic position."
expected_pf: 1.15
expected_dd_pct: 18.0
---

# EIA XNG Injection Season Breakdown

## Source

- Source: [[sources/EIA-XNG-INJECTION-SEASON-2026]]
- Primary citation: U.S. Energy Information Administration, "Weekly Natural Gas Storage Report", URL https://www.eia.gov/naturalgas/storage/.
- Structural supplement: U.S. Energy Information Administration natural-gas material documenting the seasonal storage/consumption cycle.

## Concept

Natural gas storage normally rebuilds during the April-October injection season,
when the market transitions away from winter withdrawal pressure. This card
does not ingest storage data; it uses the seasonal regime only as a structural
gate and waits for the market's own D1 downside breakdown on `XNGUSD.DWX`.

This is deliberately different from `QM5_12567_cum-rsi2-commodity`, which is a
short-horizon RSI pullback. It is also different from the existing XNG monthly
season map (`QM5_12575`), spring calendar (`QM5_12582`), weekly storage
aftershock (`QM5_12584`), and winter breakout (`QM5_12586`) builds.

## Markets And Timeframe

- Target symbol: XNGUSD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no storage feed, weather feed, futures
  curve, CSV, or external API.

## Entry Rules

- Evaluate only on a new D1 bar.
- Eligible signal months: April, May, June, July, August, September, October.
- Compute prior closed D1 close, SMA(63), ATR(20), and the previous 30-bar
  Donchian low excluding the prior closed signal bar.
- Entry Short: prior D1 close is below the previous channel low and below SMA(63).
- No long entries.
- No entry outside the injection-season window.
- No entry if an open position already exists for the EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(20) * `strategy_atr_sl_mult`.
- Exit Short if the prior D1 close rises above the previous 12-bar channel high.
- Exit Short if the prior D1 close rises above SMA(63).
- Exit any position outside the injection-season window.
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
lineage around the natural-gas storage cycle. The edge claim is tested by the
QM Q02+ pipeline on Darwinex XNGUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA natural-gas storage/seasonality lineage.
- [x] R2 mechanical: fixed injection-season gate, D1 channel/SMA confirmation, ATR stop, deterministic exits.
- [x] R3 testable: XNGUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of QM5_12567: this is not RSI pullback logic.
- [x] No duplicate of QM5_12575/12582/12584/12586: short-only injection breakdown, not monthly map, spring hold, weekly event aftershock, or winter breakout.

## Framework Alignment

- no_trade: D1 and XNGUSD.DWX guard, parameter guard, spread cap.
- trade_entry: April-October injection-season D1 Donchian breakdown plus SMA confirmation.
- trade_management: season expiry, recovery-channel exit, SMA recovery exit, and max-hold exit.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-26 | initial structural XNG injection-season breakdown build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | APPROVED | this card |
