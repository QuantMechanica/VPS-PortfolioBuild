---
strategy_id: FRAZZINI-BAB-2014_XTI_XNG_S01
source_id: FRAZZINI-BAB-2014
ea_id: QM5_13132
slug: energy-bab
status: APPROVED
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_13132_XTI_XNG_BAB_D1
period: D1
---

# Approved Build Reference - QM5_13132 Energy BAB

Canonical card: `strategy-seeds/cards/energy-bab_card.md`.

On the first tradable XTI D1 bar of each broker month, form an inverse-
volatility XTI/XNG benchmark, estimate 252-observation Dimson betas with five
lags, shrink them halfway toward one, buy the lower-beta leg, and short the
higher-beta leg.

Split `RISK_FIXED=1000` to target inverse-beta notionals under frozen
`ATR(20) * 3.5` stops. Reject more than 20% post-rounding beta mismatch. Close
at the next month transition, after 35 days, or on orphan/invalid composition;
deal history suppresses same-month re-entry.

The 24-future source is narrowed to two CFDs and raw returns, so Q02 is a
strict carrier falsification. No source performance, live action, portfolio
admission, or gate change is authorized.
