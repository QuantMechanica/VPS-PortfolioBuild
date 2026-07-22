# QM5_20046_wti-halloween-ls

Monthly WTI symmetric Halloween regime: long November-April, short May-October, renewed at each broker-month boundary. One persisted attempt per month, frozen D1 ATR(20) x 4 hard stop, 35-day stale guard, and no same-month re-entry. Backtest uses `RISK_FIXED=1000`; no live artifact is created.

Source: Burakov, Freidin and Solovyev (2018), *International Journal of Energy Economics and Policy* 8(2), 121-126. Canonical rules and non-duplicate boundary are in `strategy-seeds/cards/wti-halloween-ls_card.md`.

