# Approved Strategy Card — QM5_13116 xng-signmom

Authoritative artifacts:

- `strategy-seeds/cards/xng-signmom_card.md`
- `strategy-seeds/cards/approved/QM5_13116_xng-signmom_card.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13116_xng-signmom.md`

The approved mechanic is monthly `XNGUSD.DWX` D1 return-sign momentum from
Papailias, Liu, and Thomakos (2021): calculate the equal-weight fraction of
non-negative returns across the prior 12 completed broker months; buy at or
above 0.40 and sell below 0.40; renew monthly. The carrier uses a frozen
ATR(20)*3.5 hard stop, 35-day stale close, one attempt per month, no intramonth
re-entry, and RISK_FIXED=1000 in the only backtest setfile.

No adaptive threshold, magnitude momentum, RSI, external data, ML, live
setfile, deploy/T_Live manifest, portfolio gate, `T_Live`, or AutoTrading change
is authorized.

