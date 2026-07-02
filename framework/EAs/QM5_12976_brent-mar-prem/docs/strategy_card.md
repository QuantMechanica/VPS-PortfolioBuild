# Strategy Card Copy - QM5_12976_brent-mar-prem

Canonical card:

`strategy-seeds/cards/brent-mar-prem_card.md`

This EA mechanizes the approved Brent March calendar-premium card. It trades
only `XBRUSD.DWX` at D1, enters long on broker-calendar March bars, and exits
on the next D1 bar, month-end, max hold, Friday close, or ATR hard stop. Runtime
uses MT5 OHLC and broker calendar only; it does not touch live deploy files.
