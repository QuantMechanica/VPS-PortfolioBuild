# STR-040 — Claude independent spec (pre-reconciliation)

Source: thread 282290 (SteveHopwood shell; the STRATEGY is newark18's
"James SMA v2" rules, pages 2-5, with his literal MQL4 entry code). Exec TF
H4. Symbols: not source-bound → cohort EURUSD.DWX, GBPUSD.DWX (test-design,
flagged).

## Core rules (from newark18's posted code — the authoritative artifact)

LONG setup on closed H4 bars: bar2 bearish (close(2)<open(2)); bar1
"engulfing": close(1) > open(2) AND bar1 bullish (close(1)>open(1));
close(1) > SMA50(1) (close-priced). → BUY STOP at High(1), SL = Low(1).
SHORT mirror (SELL STOP at Low(1), SL = High(1)). No TP (his TP code was
abandoned). Exit: close all longs when an H4 candle CLOSES below the SMA50
(shorts: above) — his stated intent, implemented in ExitSignal (level
condition on closed bar).
One position (his shell was one-trade-at-a-time; his multi-trade ambition
never realized → not built).
Pending lifecycle (source silent): cancel the untriggered stop when the
exit condition (close crosses SMA against the setup) occurs OR when a new
opposite setup forms; refresh to the new signal bar's level when a NEW
same-direction setup forms (one pending max).

## Inputs

```
strategy_sma_period = 50
```

## Hooks sketch

Filter: H4/warmup 55+/handle. Entry: setup detection + pending via
QM_BUY_STOP/QM_SELL_STOP, SL at bar1 opposite extreme, TP 0. Manage:
pending lifecycle (cancel/refresh). ExitSignal: SMA-cross close (bar-gated
level read). News: default.

## Notes

- Overlap QM5_1117 (ledger) — verify distinction.
- SL = engulfing-bar extreme → variable risk; stops-level path needed.
- Frequency est. 30-80/yr/symbol.
