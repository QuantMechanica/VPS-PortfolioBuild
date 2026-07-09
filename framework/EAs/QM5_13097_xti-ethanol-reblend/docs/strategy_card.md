---
ea_id: QM5_13097
slug: xti-ethanol-reblend
status: APPROVED
source_id: EIA-ETHANOL-REBLEND-XTI-2026
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# XTI Ethanol Reblend Pullback-Reclaim

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13097_xti-ethanol-reblend_card.md`.

## Hypothesis

EIA describes ethanol blending as a proxy for gasoline demand when most gasoline
is E10, notes April ethanol-plant maintenance in the weekly ethanol production
series, and documents the spring/summer gasoline formulation switch. This EA
expresses that source lineage as a price-only `XTIUSD.DWX` D1 pullback-reclaim
rule during the late-April to mid-June spring reblend window.

## Rules

The EA trades `XTIUSD.DWX` on D1 only. It requires a prior pullback below SMA,
signal-bar SMA reclaim, bullish ATR-sized range/body, upper-range close, and
flat-to-rising SMA. It enters long with ATR stop/target and exits on stop,
target, time, date-window invalidation, or close below SMA minus an ATR buffer.

## Risk

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
portfolio gate, or AutoTrading setting is touched. This is not generic WPSR
aftershock/fade/pre-event, May-August gasoline-stock momentum, broad driving
season breakout, holiday gasoline fade, RBOB, XTI/XNG, XAU/XAG, XNG RSI, or ML.
