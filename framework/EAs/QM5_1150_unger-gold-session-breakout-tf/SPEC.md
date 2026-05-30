# QM5_1150 Unger Gold Session Breakout TF

## Scope

Implements the APPROVED card `QM5_1150_unger-gold-session-breakout-tf` as a V5 EA for `XAUUSD.DWX` on `M15`.

## Strategy Mapping

| Card rule | EA implementation |
|---|---|
| Gold reference session current high/low | `ComputeCurrentSessionRange()` reads M15 bars from the configured New York session open through `RANGE_BUILD_END`. |
| Buy-stop above session high | `BuildStopPair()` places `QM_BUY_STOP` at range high plus `ATR(14,M15) * strategy_entry_buffer_atr_mult`. |
| Sell-stop below session low | `BuildStopPair()` places `QM_SELL_STOP` at range low minus the same ATR buffer. |
| First fill cancels opposite order | `Strategy_ManageOpenPosition()` cancels remaining pending orders after a strategy position exists. |
| One trade per day | `g_last_order_day` prevents re-arming once orders were placed for the broker day. |
| Cancel unfilled orders after entry cutoff | `Strategy_ManageOpenPosition()` removes pending orders at the configured cutoff. |
| SL = 1.5 * ATR(14,M15) | `QM_StopATRFromValue()` is called with `strategy_sl_atr_mult`. |
| TP = 2.0 * ATR(14,M15) | `QM_StopRulesTakeFromDistance()` uses `strategy_tp_atr_mult`. |
| Flatten before session end | `Strategy_ExitSignal()` closes open positions at session end minus `strategy_preclose_flatten_minutes`. |
| Daily ATR range filter | `RangeAllowsEntry()` rejects range builds below `0.4 * ATR(14,D1)` or above `1.5 * ATR(14,D1)`. |
| Skip FOMC/CPI release days | The default news mode uses high-impact skip-day behavior with DXZ compliance. |

## Inputs

Defaults are the card baseline unless noted:

| Input | Default | Purpose |
|---|---:|---|
| `qm_ea_id` | `1150` | Allocated V5 EA ID. |
| `qm_magic_slot_offset` | `0` | XAUUSD.DWX magic slot. |
| `RISK_FIXED` | `1000.0` | Backtest fixed USD risk. |
| `RISK_PERCENT` | `0.0` | Disabled in the EA default and enabled by live setfiles. |
| `strategy_session_start_hour_ny` | `8` | Gold reference session open in New York time. |
| `strategy_range_build_end_hour_ny` | `10` | Range build end in New York time. |
| `strategy_entry_cutoff_hour_ny` | `14` | Unfilled-order cutoff in New York time. |
| `strategy_session_end_hour_ny` | `16` | Reference session end in New York time. |
| `strategy_preclose_flatten_minutes` | `5` | Flatten buffer before session end. |
| `strategy_atr_period` | `14` | M15 ATR period. |
| `strategy_entry_buffer_atr_mult` | `0.05` | Entry buffer as ATR multiple. |
| `strategy_sl_atr_mult` | `1.50` | Stop-loss ATR multiple. |
| `strategy_tp_atr_mult` | `2.00` | Take-profit ATR multiple. |
| `strategy_daily_atr_period` | `14` | D1 ATR period for range filter. |
| `strategy_min_range_daily_atr_mult` | `0.40` | Minimum range filter. |
| `strategy_max_range_daily_atr_mult` | `1.50` | Maximum range filter. |
| `strategy_max_spread_points` | `250` | Spread cap before placing stops. |

## Build Boundary

This is a build-only implementation. No backtests or pipeline phases are run from this EA folder.
