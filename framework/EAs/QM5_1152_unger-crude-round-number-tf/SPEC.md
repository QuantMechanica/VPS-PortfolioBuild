# QM5_1152 Unger Crude Round Number TF

## Scope

Build-only V5 implementation for approved Strategy Card `QM5_1152_unger-crude-round-number-tf`.

## Card Mapping

- Universe: `XTIUSD.DWX`
- Timeframes: M15 baseline, M5 parameter variant
- Entry: one daily pair of stop orders around the nearest 5.00 price grid levels during the New York entry window
- Buffer: `max(0.02, 0.05 * ATR(14, M15))`
- Stop loss: `1.5 * ATR(14, M15)`
- Take profit: `2.0 * ATR(14, M15)`
- No Friday entries: enforced from New York local day-of-week
- EIA skip: deterministic Wednesday 10:30 New York skip window, configurable by inputs
- Exit: stop loss, take profit, entry cutoff pending-order cancel, and pre-session-end flatten
- Risk: V5 fixed-risk backtest default and percent-risk live default through setfiles

## Framework Alignment

- No-Trade: symbol/timeframe validation, New York session window, Friday exclusion, EIA skip window, spread guard, V5 news/friday-close hooks
- Entry: `Strategy_PlaceStopPair()` submits buy-stop and sell-stop orders once per session
- Management: opposite pending orders are cancelled after a fill; unfilled orders are cancelled at cutoff
- Close: positions flatten before crude reference session end

## Deliberate Build Boundaries

- No backtests or pipeline phases were run.
- EIA inventory skipping is implemented as a deterministic Wednesday time window because no approved deployable event-calendar feed is in build scope.
- The original approved card remains unchanged; local card copy is build-check-safe.
