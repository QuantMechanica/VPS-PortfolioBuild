# QM5_1141 debondt-thaler-3y-reversal-idx

## Source Card

- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1141_debondt-thaler-3y-reversal-idx.md`
- Status: APPROVED
- Build scope: V5 EA build only; no backtests or pipeline phases.

## Strategy Mapping

- Universe: `GDAXI.DWX`, `NDX.DWX`, `UK100.DWX`, `WS30.DWX`, `SP500.DWX`.
- Timeframe: D1.
- Rebalance: first D1 bar after a calendar-month change.
- Signal: rank trailing D1 return ascending using `Close[21] / Close[777] - 1`.
- Entry: long bottom bucket, default bottom 2 of 5. Optional P3 input can short the top bucket.
- Exit: monthly rebalance closes positions that are no longer in the selected bucket or whose desired direction changed.
- Stop: ATR(D1,14) multiplied by 4.0.
- Sizing: V5 standard `RISK_FIXED` for backtest sets and `RISK_PERCENT` for live sets.

## Setfiles

- Backtest sets exist for all five index symbols.
- Live sets exist only for routable DXZ index symbols; `SP500.DWX` remains backtest-only per card caveat.

## Notes

- This implementation does not call external data APIs and does not use ML.
- The EA reads peer symbols from the terminal history and guards for insufficient D1 history.
