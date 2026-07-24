# STR-066 — Claude independent spec (pre-reconciliation)

Source: thread 504229 (txfxtrader, 2014). Exec TF M15 (ledger). Cohort:
EURUSD.DWX, GBPUSD.DWX (the post's spread/ADR pair criteria are
instrument-selection guidance → test-design cohort, flagged).

## Version note

Post #1 is EDITED (final): RSI period "2 or 3" with 50 OS/OB; TF stack D1
(optional), H4, H1, M30, M15, M5, M1; TP 30; SL 20; MM discretion. The
p.2 requote preserves the pre-edit original (RSI 55, no H4, progressive
MM = martingale-class, EXCLUDED by hard rule and superseded anyway).
Prior build QM5_9702 mechanized the OLD version (RSI 55, M5 execution,
invented session/ADR/spread gates + M15-cross exit — G0_REVIEW_T6).
BASELINE = the edited post-#1 rules.

## Rules

1. RSI(period=2; "2 or 3" → 2 first-listed, 3 = variant) vs 50 on the
   stack {H4, H1, M30, M15, M5, M1} (D1 optional → excluded), each read
   at its own shift 1 (closed bars, 20097 MTF discipline).
2. LONG edge: all six RSI > 50 (strict) on the closed M15 evaluation bar
   AND alignment was NOT complete on the prior evaluation (edge trigger).
   SHORT mirror (all < 50).
3. Entry next bar; TP 30 pips; SL 20 pips; one position; no reversal.
4. Optional session-close: NOT built (option, "trader discretion").

## Inputs

```
strategy_rsi_period = 2
strategy_level      = 50.0
strategy_tp_pips    = 30.0
strategy_sl_pips    = 20.0
```

## Hooks sketch

Filter: M15/params/warmup per TF (H4 needs ≥ period+5 H4 bars etc.)/6
iRSI handles (one per TF). Entry: alignment edge (own guard; MTF
BarsCalculated checks). Manage: empty. Exit: false. News: default.

## Notes

Six-TF alignment is rare-ish but M1/M5 flip fast → moderate frequency
(~100-300/yr). "2 or 3" period ambiguity = reconciliation point.