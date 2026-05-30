# QM5_1186 qp-comm-sma12-filter

## Strategy

Implements the approved Quantpedia commodity 12-month SMA filter card as a V5 long/flat EA. The EA is attached per commodity proxy and rebalances on the first tradable D1 bar of a new month using the last completed MN1 close.

## Universe

- XAUUSD.DWX slot 0
- XAGUSD.DWX slot 1
- XTIUSD.DWX slot 2
- XNGUSD.DWX slot 3
- XCUUSD.DWX slot 4

## Signal Mapping

- Entry: last completed monthly close is above the 12-month SMA of completed monthly closes.
- Exit: at the next monthly rebalance when the last completed monthly close is at or below the 12-month SMA.
- Direction: long only.
- Sizing: setfiles use `PORTFOLIO_WEIGHT=0.20` per attached symbol to approximate equal notional allocation across the five approved commodity proxies.
- Stop: no source alpha stop; an ATR stop is supplied only so the V5 risk engine can size positions deterministically.

## V5 Alignment

- No-trade: framework kill switch, news mode, Friday close and timeframe/symbol guards.
- Entry: `Strategy_EntrySignal`.
- Management: no intramonth alpha management.
- Exit: `Strategy_ExitSignal` at monthly rebalance.

## Build Notes

No external data, web calls, ML, martingale, interpolation, or short side are used.
