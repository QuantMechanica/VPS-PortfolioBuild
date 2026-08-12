# STR-127 — FINAL reconciled spec (build authority)

EA: QM5_20147 `ndx-ema50-momentum-d1` · TF D1 · Cohort: NDX.DWX.

## Rules (once per new D1 bar)

- EMA(50, close). Regime: Close[1] > EMA[1] → long side; < → short;
  == → cancel pending, no order.
- Flat + long side: replace the strategy pending with ONE buy stop at
  High[1], SL Low[1]. Short mirror (sell stop Low[1], SL High[1]).
  Replace at every D1 close; NEVER a ladder (house no-stacking,
  FLAG-127-01). Cancel on regime flip.
- Gap policy (FLAG-127-03): live pendings keep real stop semantics; a
  freshly calculated level already crossed at placement → skip the
  signal (no backfill, no chase).
- On fill: remove residual pendings; no new entries while positioned;
  EMA flip does NOT close the position; SL = signal bar's opposite
  extreme, never moved.
- Exit: at each completed D1 close after the fill, first close
  strictly profitable vs fill (gross, direction-signed) → market
  close next tick (per-bar retry latch). Same-day close eligible
  (FLAG-127-05). No TP, no time exit.
- Blackout invalidating the pending window → remove pending, consume
  that D1 signal.

## Inputs

```
strategy_ema_period = 50
```

## Flags

Author's own structural critique (losses span a full day's range,
wins often fractional; ~40% drawdown talk) = the recorded test
hypothesis (card R1). FTMO-Index-Swap caveat applies at Q06+ (swap
DEFERRED memo). Excluded: EMA-less variant, ATR sizing, swing rules.

## Hooks

Filter: D1/params/warmup ≥ 60. Entry: false — pending state machine in
Manage (daily replace, flip cancel, gap policy, profitable-close exit
with retry latch). Manage: as above. Exit: false. News: default
fail-closed. NO QM_IsNewBar(); own static D1 guard; ZeroMemory(req) +
symbol_slot.
