# WTI ETF Roll-Pressure Fade

Card source: `strategy-seeds/cards/approved/QM5_12736_wti-roll-fade_card.md`

This EA implements the approved `QM5_12736_wti-roll-fade` card: a
low-frequency `XTIUSD.DWX` D1 short-only sleeve sourced from the CFTC Office of
the Chief Economist paper "Predatory or Sunshine Trading? Evidence from Crude
Oil ETF Rolls". Runtime uses Darwinex MT5 OHLC and broker calendar only.

Rules:

- Trade only `XTIUSD.DWX` on D1, magic slot 0.
- Enter short only during broker trading days 5-9 of the current month.
- Require prior D1 downside confirmation and a close below SMA.
- Use an ATR hard stop.
- Exit by roll-window end, month change, SMA recovery, max hold, or framework
  Friday close.
- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.

This is not a WTI month-of-year, weekday, WPSR, hurricane, refinery, OPEC,
CME-expiry, CAD/oil, XTI/XNG, XAU/XAG, or XNG RSI commodity sleeve.
