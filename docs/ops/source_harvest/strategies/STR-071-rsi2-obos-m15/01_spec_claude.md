# STR-071 — Claude independent spec (pre-reconciliation)

Source: thread 539300 (Kosomolate, ~2015; "NO LONG STORY"). Exec TF M15.
Cohort: EURUSD.DWX, GBPUSD.DWX (source names no pairs; the EA screenshots
imply one; test-design, flagged).

## Rules (verbatim table)

RSI(2, close) on closed M15 bars. BUY when RSI(1) < 30; SELL when RSI(1)
> 70 (strict). Entry next bar; SL 25 pips; TP 10 pips. TM: break-even —
when profit reaches +5 pips, move SL to entry + 1 pip (BE+1; mirror
short). One position; no reversal; re-entry only after flat AND a fresh
signal bar (the condition can persist across bars — mechanize: one entry
per signal EPISODE: RSI must return inside [30,70] before a new signal
arms; flagged — the source EA's behaviour is unknown).

Prior-build deltas (QM5_9703, codex T6): sessions, ATR/spread vetoes,
12-bar time exit, RSI-midline exit ADDED there — all absent here; the
25/10 + BE core matches.

## Inputs

```
strategy_rsi_period   = 2
strategy_buy_level    = 30.0
strategy_sell_level   = 70.0
strategy_sl_pips      = 25.0
strategy_tp_pips      = 10.0
strategy_be_trigger_pips = 5.0
strategy_be_plus_pips = 1.0
```

## Hooks sketch

Filter: M15/params/warmup ≥ 10/handle. Entry: episode-armed OBOS check
(own guard). Manage: BE move at +5 (once, retry-latched). Exit: false.
News: default.

## Notes

Inverted risk (SL 25 > TP 10) = high-WR scalper; churn ~300+/yr; author
claims (600%/yr, fixed lots) unaudited. Episode re-arm is THE
reconciliation point.
