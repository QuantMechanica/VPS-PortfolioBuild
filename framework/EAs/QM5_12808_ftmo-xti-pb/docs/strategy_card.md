---
ea_id: QM5_12808
slug: ftmo-xti-pb
source_id: FTMO-MAR2026-XTI-PORTFOLIO
g0_status: APPROVED
status: APPROVED
---

# FTMO XTI Trend Pullback

This is a copy of the approved card body kept with the EA for build review.

The EA trades `XTIUSD.DWX` on H4. It requires a D1 EMA(50/200) trend regime,
then enters after the prior H4 bar pulls back into EMA(50) and reclaims EMA(21)
in the D1 trend direction. Exits use the initial ATR hard stop, H4 EMA(50)
trend invalidation, D1 trend invalidation, and a max-hold guard.

Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The build does not
touch live deploy artifacts or portfolio admission code.
