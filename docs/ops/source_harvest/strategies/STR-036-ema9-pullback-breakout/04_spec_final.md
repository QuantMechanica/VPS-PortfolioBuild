# STR-036 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_ema9-pullback-m15` · TF M15 · Symbol (slot 0): GBPUSD.DWX.
Base: EA_Skeleton.

## Inputs (group "Strategy")

```
input int    strategy_ema_period      = 9;
input double strategy_min_gap_pips    = 5.0;
input double strategy_sl_buffer_pips  = 1.0;   // + current spread at entry
input double strategy_rr              = 2.0;
```

## State machine (closed bars; own new-bar guard; restart-replay from
## recent bars — no files)

- CROSS event (shift 1 closes across EMA9 vs shift 2 on the other side)
  opens/flips the directional SETUP (any pending old setup invalidated).
- Each closed bar while a setup is armed is a CANDIDATE: LONG candidate
  qualifies iff low(1) − ema9(1) ≥ 5 pips AND close(1) > high(2). First
  qualifying candidate → entry at next bar; setup CONSUMED (no re-entry
  until a fresh cross). SELL mirror (source sell-side typo read as above
  prev high; documented).
- No own position may exist (one position).
- SL = low(2) − (1 pip + current spread) for long (mirror short); TP =
  entry + strategy_rr × (entry − SL). Invalid geometry → skip + log,
  setup stays consumed.

## Hooks

1 NoTradeFilter: M15; params; warmup ≥ 20 bars; handle valid.
2 EntrySignal: machine above. 3 Manage: empty. 4 ExitSignal: false.
5 NewsFilterHook: default.

## Compliance

Registry magic slot 0; RISK_FIXED/RISK_PERCENT; ≤1%/trade; R1 honesty
(thread died; author withheld extra rules privately — stated ruleset built
verbatim); frequency est. 100-200/yr.
