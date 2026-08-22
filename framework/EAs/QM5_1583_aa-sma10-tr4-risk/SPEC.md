# QM5_1583 aa-sma10-tr4-risk — Build Specification

## Card of record

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1583_aa-sma10-tr4-risk.md`
- `g0_status`: `APPROVED`
- EA registry identity: `1583,aa-sma10-tr4-risk`
- Source family: Alpha Architect monthly tactical allocation

## Mechanical contract

At the first eligible D1 bar of each new broker calendar month, use only completed
month-end closes reconstructed from closed D1 bars:

1. `ma_positive = latest completed month close > SMA(latest 10 completed month closes)`.
2. `return_positive = latest completed month close / close four months earlier - 1 > 0`.
3. Target equity-index risk exposure is `1.0` when both signals are positive,
   `0.5` when exactly one is positive, and `0.0` otherwise.
4. An existing position is closed at every monthly rebalance. A positive target
   is reopened on the same bar with the framework risk budget scaled to the target.
5. Initial stop is `3.0 * ATR(20,D1)`. There is no fixed take-profit, trailing
   stop, pyramiding, grid, martingale, or intra-month signal exit.

The defensive sleeve is represented by flat/cash behavior because no defensive
proxy is approved for this EA.

## Framework alignment

| Card rule | V5 location |
|---|---|
| D1 chart and registered host slot only | `Strategy_NoTradeFilter` |
| Minimum 220 closed D1 bars and 11 completed monthly closes | `Strategy_LoadMonthlyCloses` |
| Exact month-end endpoint extraction | `Strategy_LoadMonthlyCloses` |
| 10-month SMA and 4-month return | `Strategy_TargetExposure` |
| 100/50/0 target allocation | `Strategy_TargetExposure` and `Strategy_ConfigureRiskForExposure` |
| Monthly close, resize, and entry | `Strategy_EntrySignal` |
| 3× ATR(20,D1) initial stop | `Strategy_EntrySignal` via `QM_StopATRFromValue` |
| Standard news blackout | framework two-axis `PRE30_POST30` + `DXZ` entry gate |
| No extra management | `Strategy_ManageOpenPosition` |
| No separate discretionary exit | `Strategy_ExitSignal` |

## Governed symbols and slots

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | GDAXI.DWX | 15830000 |
| 1 | NDX.DWX | 15830001 |
| 2 | SP500.DWX | 15830002 |
| 3 | UK100.DWX | 15830003 |
| 4 | WS30.DWX | 15830004 |
| 5 | XAUUSD.DWX | 15830005 |
| 6 | EURUSD.DWX | 15830006 |
| 7 | GBPUSD.DWX | 15830007 |
| 8 | USDJPY.DWX | 15830008 |
| 9 | USDCHF.DWX | 15830009 |
| 10 | AUDUSD.DWX | 15830010 |
| 11 | USDCAD.DWX | 15830011 |
| 12 | NZDUSD.DWX | 15830012 |

`SP500.DWX` is backtest-only. Any future live promotion requires the card's
parallel validation on a broker-routable index and separate OWNER approval.

## Build-only boundary

This specification authorizes compilation and deterministic non-live review only.
It does not provide a pipeline verdict or authorize T6/live use.
