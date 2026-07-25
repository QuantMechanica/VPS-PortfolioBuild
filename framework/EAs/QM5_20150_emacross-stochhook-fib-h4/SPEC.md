# QM5_20150_emacross-stochhook-fib-h4 - Strategy Spec

**EA ID:** QM5_20150
**Slug:** `emacross-stochhook-fib-h4`
**Source:** BP-PHILIPPIRRIP-EMASTOCH-70731 (see card QM5_20150)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---


EA: QM5_20150 `emacross-stochhook-fib-h4` · TF H4 · Cohort:
EURUSD.DWX, USDJPY.DWX (author's worked example USDJPY; test-design).

## Arming (closed H4 bars; state IDLE / ARMED_LONG / ARMED_SHORT)

- Bull cross: EMA20[1] > EMA50[1] AND EMA20[2] ≤ EMA50[2]. Arm long
  ONLY if K[1] ≥ 80 at the cross bar (the source's defining pattern);
  else ignore the whole regime. Bear mirror (K[1] ≤ 20).
- ImpulseStart = extreme of the entire preceding opposite-EMA regime
  incl. the cross bar (parameter-free); recorded at arming.
- Cancel armed state on EMA recross (a recross on the trigger bar
  cancels, never enters).
- OppositeExtremeSeen: armed-long latches when a completed bar has
  K ≤ 20 (short: K ≥ 80).
- HOOK (long): after the latch, K[2] ≤ D[2] AND K[1] > D[1] AND
  min(K[1], D[1]) ≤ 20. Short mirror (max ≥ 80). First hook consumes
  the setup (accept or reject). Entry next bar market if EMA order
  still holds + gates pass.
- Stoch(14, 3, 1, MODE_SMA, STO_CLOSECLOSE); EMAs PRICE_CLOSE.

## Risk / exits

- ImpulseEnd = directional extreme cross→hook (frozen at hook close);
  L = |ImpulseEnd − ImpulseStart| (reject non-positive).
  F(r) = ImpulseStart ± r·L.
- HARD server SL at ImpulseStart ∓ 10 pips (LABELED deviation
  STR137-D1: the author's mental-stop doctrine is inadmissible).
- Fib ladder {1, 1.272, 1.618, 2, 2.618, 3, 3.618, 4, 4.618, 5}:
  first close ≥ F(1) → stop = entry (BE); close ≥ F(1.272) → stop =
  F(1); each later ratio → stop = previous ratio. Ratchet-only,
  applied next bar, capped at F(4.618) (STR137-D2/I7). No TP.
- Opposite completed setup → close next bar (no same-bar reverse).

## Inputs

```
strategy_ema_fast = 20
strategy_ema_slow = 50
strategy_stoch_k = 14
strategy_stoch_d = 3
strategy_stoch_slowing = 1
strategy_ob_level = 80.0
strategy_os_level = 20.0
strategy_sl_buffer_pips = 10.0
```

## Hooks

Filter: H4/params/warmup (regime scan needs deep history — cap the
regime walk at 500 bars, log if hit). Entry: armed machine + hook (per
final rules; EntrySignal path). Manage: fib-ladder server-stop ratchet
per closed bar + opposite-setup close, retry latches. Exit: false.
News: default fail-closed. NO QM_IsNewBar(); own static guards;
ZeroMemory(req) + symbol_slot; QM_Stoch_K/D pooled readers ONLY if
CLOSE/CLOSE is supported — else pool-registered handle with inline
perf-allowed (20138 precedent).
