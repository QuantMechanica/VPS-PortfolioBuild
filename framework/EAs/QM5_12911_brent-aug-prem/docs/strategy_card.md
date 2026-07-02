# Strategy Card Copy - QM5_12911_brent-aug-prem

Canonical card:

`strategy-seeds/cards/approved/QM5_12911_brent-aug-prem_card.md`

This EA mechanizes the approved Brent August calendar-premium card. It trades
only `XBRUSD.DWX` at D1, enters long on broker-calendar August bars, and exits
on the next D1 bar, month-end, max hold, Friday close, or ATR hard stop. Runtime
uses MT5 OHLC and broker calendar only; it does not touch live deploy files.
