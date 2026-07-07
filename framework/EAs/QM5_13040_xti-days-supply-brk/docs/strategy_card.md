---
ea_id: QM5_13040
slug: xti-days-supply-brk
status: APPROVED
source_id: EIA-XTI-DAYS-SUPPLY-BRK-2026
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# XTI Days-of-Supply Tight-Cover Breakout

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-days-supply-brk_card.md`.

## Hypothesis

The EIA crude-oil days-of-supply series measures stock cover, not just headline
barrel inventory. The EA tests whether WTI D1 breakouts during the regular WPSR
window can continue when price is already near the top of a medium-term
stock-cover proxy channel.

## Rules

The EA trades `XTIUSD.DWX` on D1 only. It inspects the prior completed
Wednesday/Thursday bar, allows at most one entry per month, requires a bullish
ATR-sized upper-close bar, a break above the prior 55-D1 high, close in the
upper part of the 126-D1 close channel, short pullback reclaim, and close above
a rising `SMA(50)`. It enters long with ATR stop/target and exits on stop,
target, time, or close below `SMA(50)`.

## Risk

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
portfolio gate, or AutoTrading setting is touched. This is not WPSR two-event
inventory momentum, one-bar aftershock/fade/pre-event logic, field production,
product-supplied demand, gasoline-stock pressure, XAU/XAG, XNG RSI logic, or
ML.
