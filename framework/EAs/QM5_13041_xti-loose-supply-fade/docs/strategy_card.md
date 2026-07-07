---
ea_id: QM5_13041
slug: xti-loose-supply-fade
status: APPROVED
source_id: EIA-XTI-DAYS-SUPPLY-FADE-2026
period: D1
target_symbols: [XTIUSD.DWX]
pipeline_phase: Q02
---

# XTI Loose Days-Of-Supply Breakdown Fade

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-loose-supply-fade_card.md`.

## Hypothesis

The EIA crude-oil days-of-supply series measures stock cover, not just headline
barrel inventory. The EA tests whether WTI D1 breakdowns during the regular
WPSR window can continue when price is already near the bottom of a medium-term
stock-cover proxy channel.

## Rules

The EA trades `XTIUSD.DWX` on D1 only. It inspects the prior completed
Wednesday/Thursday bar, allows at most one entry per month, requires a bearish
ATR-sized lower-close bar, a break below the prior 55-D1 low, close in the
lower part of the 126-D1 close channel, short rebound rejection, and close
below a falling `SMA(50)`. It enters short with ATR stop/target and exits on
stop, target, time, or close above `SMA(50)`.

## Risk

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live/deploy manifest,
portfolio gate, or AutoTrading setting is touched. This is not the existing
long tight-cover breakout, WPSR two-event inventory momentum, one-bar
aftershock/fade/pre-event logic, field production, product-supplied demand,
gasoline-stock pressure, XAU/XAG, XNG RSI logic, or ML.
