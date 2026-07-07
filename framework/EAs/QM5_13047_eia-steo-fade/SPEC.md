# QM5_13047 eia-steo-fade

## Scope

Single-symbol `XTIUSD.DWX` D1 structural energy sleeve. The EA implements the
approved `strategy-seeds/cards/eia-steo-fade_card.md` card.

## Logic

- Detect the EIA STEO monthly proxy day in broker calendar time: first Tuesday
  after the first Thursday, with optional Wednesday delay handling.
- Build a prior D1 Donchian context excluding the STEO proxy bar.
- Enter long after a failed downside probe that closes back inside the range.
- Enter short after a failed upside probe that closes back inside the range.
- Use ATR stop, ATR target, max-hold exit, standard news handling, and Friday
  close.

## Runtime Data

Darwinex MT5 `XTIUSD.DWX` OHLC, spread, ATR, broker time, and V5 framework
state only. No EIA feed, CSV, API, futures curve, inventory data, analyst
forecast, ML, grid, martingale, or external runtime dependency.
