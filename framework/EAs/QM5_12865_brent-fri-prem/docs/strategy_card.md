# Strategy Card Copy - QM5_12865_brent-fri-prem

Canonical card:

`strategy-seeds/cards/approved/QM5_12865_brent-fri-prem_card.md`

This EA mechanizes the approved Brent Friday calendar-premium card. It trades
only `XBRUSD.DWX` at D1, enters long on broker-calendar Friday bars, and exits
through framework Friday close, the next non-Friday D1 bar, max hold, or an ATR
hard stop. Runtime uses MT5 OHLC and broker calendar only; it does not touch
live deploy files.
