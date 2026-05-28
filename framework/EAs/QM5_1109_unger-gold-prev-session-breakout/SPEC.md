# QM5_1109 Unger Gold Previous-Session Breakout

## Scope

Implements the APPROVED card `QM5_1109_unger-gold-prev-session-breakout` as a V5 EA for `XAUUSD.DWX` on `M15`.

## Strategy Mapping

| Card rule | EA implementation |
|---|---|
| Previous defined session high/low | `Strategy_PreviousSessionRange()` scans the latest valid M15 session window. |
| Buy-stop above previous high | `Strategy_EntrySignal()` builds `QM_BUY_STOP` at `prev_high + ATR(14) * buffer_mult`. |
| Sell-stop below previous low | `Strategy_EntrySignal()` returns `QM_SELL_STOP` at `prev_low - ATR(14) * buffer_mult`. |
| First fill cancels opposite pending order | `Strategy_ManageOpenPosition()` cancels remaining stop orders after an open position exists. |
| One trade per day | `g_trade_taken_today` and `g_armed_day_key` prevent re-arming after fill or order placement. |
| Hard SL = 1.5 * ATR(14,M15) | `Strategy_BuildStopRequest()` uses `QM_StopATRFromValue()`. |
| Optional TP = 2.5R, default disabled | `strategy_use_take_profit=false`, `strategy_tp_rr=2.50`. |
| Close before session end | `Strategy_ExitSignal()` closes open positions at `session_end - preclose_flatten_minutes`. |
| Cancel unfilled orders outside window | `Strategy_ManageOpenPosition()` cancels pending stops outside session/pre-close. |
| Skip small previous-session ranges | `Strategy_RangeAllowsEntry()` requires previous range >= median range * `strategy_min_range_median_mult`. |
| Standard V5 news/risk/friday close | Framework `QM_FrameworkInit`, news 2-axis inputs, and Friday close wiring retained. |

## Inputs

Defaults are the card baseline unless noted:

| Input | Default | Purpose |
|---|---:|---|
| `qm_ea_id` | `1109` | Allocated V5 EA ID. |
| `qm_magic_slot_offset` | `0` | XAUUSD.DWX magic slot. |
| `RISK_FIXED` | `1000.0` | Backtest fixed USD risk. |
| `RISK_PERCENT` | `0.0` | Disabled in backtest set. |
| `strategy_session_start_hour` | `8` | Broker-time session start. |
| `strategy_session_end_hour` | `22` | Broker-time session end. |
| `strategy_preclose_flatten_minutes` | `15` | Mandatory pre-session-end flatten. |
| `strategy_atr_period` | `14` | M15 ATR period. |
| `strategy_entry_buffer_atr_mult` | `0.10` | Entry buffer. P3 candidates: 0, 0.05, 0.10, 0.20. |
| `strategy_sl_atr_mult` | `1.50` | Hard stop distance. |
| `strategy_use_take_profit` | `false` | Card default: TP disabled for first build. |
| `strategy_tp_rr` | `2.50` | Optional TP R multiple. |
| `strategy_range_median_sessions` | `20` | Range-regime median sample. |
| `strategy_min_range_median_mult` | `0.50` | Minimum previous-session range threshold. |
| `strategy_spread_median_days` | `20` | Spread median sample. |
| `strategy_spread_max_median_mult` | `2.00` | Spread cap versus median. |

## Build Boundary

This is a build-only implementation. No backtests or pipeline phases are run from this EA folder.
