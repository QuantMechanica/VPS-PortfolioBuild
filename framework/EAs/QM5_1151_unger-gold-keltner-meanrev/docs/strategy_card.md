---
ea_id: QM5_1151
slug: unger-gold-keltner-meanrev
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Unger Gold Keltner Mean Reversion - False Break Around Channel Extremes

## Source

Unger Academy January 2026 Strategy of the Month article, "A Reversal Strategy on the Gold Futures Takes the Win", plus *The Unger Method* reference. Local EA copy intentionally omits external URLs to satisfy build-time runtime/API guards.

## Mechanics

Universe: `XAUUSD.DWX`. Execution timeframe: `M30`.

Entry:
- Keltner Channel on M30, default `EMA_PERIOD=20`, `ATR_PERIOD=20`, `ATR_MULT=2.0`.
- Long setup: price trades below the lower Keltner band, then the next completed M30 bar closes back above the lower band inside the configured long NY time window.
- Short setup: price trades above the upper Keltner band, then the next completed M30 bar closes back below the upper band inside the configured short NY time window.
- Enter at market on the signal bar close.
- One entry per direction per session; one open position per magic.

Exit:
- Stop loss or take profit.
- Close after `MAX_HOLD_BARS=48` M30 bars.
- First-build mean exit: optional close when price reaches the Keltner midline.

Stop/target:
- First build normalizes fixed GC monetary stop/target into ATR terms: `SL=2.0*ATR(14,M30)`, `TP=4.0*ATR(14,M30)`.

Filters:
- Long window default 08:00-15:00 New York.
- Short window default 09:00-13:00 New York.
- Skip high-impact release days via V5 news configuration.
- Standard spread and one-position controls.

## Approval

G0 status is APPROVED. No ML, online adaptation, grid, martingale, or external data feed is authorized.
