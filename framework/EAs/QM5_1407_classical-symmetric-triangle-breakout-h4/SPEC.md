# QM5_1407_classical-symmetric-triangle-breakout-h4 — Strategy Spec

**EA ID:** QM5_1407
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md`
**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Revision:** v5.1, 2026-08-24

## Strategy contract

The EA scans bounded H4 history for a Williams five-bar-fractal symmetric triangle. It requires at least three descending pivot highs and three ascending pivot lows, D1-ATR-scaled mirrored regression slopes, a minimum 3 ATR(H4) amplitude, no earlier buffered close outside the triangle, and an apex no more than 30% of the pattern length ahead. A pattern whose apex is on or behind the current H4 bar is invalid.

After a valid pattern is found, the EA arms both sides simultaneously:

- BUY-STOP at the current projected supply line plus 0.5 ATR(H4).
- SELL-STOP at the current projected demand line minus 0.5 ATR(H4).
- Both orders expire after 12 H4 bars. The first fill cancels its peer (OCO).
- Every new H4 bar revalidates the same pivot-overlap pattern and cancels the bracket when the apex has passed or the structure is stale.

The spread must be at most 0.25 ATR(H4). Entry is blocked within 480 minutes before and after high-impact news; management remains active during the blackout.

## Exits and risk

- Full TP is one triangle height from entry.
- At 50% of the measured move, close 50% and move SL to break-even. Partial-close and SL results are checked independently and failed actions are retried.
- Pattern-failure exit uses the persisted supply/demand line projected forward to the current closed H4 bar.
- Time stop is 36 H4 bars.
- Initial SL is beyond the opposite pattern extreme by 0.3 ATR(H4), capped at 3 ATR(H4).
- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`; live packaging must invert the active risk mode under OWNER policy.

Pending-pattern geometry, pivot identities, reuse history, and TP1 action flags are persisted through terminal global variables. An open position without durable geometry after restart exits fail-closed.

## Reuse rule

After entry or invalidation, candidates are blocked for 20 H4 bars only when more than 50% of their pivot timestamps overlap the recorded pattern. Unrelated patterns remain eligible.

## Approved universe

- EURUSD.DWX
- GBPUSD.DWX
- XAUUSD.DWX
- NDX.DWX
- WS30.DWX
- GDAXI.DWX
- UK100.DWX
- XTIUSD.DWX

## Framework alignment

- Umbrella include and initialization: `QM_Common.mqh` / `QM_FrameworkInit`.
- Magic ownership: registry-backed `QM_FrameworkMagic` and `QM_EntryRequest.symbol_slot`.
- Entries and OCO removal: `QM_TM_OpenPosition` / `QM_TM_RemovePendingOrder`.
- Partial, break-even, and strategy exits: `QM_TM_PartialClose`, `QM_TM_MoveSL`, `QM_TM_ClosePosition`.
- Direct MAE hook: `QM_FrameworkTrackOpenPositionMae` on every tick before strategy returns.
- Series access: bounded `CopyRates` calls with `ArraySize` guards; the one position-age `iBarShift` is explicitly perf-allowed.

No ML, proxy signal, macro-bias filter, grid, or PnL-adaptive mechanic is present.
