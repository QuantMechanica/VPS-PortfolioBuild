# QM5_1115_qp-lunch-sp500 SPEC

## Identity
- EA: `QM5_1115_qp-lunch-sp500`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1115_qp-lunch-sp500.md`
- Symbol: `SP500.DWX`
- Timeframes: `M15`, `H1`
- Magic slot: `0`

## Strategy Mapping
- No-Trade: blocks non-`SP500.DWX`, non-`M15/H1`, weekends, configured US cash holidays, common early-close days, and spread above `3x` median H1 spread over the prior 20 days.
- Entry: short at 11:00 New York time; long at 12:00 New York time after the short has been closed.
- Management: none beyond broker hard stop.
- Close: close short at/after 12:00 New York time; close long at/after 14:00 New York time, with a 14:05 safety condition retained.

## Risk And Stops
- Backtest default: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live default setfile: `RISK_PERCENT=0.25`, `RISK_FIXED=0`.
- Stop: H1 ATR(14) * 1.5 from leg entry.
- Take-profit: none in card, so no TP is placed.

## Framework Alignment
- Includes only `<QM/QM_Common.mqh>`.
- Uses `QM_FrameworkInit`, `QM_TM_ClosePosition`, `QM_TM_OpenPosition`, `QM_ATR`, `QM_StopATRFromValue`, and `QM_MagicChecked` via framework wiring.
- Uses Darwinex `.DWX` symbol discipline. No deploy-time symbol stripping is implemented in the EA.
- No ML, no WebRequest, no grid, no martingale.

## Caveat
The card states `SP500.DWX` is backtest-only for T1-T5. T6 live promotion requires parallel validation on `NDX.DWX` or `WS30.DWX`.
