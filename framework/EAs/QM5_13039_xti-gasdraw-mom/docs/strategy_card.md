---
ea_id: QM5_13039
slug: xti-gasdraw-mom
status: APPROVED
source_id: EIA-GASDRAW-XTI-MOM-2026
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# XTI Gasoline Draw Pressure Momentum

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-gasdraw-mom_card.md`.

## Hypothesis

Weekly EIA gasoline-stock pressure can transmit into WTI during the May-August
driving-season demand window when the D1 `XTIUSD.DWX` bar reacts strongly after
a short pullback. The EA is price-only at runtime and uses the official EIA
gasoline-stock/WPSR source family as structural lineage.

## Rules

The EA trades `XTIUSD.DWX` on D1 only. It inspects the prior completed
Wednesday/Thursday bar, requires May-August seasonality, pre-signal pullback,
ATR-sized bullish range/body, upper-range close, close above rising `SMA(50)`,
and then enters long with ATR stop/target. It exits on stop, target, time,
season invalidation, or close below `SMA(50)`.

## Risk

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
portfolio gate, or AutoTrading setting is touched. This is not the
`QM5_13035` product-supplied Donchian breakout, not crude-inventory WPSR
aftershock/fade/pre-event logic, not XAU/XAG, not XNG RSI logic, and not ML.
