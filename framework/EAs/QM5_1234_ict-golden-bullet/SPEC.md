# QM5_1234 ict-golden-bullet

## Source

- Approved Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1234_ict-golden-bullet.md`
- EA path: `framework/EAs/QM5_1234_ict-golden-bullet/QM5_1234_ict-golden-bullet.mq5`
- Framework: QuantMechanica V5

## Strategy Mapping

- No-Trade: blocks unsupported symbols, wrong slot/timeframe, insufficient history, and invalid parameters.
- Entry: M5-only New York 13:00-13:59 window. Builds the 13:00 reference liquidity from the previous completed H1 candle and the 12:00-12:59 NY M5 range. Requires sweep, return inside liquidity, M5 FVG, spread/volatility/session-quality filters, and one setup attempt per direction per symbol/day.
- Trade Management: removes unfilled limit orders after the 14:00 NY window and cancels a pending order when the last close moves beyond the stop side.
- Close: closes open strategy positions at or after 14:55 New York time.

## Inputs

- `strategy_ny_utc_offset_hours`: default `-4`, used to convert UTC to New York session time. This is explicit because the EA has no dedicated DXZ DST calendar API.
- `strategy_sweep_buffer_points`, `strategy_stop_buffer_points`, `strategy_min_stop_points`
- `strategy_atr_period_m5`, `strategy_max_stop_atr_mult`
- `strategy_min_reward_risk`, `strategy_take_profit_rr`
- `strategy_max_spread_points`, `strategy_max_spread_mult`, `strategy_min_atr_hour_mult`

## Symbol Slots

0. EURUSD.DWX
1. GBPUSD.DWX
2. USDJPY.DWX
3. AUDUSD.DWX
4. USDCAD.DWX
5. NZDUSD.DWX
6. XAUUSD.DWX
7. XTIUSD.DWX
8. NDX.DWX
9. WS30.DWX
10. GDAXI.DWX
11. UK100.DWX

## Validation

- Build-only scope. No backtests or pipeline phases.
- Expected validation commands:
  - `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1234_ict-golden-bullet/QM5_1234_ict-golden-bullet.mq5 -Strict`
  - `framework/scripts/build_check.ps1 -EAPath framework/EAs/QM5_1234_ict-golden-bullet/QM5_1234_ict-golden-bullet.mq5 -Strict`
