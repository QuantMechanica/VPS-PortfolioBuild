---
ea_id: QM5_13133
slug: energy-ivol
strategy_id: FUERTES-MOMIVOL-2015_XTI_XNG_S02
source_id: FUERTES-MOMIVOL-2015
status: APPROVED
g0_status: APPROVED
logical_symbol: QM5_13133_XTI_XNG_IVOL_D1
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
period: D1
risk_mode: RISK_FIXED
copy_of: strategy-seeds/cards/energy-ivol_card.md
---

# Energy Pure IVol Spread

At each broker-month transition, fit XTI and XNG D1 returns separately on the
equal-weight XTI/XNG/XAU/XAG commodity-factor return over 252 observations.
Buy the lower residual-volatility energy leg and short the higher one.

The two ATR-stopped legs target equal dollar notional and reject more than 20%
post-rounding mismatch. Close at the next month, after 35 days, or immediately
on an orphan or invalid package. Current-month deal history prevents re-entry
after restart or stop-out.

This is the source's standalone IVol rule, not `QM5_13113` momentum-IVol
agreement and not `QM5_12567` cumulative RSI2. XAU and XAG are read-only factor
members. Q02 is a two-CFD carrier test; Q09 alone may establish decorrelation.

No live setfile, deploy manifest, portfolio gate, T_Live path, or AutoTrading
setting is part of this build.
