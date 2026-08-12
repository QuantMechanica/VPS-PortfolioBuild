# STR-103 — Claude spec (independent, pre-reconciliation)

Strategy: **3 Little Pigs multi-TF SMA trend swing** — enter with the aligned
W1/D1 trend on an H4 pullback-touch of SMA34 that closes back in trend direction;
ATR-scaled stop behind SMA34, SMA-following ratchet trail, no fixed target.

## Definitions (closed-bar discipline)

- `SMA55_W1`, `SMA21_D1`, `SMA34_H4`: simple MAs of CLOSE on their TFs, computed on
  CLOSED bars only (shift ≥1 on each TF). Evaluated at each H4 bar close.
- `ATR14_H4`: ATR(14) on H4, closed bars.
- ATR offset (deterministic mapping of the source's "indicator-window high+low"):
  `offset_pips = 0.25 * (Highest(ATR14_H4, LB) + Lowest(ATR14_H4, LB))` in pips,
  lookback `LB = 100` closed H4 bars (proxy for the author's visible chart window;
  flagged interpretation — reconciliation item).
- Evaluation once per new H4 bar; trigger bar b1 = last closed H4 bar.

## Entry

LONG (all at b1 close):
1. `Close[b1] > SMA55_W1` (last closed W1 SMA) AND `Close[b1] > SMA21_D1`.
2. Touch-and-close: `Low[b1] <= SMA34_H4[b1]` AND `Close[b1] > SMA34_H4[b1]`.
3. No open position/pending this magic.
Entry: market at open of next H4 bar (source enters "on close"; framework
executes at next-bar open — same price event, no look-ahead).
STAGED-ALIGNMENT (source's "one other rule"): if condition 2 fired while 1 was
false, arm a `staged` flag; when 1 becomes true at a later H4 close AND
`Close > SMA34_H4` still holds, enter at the close of the NEXT H4 candle (one
further completed bar with Close on the trend side). The staged flag clears if
price closes back through SMA34 before alignment completes.
SHORT = full mirror.

## Exit / SL / Trailing

- Initial SL (long): `SMA34_H4[b1] − offset_pips`; (short): `SMA34_H4[b1] + offset_pips`.
  If entry price − SL < broker stops-level, widen to minimum legal distance
  (framework clamp) and log.
- Trailing: at each NEW H4 bar close, recompute `SMA34_H4 − offset_pips` (long);
  if it is HIGHER than the current SL, move SL up (ratchet only; never loosen).
  Mirror for short. offset recomputed with current ATR values each update.
- No TP (open target). Exit only via SL/trail hit (server-side), framework
  Friday-close, or kill-switch paths.
- Re-entry after stop-out: allowed — normal entry rules re-evaluate on subsequent
  bars (no cooldown stated; none added).

## Filters / session / MM

- No session/news filter stated → framework standard compliance layer only.
- Risk: source states 1%/trade → framework RISK_PERCENT=1.0 intent for live
  (backtest RISK_FIXED per convention); risk maps to the ATR-scaled initial stop
  distance. Within the 1% default per-trade cap.

## Edge cases

- SL distance varies per signal (ATR-scaled): floor at stops-level, cap risk via
  framework sizing (lots scale to distance).
- Restart mid-trade: SL is server-side; on init, resume trailing from current SL
  (ratchet logic is stateless: proposed SL vs current SL comparison).
- Staged flag persistence: in-memory only; after restart the staged setup is
  re-derived if still valid on the next H4 close, else naturally dropped
  (conservative: missing one staged entry ≤ inventing one).
- Both-direction signals same bar: impossible (mutually exclusive alignment).
- Weekend: framework Friday-close flattens; Monday re-entry per rules.

## Symbols / TF / frequency

- H4 execution; the source's 8 pairs, .DWX: AUDUSD, EURGBP, EURJPY, EURUSD,
  GBPUSD, USDCAD, USDCHF, USDJPY (8 slots).
- Expected frequency: swing with re-entries, est. 10–40 trades/yr/symbol —
  above the Q02 floor.

## Params (source-fixed)

`sma_w1=55, sma_d1=21, sma_h4=34, atr_period=14, atr_lookback=100,
atr_offset_factor=0.25, risk_percent_live=1.0, staged_entry_enabled=true`
