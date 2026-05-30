# QM5_1102_qp-comm-skew-low SPEC

## Identity
- EA: `QM5_1102_qp-comm-skew-low`
- Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1102_qp-comm-skew-low.md`
- Status: build implementation only; no pipeline phases or backtests run.

## Universe
- `XAUUSD.DWX` slot 0
- `XAGUSD.DWX` slot 1
- `XTIUSD.DWX` slot 2
- `XNGUSD.DWX` slot 3

The approved card lists wider candidates if present. The build uses the four DWX commodity symbols called out in the G0 approval reasoning and mirrored by the related `QM5_1103_qp-comm-ie-low` build.

## Trading Logic
- Rebalance trigger: first chart bar after the D1 month boundary, using the last closed D1 bar as the month-end key.
- Data requirement: at least `strategy_min_bars_d1=270` D1 bars per universe symbol.
- Signal: compute daily log returns over `strategy_return_lookback_d1=252` prior closed D1 bars.
- Stability gate: require at least `strategy_min_nonzero_returns=200` non-zero return observations.
- Ranking: ascending total skewness, defined as the third standardized moment.
- Entry: long bottom `strategy_bucket_size=2` lowest-skewness symbols and short top `strategy_bucket_size=2` highest-skewness symbols.
- Exit: close at the next monthly rebalance. Symbols not in an active bucket do not re-enter.
- Stop: hard stop at `strategy_atr_sl_mult=5.0` times D1 ATR(`strategy_atr_period_d1=20`) from entry.

## V5 Alignment
- No-Trade: timeframe/universe/spread checks in `Strategy_NoTradeFilter`.
- Entry: skewness computation, cross-sectional rank and ATR stop in `Strategy_EntrySignal`.
- Management: no trailing, break-even or partial close beyond framework risk and SL.
- Close: monthly rebalance close in `Strategy_ExitSignal`.
- Risk: backtest fixed risk defaults and live percent-risk inputs are both present per V5 contract.
- Magic: `QM_MagicResolver` via framework, with slots `0..3` registered for `ea_id=1102`.

## Set Files
- H1 backtest setfiles are provided for each supported DWX commodity symbol.
- The EA also allows D1 charts, but canonical build sets use H1 to match the related Quantpedia commodity implementation pattern.
