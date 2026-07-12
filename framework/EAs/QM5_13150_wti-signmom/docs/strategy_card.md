# Approved Strategy Card — QM5_13150 wti-signmom

Authoritative artifacts:

- `strategy-seeds/cards/wti-signmom_card.md`
- `strategy-seeds/cards/approved/QM5_13150_wti-signmom_card.md`
- `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13150_wti-signmom.md`

The approved mechanic is monthly `XTIUSD.DWX` D1 return-sign momentum from
Papailias, Liu, and Thomakos (2021): calculate the equal-weight fraction of
non-negative returns across the prior 12 completed broker months; buy at or
above 0.40 and sell below 0.40; renew monthly. The carrier uses a frozen
ATR(20)*3.5 hard stop, 35-day stale close, one attempt per month, restart-safe
deal-history de-duplication, and `RISK_FIXED=1000` in its only setfile.

This is not WTI cumulative-return TSMOM: it counts the signs of twelve
individual monthly returns. The existing XNG implementation is the declared
same-source sibling. No adaptive threshold, RSI, external data, ML, live
setfile, deploy/T_Live manifest, portfolio gate, `T_Live`, or AutoTrading
change is authorized.
