# QM5_12813 EIA Energy Switch

Canonical card: `strategy-seeds/cards/approved/QM5_12813_eia-energy-switch_card.md`

This EA expresses a fixed, low-frequency XTI/XNG seasonal energy switch:

- May 15 through August 31: buy `XTIUSD.DWX`, sell `XNGUSD.DWX`.
- November 1 through March 31: sell `XTIUSD.DWX`, buy `XNGUSD.DWX`.
- Require D1 SMA confirmation on both legs.
- Enter at most one two-leg package per calendar month.
- Exit on month change, season end, max hold, Friday close, broken package, or ATR stop.

Q02 setfiles use `RISK_FIXED=1000` and all runtime data comes from Darwinex MT5 D1 OHLC plus broker calendar.
