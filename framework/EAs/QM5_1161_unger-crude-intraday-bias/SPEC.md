# QM5_1161 Unger Crude Intraday Bias

## Source Card
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1161_unger-crude-intraday-bias.md`
- EA id: `1161`
- Slug: `unger-crude-intraday-bias`
- Symbol: `XTIUSD.DWX`
- Execution timeframe: `M15`

## Strategy Mapping
- Entry module:
  - Long bias leg opens around `16:00` New York time.
  - Short bias leg opens around `10:00` New York time.
  - One position per magic; no new leg while a prior leg is open.
  - Optional EMA(20, M15) direction filter is enabled by default.
  - Entries require spread below the local median-spread multiple.
  - Wednesday EIA inventory release window is skipped deterministically by default.
- Trade management module:
  - No trailing stop, break-even, partial close, or add-on logic.
- Exit module:
  - Long leg closes around `03:00` New York time on the following session.
  - Short leg closes around `15:00` New York time on the same session.
  - ATR stop handles adverse exits.
- Risk:
  - Backtest setfiles use `RISK_FIXED=1000`.
  - Live setfile uses `RISK_PERCENT=0.25` and `RISK_FIXED=0`.

## Notes
- No external market-data or event API is used.
- EIA skip is deterministic Wednesday 10:30 New York with configurable pre/post minutes.
- No backtests or pipeline phases were run as part of the build.
