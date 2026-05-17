# QM5_1086 v2 Research Notes

Source researched: Alpha Architect / Wesley Gray, PhD, "Avoiding the Big Drawdown with Trend-Following Investment Strategies", PDF: https://alphaarchitect.com/wp-content/uploads/2021/08/Avoiding_the_Big_Drawdown_with_Trend-Following_Investment_Strategies.pdf

## Original Rule

The source defines the Downside Protection Model as two monthly trend rules:

- Time-series momentum: 12-month excess return over T-Bills; positive means risky asset exposure, otherwise cash/T-Bills.
- Moving average: current price versus 12-month moving average; positive means risky asset exposure, otherwise cash/T-Bills.
- The source says these rules are assessed monthly and transact at month close.

Short source excerpts:

- "The Downside Protection Model (DPM) follows two simple rules"
- "We assess these rules monthly"
- "transact at the close of the month"

## Diff vs v1

v1 correctly encoded the two rule families, but it shipped H1 setfiles and explicitly blocked non-H1 charts in `Strategy_NoTradeFilter()` and `Strategy_ExitSignal()`. The card and source are monthly/D1-style allocation rules. That H1 port was too brittle for a monthly close strategy and contributed to no-trade behavior in P2.

## v2 Rule

v2 keeps the source rule logic but ports execution to D1/monthly rebalance:

- Setfiles are renamed to D1.
- 12-month return and moving average are computed as a 252-trading-day D1
  proxy so DWX tester runs do not depend on missing MN1 custom-symbol history.
- `Strategy_NoTradeFilter()` allows D1, not only H1.
- `Strategy_ExitSignal()` allows D1, not only H1.
- Entry remains on the first D1 bar after a monthly boundary using the closed monthly bar, matching the available MT5/DWX execution model.

## Source Universe

The source studies broad market indices and asset classes. The card port remains the approved DWX universe: `SP500.DWX` backtest-only plus `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`, and liquid FX majors.
