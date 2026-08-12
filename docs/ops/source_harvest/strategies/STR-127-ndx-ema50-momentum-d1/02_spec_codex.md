# STR-127 — Codex independent mechanization spec

## 1. Scope and source boundary

- Strategy: NASDAQ-100 D1 momentum breakout in the direction of the 50 EMA.
- Source read: `00_source.md`, including the complete 15-post thread.
- Ledger row: `STR-127` in `SOURCE_LEDGER.csv`.
- The author's own adverse assessment is retained as evaluation context, not used to rewrite the entry or exit.

## 2. Cohort, timeframe, and clock

- Sole instrument: `NDX.DWX`.
- Signal, order-refresh, and exit timeframe: `D1`.
- Use completed DarwinexZero broker D1 bars on the New-York-close GMT+2/GMT+3 feed.
- EMA input: close-price EMA, period `50`, evaluated on the same completed D1 signal bar.
- Long and short directions are both source-required.

## 3. Numbered mechanized closed-bar rules

1. Evaluate the strategy once on the first tradable tick after each new completed D1 bar.
2. Read that bar's close, high, and low and the 50-period EMA value at the same closed-bar shift.
3. If any required bar or EMA value is incomplete/non-finite, cancel no valid state speculatively; block new action and emit setup/data-missing evidence.
4. When flat and `close > EMA50`, maintain exactly one buy-stop candidate at the completed bar's high with its stop loss at that bar's low.
5. When flat and `close < EMA50`, maintain exactly one sell-stop candidate at the completed bar's low with its stop loss at that bar's high.
6. At each new D1 close, remove the previous strategy pending order before submitting the newly calculated same- or opposite-side order. There is never a ladder of historical daily stops.
7. If `close == EMA50`, remove any untriggered strategy pending and submit no new order.
8. Align prices outward to the symbol trade tick without weakening the stop. If the pending geometry is already marketable or illegal at the first post-close tick, treat it as the gap case in FLAG-127-03.
9. Once a position fills, remove all remaining strategy pending orders and submit no new entry while the position is open.
10. Preserve the signal bar's opposite extreme as the position stop. An EMA regime flip does not close an already-open position.
11. After entry, inspect every subsequently completed D1 bar, including the entry day's completed bar when its close occurs after the fill.
12. At the first such bar whose close is profitable relative to the actual fill (`close > fill` for long; `close < fill` for short), issue a market exit on the first tradable tick after that close.
13. If that close is not profitable, hold the position until a later profitable D1 close or the original stop.
14. Allow at most one open position and one pending order per magic. Do not pyramid, stack, martingale, grid, or reverse an open trade.
15. Apply mandatory news blackout, stale-calendar fail-closed behavior, Friday close, daily-loss, and portfolio drawdown guards.

## 4. Inputs

| Input | Primary value | Status |
|---|---:|---|
| `strategy_ema_period` | `50` | Source-fixed |
| `strategy_signal_timeframe` | `PERIOD_D1` | Source-fixed |
| `strategy_pending_policy` | `REPLACE_EACH_D1_CLOSE` | FLAG-127-01 |
| `strategy_equal_ema_policy` | `CANCEL_AND_FLAT` | FLAG-127-02 |
| `strategy_gap_policy` | `STOP_SEMANTICS_AT_NEXT_TICK` | FLAG-127-03 |
| `strategy_profit_test` | `DIRECTIONAL_CLOSE_VS_FILL` | FLAG-127-04 |
| `RISK_FIXED` | `> 0` in backtests | House-required |
| `RISK_PERCENT` | `0` in backtests; `> 0` and `<= 1.0` live | House-required |
| `qm_news_stale_max_hours` | `<= 336` | Guardrail; never weaken |

No target, ATR sizing filter, EMA bypass, long-only switch, or alternate swing rule belongs in the primary specification.

## 5. Five-hook sketch

### `Strategy_NoTradeFilter`

- Validate `NDX.DWX`, D1 history, EMA readiness, risk inputs, one-position/one-pending state, news-calendar freshness, and framework safety state.
- Do not use the later forum variant that removes the EMA or adds ATR-based dollars-per-point sizing.
- When a mandatory blackout invalidates the active pending-order period, remove the pending order and consume that D1 signal; wait for the next completed D1 bar.

### `Strategy_EntrySignal`

- On a new D1 close while flat, cancel the prior strategy pending.
- Above EMA50, emit one buy stop at the signal high with stop at the signal low.
- Below EMA50, emit one sell stop at the signal low with stop at the signal high.
- At equality, emit nothing.

### `Strategy_ManageOpenPosition`

- Remove any residual pending order after a fill.
- Preserve the original stop; do not trail, break even, partially close, or add a target.
- Track the fill time so only D1 closes completed after the fill can qualify for exit.

### `Strategy_ExitSignal`

- On each new completed D1 bar after entry, return true for the first directionally profitable close.
- Do not exit merely because price crosses the EMA.
- Framework Friday and risk-kill exits remain mandatory house overrides.

### `Strategy_NewsFilterHook`

- Use the fail-closed framework high-impact blackout appropriate to `NDX.DWX`/USD exposure.
- Do not leave a pending stop capable of triggering inside a blocked window.

## 6. Interpretation flags

- **FLAG-127-01 — pending accumulation is ambiguous.** "Set a buy order at the day's high. Do the same tomorrow" could accumulate multiple pending orders, while only regime-flip cancellation is explicit. House policy forbids stacking, so the primary projection replaces the old order at every D1 close. An accumulating ladder is out of scope.
- **FLAG-127-02 — equality is unstated.** The source specifies above and below EMA50 only. Equality is mechanized as cancel-and-no-entry rather than arbitrarily choosing a direction.
- **FLAG-127-03 — gap through the stop level is unstated.** Primary semantics are those of a real stop order: if a valid order was live before a gap, it fills at the first available executable price; if a newly calculated level is already crossed before it can be placed, submit a market-equivalent stop fill only if the framework can preserve auditable next-tick pricing and legal stop geometry, otherwise skip that D1 signal. Do not backfill at the stale high/low.
- **FLAG-127-04 — "profitable close" cost basis is unstated.** The primary signal compares the completed D1 close with actual fill in the trade direction. Real commission, swap, and spread remain in P/L evidence but no invented cost estimate changes the exit signal. A net-account-currency trigger would be a separate variant.
- **FLAG-127-05 — same-day profitable close.** A position triggered during a D1 bar may exit after that same bar closes if it is the first completed close after the fill and is profitable. The source does not require a full additional holding day.
- **FLAG-127-06 — no underwater time exit.** The source supplies none. The position can remain open until its original stop or a profitable close, subject only to mandatory framework Friday/risk exits.

## 7. Risk and evaluation notes

- Backtests use `RISK_FIXED > 0` and `RISK_PERCENT = 0`; live risk is `<=1%` per magic.
- The source author identifies structural negative reward/risk: a loser can span a full D1 range while profitable-close exits are often below half a range.
- The author also discusses drawdowns around 40%. This conflicts sharply with Edge Lab targets (`<=5%` daily and `<=10%` total) and is a reason for strict Q-gate testing, not for modifying the mechanics.
- Mandatory news blackout is a house safety overlay. No commission, swap, DST, or slippage value is invented.
- The ledger identifies no built duplicate and distinguishes the idea from existing live NDX strategies.
