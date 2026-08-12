# STR-143 — FINAL reconciled spec (build authority)

EA: QM5_20152 `sma-cross-pullback-h1` · TF H1 · Cohort: EURUSD.DWX
(the single illustrated symbol; multi-pair = labeled variant).

## Arming / entry (closed H1 bars; IDLE / ARMED_LONG / ARMED_SHORT)

- Bull cross: SMA100[1] > SMA200[1] AND SMA100[2] ≤ SMA200[2] →
  ARMED_LONG. Bear mirror. New opposite cross replaces the arm;
  equality after arming cancels until a fresh cross.
- LONG trigger: first STRICTLY LATER completed bar with K[2] ≤ 25 AND
  K[1] > 25 while SMA100[1] > SMA200[1] (same-bar-as-cross cannot
  trigger). SHORT mirror through 75. Stoch(14, 3, 3, MODE_SMA,
  STO_LOWHIGH); K-line level cross, NOT a K/D cross.
- Trigger consumes the arm (accept or reject); later stoch moves in
  the same regime cannot enter — fresh cross required. Entry next bar
  market; one position per magic.

## Risk / exits

- From actual fill: SL = fill ∓ 150 pips, TP = fill ± 300 pips, both
  server-side atomically; reject invalid geometry, never widen.
- BE: when a COMPLETED bar's favorable extreme reaches fill ± 150
  pips, latch; move SL to normalized fill on the next bar,
  tighten-only, once. Broker fills before the update are final.
- No recross/stoch/time exits, no partials, no trailing beyond BE.

## Inputs

```
strategy_sma_fast = 100
strategy_sma_slow = 200
strategy_stoch_k = 14
strategy_stoch_d = 3
strategy_stoch_slowing = 3
strategy_os_level = 25.0
strategy_ob_level = 75.0
strategy_sl_pips = 150.0
strategy_tp_pips = 300.0
strategy_be_trigger_pips = 150.0
```

## Hooks

Filter: H1/params/warmup ≥ 202. Entry: armed machine + level-cross
trigger (QM_Stoch_K pooled reader — STO_LOWHIGH is the pool default).
Manage: BE once-latch per closed bar with next-bar move + retry
pacing. Exit: false. News: default fail-closed. NO QM_IsNewBar(); own
static guards; ZeroMemory(req) + symbol_slot.

Overlap: distinct from QM5_20138 (stoch-zone H4) and QM5_20143
(EMA-campaign M5) — 03_reconciliation.md.
