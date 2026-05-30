# QM5_1202_qp-sp500-rv-vix-short SPEC

## Source
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1202_qp-sp500-rv-vix-short.md`
- Framework: QuantMechanica V5

## Strategy Mapping
- Symbol: `SP500.DWX`
- Timeframe: `D1`
- Direction: short-only
- Entry: on a new D1 bar, compute 10-day annualized realized volatility from closed `SP500.DWX` daily returns and compare it to the 60-day SMA of VIX closes from local CSV. Enter/maintain short when `VIX_SMA_60 < SP500_RV_10`.
- Exit: at daily rebalance, close the short when `VIX_SMA_60 >= SP500_RV_10` or when the local VIX CSV is unavailable/stale.
- Stop: initial stop at `2.5 * ATR(20)` above short entry.
- Data gate: requires at least 40 SP500 D1 bars and 80 valid VIX observations.
- External data: no web/API calls. VIX is read from deterministic local CSV `QM5_1202_vix_daily.csv`.

## V5 Modules
- `Strategy_NoTradeFilter`: symbol/timeframe/slot/history/parameter/trade-mode gates.
- `Strategy_EntrySignal`: closed-bar short signal and ATR stop generation.
- `Strategy_ManageOpenPosition`: no active trailing; card only specifies initial ATR stop.
- `Strategy_ExitSignal`: closed-bar short/flat signal exit.

## Registry
- `ea_id`: `1202`
- `slug`: `qp-sp500-rv-vix-short`
- Magic: `12020000` for `SP500.DWX`, slot `0`

## Notes
- `SP500.DWX` remains a T6 live caveat per card. Live promotion requires later parallel validation on `NDX.DWX` or `WS30.DWX`.
- No backtests or pipeline phases are part of this build.
