# Strategy Card Copy - QM5_12852_wti-may-prem

Canonical card:

`strategy-seeds/cards/approved/QM5_12852_wti-may-prem_card.md`

This EA mechanizes the approved WTI May calendar-premium card. It trades only
`XTIUSD.DWX` at D1, enters long on broker-calendar May bars, and exits on the
next D1 bar, month-end, max hold, Friday close, or ATR hard stop. Runtime uses
MT5 OHLC and broker calendar only; it does not touch live deploy files.
