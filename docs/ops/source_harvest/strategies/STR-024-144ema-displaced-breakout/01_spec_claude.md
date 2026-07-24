# STR-024 — Claude independent spec (pre-reconciliation)

Source: thread 1348501 "144 ema method" (jamesagnew, ~2024). Exec TF M5.
Symbols: NOT source-stated → cohort mechanization: EURUSD.DWX, GBPUSD.DWX
(conventional M5 FX majors; flagged unsourced decision).

## Core rules (OP variant (a) — the ledger-bound baseline)

1. Indicators: EMA(34) displaced +16 bars ["trigger"], EMA(144) ["stop"].
   Displaced read: one unshifted EMA34 handle read at shift 1+16 = 17
   (equivalence per QM5_20103 precedent); EMA144 read at shift 1.
2. LONG: M5 close crosses ABOVE the displaced trigger:
   close(1) > trig(1) AND close(2) <= trig(2). SHORT mirror.
3. SL = EMA144 value at the signal bar (server-side, static; normalized). If
   SL is on the wrong side of entry or violates stops-level → skip + log
   (SETUP_CONFIG_INVALID). TP = 17 pips fixed.
4. One position; opposite signal does NOT reverse (exits are SL/TP only in
   variant (a)).
5. Variant (b) (author's follow-up: "enter and hold until opposite close
   signal", no TP/17) documented in card, NOT built.

## Inputs

```
strategy_trigger_ema_period = 34
strategy_trigger_shift      = 16
strategy_stop_ema_period    = 144
strategy_tp_pips            = 17.0
```

## Hooks sketch

- NoTradeFilter: M5; params sane; warmup ≥ 144+16+5 bars; handles valid /
  BarsCalculated sufficient.
- EntrySignal: own new-bar guard; no own position; cross detection (strict);
  SL from EMA144(1), TP 17 pips via framework helper.
- Manage: empty. ExitSignal: false. NewsFilterHook: default.

## Risks / notes

- R1: thread is openly skeptical (author "new strategy every night";
  MA-crossover non-robustness essays) — honesty-heavy falsification build;
  quality tier C−.
- SL distance variable (EMA144 distance at signal); frequently large on M5
  trends → RISK_FIXED sizes down; tiny distances near-crossings → stops-level
  skip path important.
- Overlap QM5_9944: check variant/status in reconciliation.
- Frequency: M5 cross system — hundreds/yr; churn judged by Q02.
