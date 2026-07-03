# Strategy Card Copy - QM5_12980_brent-6m-rev

Canonical card:

`strategy-seeds/cards/brent-6m-rev_card.md`

This EA mechanizes the approved Brent 6-month overextension fade card. It
trades only `XBRUSD.DWX` at D1, evaluates one monthly 120-D1 return extreme,
fades SMA/ATR-confirmed overextensions, and exits on return zero-cross, max
hold, Friday close, or ATR hard stop. Runtime uses MT5 OHLC only and does not
touch live deploy files.
