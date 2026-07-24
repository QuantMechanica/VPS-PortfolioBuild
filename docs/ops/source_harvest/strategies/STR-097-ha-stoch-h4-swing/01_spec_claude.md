# STR-097 — Claude spec (independent, pre-reconciliation)

Strategy: **HA + Stoch trend-pullback swing (H4)** — trend-following pullback
re-entry in the direction of the 100-SMA trend, triggered by a Heiken-Ashi colour
flip confirmed by a Stochastic(8,3,3) cross, evaluated strictly on H4 closed bars.

## Definitions (closed-bar, no repaint)

- HA candles computed classically: `ha_close=(O+H+L+C)/4`;
  `ha_open=(ha_open[1]+ha_close[1])/2`; colour green iff `ha_close>ha_open`.
  Computed from completed H4 OHLC only (evaluate on new-bar open of bar 0 using
  bars 1..N).
- `SMA100` = simple MA of CLOSE, period 100, H4.
- `Stoch(8,3,3)` low/high price field (MT5 STO_LOWHIGH), %K slowing 3, %D 3.
- All conditions evaluated once per new H4 bar on bar indices ≥1.

## Entry

LONG (all on the just-closed bar b1 = index 1, prior bar b2 = index 2):
1. Trend: `Close[b1] > SMA100[b1]`.
2. Pullback existed: at least 2 consecutive RED HA candles in the window
   b2..b6 immediately preceding the flip (i.e. HA[b2] red and HA[b3] red —
   minimal deterministic reading of "green followed by red" pullback).
3. Flip: `HA[b1]` is GREEN and `HA[b2]` is RED.
4. Stoch confirm: `%K[b1] > %D[b1]` AND `%K[b2] <= %D[b2]` (fresh cross on the
   trigger bar or the bar before it — allow cross on b2 with %K[b1]>%D[b1] still
   true) AND the cross occurred in the LOWER region: `%D at the cross bar < 50`
   (source says "towards the bottom of the stochs window"; no numeric level is
   stated — 50 = least-restrictive deterministic reading of "bottom half";
   flagged as interpretation for reconciliation).
5. No open position/pending for this magic (framework duplicate guard).
SHORT = full mirror (Close<SMA100, 2 green HA then red flip, %K crosses below %D
in the UPPER region %D>50).

Entry execution: market order at the open of the new H4 bar after signal close
(source: "wait for the 4 hour candle to close and open your trade").

## Exit / SL / TP — variant 2 (primary; fully deterministic as stated)

- Initial SL: 50 pips from entry (pip = 10*point on 5-digit FX symbols; framework
  pip helper).
- TP: 50 pips.
- Break-even move: when floating profit reaches +25 pips, move SL to entry+1 pip
  (long) / entry−1 pip (short). One-shot, never moved back.
- Additionally exit at market if an opposing ENTRY signal triggers (trend-flip
  protection; conservative reading — the source holds to TP/SL in variant 2, so
  this extra exit is OFF by default input `strategy_exit_on_opposite=false`).
- Variants 1/3 (HA-flip exit / partial-take) are source variants but their
  trailing is unquantified → NOT implemented in this build; documented for a
  possible later card variant. No invented trailing.

## Filters / session

- None stated in source → none beyond framework standard (news filter active
  fail-closed, Friday-close default-on 21h broker — framework compliance layer,
  not strategy logic).

## Money management

- Framework standard: RISK_FIXED for backtest / RISK_PERCENT live; risk maps to
  the 50-pip initial stop. No source-specific sizing (source discusses lots only
  in variant 3's split, which we don't build).

## Edge cases

- Gap through SL/TP: broker-side pending SL/TP orders (framework sets server-side
  SL/TP at entry) — fills at market on gap.
- Weekend: Friday-close (framework) flattens before rollover; no weekend holds.
- Missing bars / low liquidity: signal evaluation only on completed bars; no
  intra-bar action except the BE move (tick-evaluated, threshold-based).
- Signal while position open (same direction): ignored (no pyramiding — none
  stated in source).
- Opposite signal while open: ignored in variant 2 default (see above).
- Restart mid-trade: SL/TP live server-side; BE-move state re-derived from
  position P&L (if floating ≥ +25 pips and SL < entry+1 → apply move; idempotent).

## Symbols / timeframe / frequency

- H4; FX .DWX: GBPUSD, EURAUD, USDCHF, EURCAD (the four source-demonstrated pairs).
- Expected frequency: author claims ≥5/week across watchlist; conservatively ≥1
  per week per symbol in trending regimes, worst case ~25–60 trades/yr/symbol —
  comfortably above the Q02 floor (≥5/yr).

## Params (source-fixed, no optimization)

`sma_period=100, stoch_k=8, stoch_d=3, stoch_slow=3, stoch_zone=50,
pullback_min_bars=2, sl_pips=50, tp_pips=50, be_trigger_pips=25, be_offset_pips=1`
