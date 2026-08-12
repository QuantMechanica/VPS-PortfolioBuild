# STR-021 — Claude spec (independent, pre-reconciliation)

Strategy: **Weekly-open break + order-block liquidity-sweep reversal (Metals, M15)**
— after price sweeps through the weekly open, a high-volume rejection candle beyond
the level becomes the order block; on reclaim-confirmation a limit order at the
block edge trades the reversal back through the level.

## Definitions (closed-bar, M15 execution)

- `weekly_open`: open price of the current broker W1 bar (resets Monday 00:00
  broker; NY-close GMT+2/+3 convention — framework broker-time helpers).
- Volume basis: **tick volume** (only volume on .DWX; author's caveat documented —
  extreme-volume is a confirmation heuristic, deterministically proxied):
  `extreme_vol(bar) := tick_volume[bar] >= vol_mult * SMA(tick_volume, vol_lookback)[bar]`
  with `vol_mult=2.0`, `vol_lookback=96` (one M15 day). [interpretation]
- All logic on closed M15 bars; evaluated once per new M15 bar.

## Setup state machine (BUY side; SELL mirror)

State per week, per side:
1. `IDLE` → `BROKEN_DOWN`: first M15 close `< weekly_open` this week.
2. In `BROKEN_DOWN`: track the most recent qualifying **order block** = bearish
   M15 candle (`Close<Open`) whose HIGH is below `weekly_open` (candle entirely
   below the level [interpretation of "below the broken level"]) AND `extreme_vol`.
   Newest qualifying candle replaces older candidates.
3. `CONFIRMED`: an M15 close `> OB.high` while OB valid → place **BUY LIMIT** at
   `OB.high`, `SL = OB.low − sl_buffer_pips`, `TP = entry + 2*(entry−SL)` (1:2 RR —
   the only deterministic stated exit; other options documented, not built).
4. Pending management: limit expires at week end (weekly-level regime ends) or is
   replaced if a newer OB confirms first. Max ONE pending + ONE position per side
   per symbol; no averaging.
5. After fill: no re-arm on the same side until position closes; state resets
   weekly.

## Filters / session / MM

- No session filter stated → none (session=none). Framework news filter +
  Friday-close active (compliance layer). NOTE: Friday-close flattens weekend
  holds — a 1:2-RR intraweek reversal usually resolves in days; residual open
  positions get flattened Friday 21h broker (documented deviation from "open
  target" — this exit list includes 1:2 RR, so acceptable).
- Sizing: framework standard (RISK_FIXED backtest / RISK_PERCENT live) on the
  OB-defined stop distance.

## Edge cases

- Gap over limit price: limit fills at better price (standard); SL/TP recomputed
  from actual fill by framework helpers? NO — SL/TP are placed with the pending
  order (absolute prices from OB geometry); a gap-fill keeps the absolute SL/TP
  (risk only shrinks). [conservative]
- OB candle with zero range (High==Low): rejected (cannot define stop).
- Stop distance below broker stops-level: skip the setup and log (do not widen —
  the geometry IS the trade). [restrictive]
- Week rollover with pending: cancel pending at first bar of new week.
- Restart: pending/position are server-side; state machine re-derives from
  current week's bars deterministically on init (replay closed bars since weekly
  open).
- Both sides can arm in the same week sequentially; simultaneous opposite
  pending+position allowed only if OWNER-hedging is framework-legal — NOT
  allowed here: opposite setup is ignored while a position is open. [restrictive]

## Symbols / TF / frequency

- M15 [interpretation; TF unstated in source], Metals: XAUUSD.DWX (primary),
  XAGUSD.DWX (second slot). The author explicitly aims at gold/oil transfer.
- Expected frequency: weekly-level sweeps both sides, est. 30–100 setups/yr/symbol
  (episodic but well above the ≥5/yr floor).

## Params (source-fixed + flagged interpretations)

`vol_mult=2.0 [interp], vol_lookback=96 [interp], sl_buffer_pips=1 [interp],
rr_ratio=2.0, expiry=week_end [interp], tf=M15 [interp]`
