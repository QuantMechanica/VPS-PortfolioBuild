# QM5_1179 qp-comm-term-carry

## Strategy

Approved Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1179_qp-comm-term-carry.md`

Quantpedia commodity term-structure carry implementation for approved DWX commodity proxies. The EA runs on D1, reads a local roll-yield CSV, ranks the five-symbol commodity universe by prior-month roll yield, and rebalances on the first tradable day of each month. It opens long exposure in the top 20% highest roll-yield commodity and short exposure in the bottom 20% lowest roll-yield commodity when all five symbols have valid signal rows.

## Framework Alignment

- No-Trade: V5 framework guards plus D1 timeframe, symbol-universe, parameter, spread, and signal-availability checks.
- Entry: first tradable day of the month, prior-month roll-yield CSV read, minimum five eligible commodities, top 20% long and bottom 20% short.
- Management: no trailing, break-even, partial close, hedge ratio, futures-curve optimization, grid, or martingale.
- Close: monthly rebalance closes open positions before the next monthly rank can open fresh legs.
- Risk: `PORTFOLIO_WEIGHT=0.50` in setfiles so the expected two active legs split `RISK_FIXED=1000` in backtest and `RISK_PERCENT=0.25` in live.
- Magic: `ea_id=1179`, slots `0..4` for `XAUUSD.DWX`, `XTIUSD.DWX`, `XNGUSD.DWX`, `XAGUSD.DWX`, `XCUUSD.DWX`.

## Parameters

- `strategy_roll_yield_csv_path`: default `QM5_1179_commodity_roll_yield.csv`.
- `strategy_min_eligible`: default `5`.
- `strategy_bucket_pct`: default `20.0`.
- `strategy_atr_period`: default `20`.
- `strategy_atr_sl_mult`: default `2.5`.
- `strategy_max_spread_points`: default `0`, disabled.

## Data Contract

The EA expects a local CSV in terminal Files or Common Files with fields in this order:

`symbol,month,front_contract_price,next_contract_price,roll_yield`

`month` may be `YYYY-MM`, `YYYYMM`, or a date whose first six digits represent the signal month. Without a valid row for all five approved commodities for the prior month, the EA intentionally produces no entry signal.

## Notes

The approved card is marked body-incomplete, but it contains enough mechanical rules for a build: target universe, monthly roll-yield ranking, top/bottom quintile selection, monthly rebalance, ATR stop, and fixed risk split. No external web/API access, backtests, or pipeline phases are part of this build.
