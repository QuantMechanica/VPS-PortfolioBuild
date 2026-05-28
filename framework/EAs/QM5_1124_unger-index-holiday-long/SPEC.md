# QM5_1124 Unger Index Holiday Long

## Build Scope

- `ea_id`: 1124
- `slug`: `unger-index-holiday-long`
- Source card: `docs/strategy_card.md`
- Timeframe: D1
- Direction: long only
- Symbols and slots:
  - `0`: `GDAXI.DWX`
  - `1`: `SP500.DWX` backtest-only validation port
  - `2`: `NDX.DWX`
  - `3`: `WS30.DWX`

## Strategy Mapping

### No-Trade

- Blocks symbols outside the card universe.
- Requires current symbol slot to match `qm_magic_slot_offset`.
- Applies a median-spread guard (`strategy_spread_median_mult`, `strategy_spread_lookback`) before new entries.
- Uses standard V5 kill-switch and news hooks.
- Friday close is disabled by default because the card explicitly carries closed-market holiday gap risk.

### Entry

- D1 only.
- Signal day is `strategy_days_before_holiday` trading days before a configured exchange holiday.
- Entry is evaluated at the next trading day's D1 open.
- Long-only market entry.
- Optional trend filter: prior close must be above `SMA(180)` by default.
- Optional month filter: default `3,4,12` for Easter and Christmas families.
- Skip entries where the open gap from prior close exceeds `strategy_gap_skip_stop_mult * planned_stop_distance`.

### Management

- No trailing stop, break-even, scale-in, or partial close in the baseline.

### Close

- Broker SL or TP can close first.
- Default strategy close after `strategy_time_stop_bars = 5` trading bars.
- Variant input `strategy_exit_after_holiday_close = true` closes at the first D1 session close after the holiday.

## Stops And Sizing

- Stop loss: `1.0 * ATR(10, D1)` from entry.
- Take profit: `3.0 * ATR(10, D1)` from entry.
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live default: `RISK_PERCENT=0.25`, `RISK_FIXED=0`.

## Calendar Implementation

Calendar logic is deterministic and in-code for this build:

- German index port (`GDAXI.DWX`): New Year, Good Friday, Easter Monday, Labour Day, German Unity Day, Christmas Eve, Christmas Day, Boxing Day, New Year's Eve.
- US index ports (`SP500.DWX`, `NDX.DWX`, `WS30.DWX`): New Year, MLK Day, Presidents Day, Good Friday, Memorial Day, Juneteenth, Independence Day, Labor Day, Thanksgiving, Christmas.

## Framework Alignment

- Includes `<QM/QM_Common.mqh>`.
- Uses `QM_FrameworkInit`, `QM_FrameworkMagic`, `QM_TM_OpenPosition`, `QM_TM_ClosePosition`, `QM_ATR`, `QM_SMA`, and `QM_StopATRFromValue`.
- Does not compute lots directly.
- Magic numbers are resolved through `QM_MagicResolver`.
- No ML, external market-data API, grid, martingale, or runtime imports.
