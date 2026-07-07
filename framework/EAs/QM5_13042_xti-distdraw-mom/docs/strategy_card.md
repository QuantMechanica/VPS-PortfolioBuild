---
ea_id: QM5_13042
slug: xti-distdraw-mom
status: APPROVED
source_id: EIA-XTI-DISTDRAW-MOM-2026
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# XTI Distillate Draw Pressure Momentum

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13042_xti-distdraw-mom_card.md`.

The EA trades `XTIUSD.DWX` on D1 only. It uses the official EIA Weekly
Petroleum Status Report, weekly distillate fuel oil stocks, and heating-oil
source family as structural lineage. Runtime is price-only: Wednesday/Thursday
WPSR proxy bar, October-March heating-season gate, short pullback, bullish
ATR-sized reaction, upper close location, close above rising SMA, ATR
stop/target, season/SMA/time exits, standard news and Friday close handling.

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
T_Live, portfolio gate, or AutoTrading setting is touched. This is not
`QM5_13039` gasoline-stock summer pressure, not broad distillate seasonal
breakout/pullback, not crude inventory momentum, not product-supplied breakout,
not XAU/XAG, not XNG RSI logic, and not ML.
