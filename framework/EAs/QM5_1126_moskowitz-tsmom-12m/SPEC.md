# QM5_1126 moskowitz-tsmom-12m

## Strategy Card

- Source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1126_moskowitz-tsmom-12m.md`
- Status: APPROVED
- Framework: QuantMechanica V5
- Pipeline phase: build-only, no backtests executed

## Mechanics

- Universe: `GDAXI.DWX`, `NDX.DWX`, `UK100.DWX`, `WS30.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `XAUUSD.DWX`
- Timeframe: D1
- Rebalance: first D1 trading session of each calendar month, detected by month change between the latest closed D1 bar and the active D1 bar
- Signal: `r12 = Close[21] / Close[252] - 1`
- Entry: long when `r12 > threshold`, short when `r12 < -threshold`, flat otherwise
- Exit: on monthly rebalance when the signal turns flat or flips direction
- Stop: ATR(D1,14) * 3.0 hard stop
- Take profit: none
- Trade management: no trailing, break-even, pyramiding, or partial close

## V5 Mapping

- No-Trade: V5 framework kill switch, news gate, Friday close, symbol/timeframe guard, and spread guard
- Entry: `Strategy_EntrySignal`
- Management: `Strategy_ManageOpenPosition`
- Close: `Strategy_ExitSignal`
- Magic: `QM_FrameworkMagic()` with per-symbol `qm_magic_slot_offset`

## Defaults

- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Live risk: `RISK_PERCENT=0.25`, `RISK_FIXED=0`
- News: disabled by default
- Friday close: enabled by default

## Validation

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings
- `build_check.ps1 -Strict`: PASS, 0 failures, 0 warnings
