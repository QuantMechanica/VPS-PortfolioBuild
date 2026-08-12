# STR-079 — Claude independent spec (pre-reconciliation)

Source: thread 707474 (MickeyMar, ~2017). Exec TF M15. Cohort:
EURUSD.DWX, GBPUSD.DWX (author trades a pair basket; names none
binding → test-design, flagged).

## Rules

1. Channel: EMA(55, HIGH) upper, EMA(55, LOW) lower. Signal: EMA(33,
   CLOSE).
2. LONG signal: signal line crosses ABOVE the upper channel on the
   closed bar (sig(1) > up(1) AND sig(2) <= up(2)); SHORT: crosses BELOW
   the lower channel (mirror).
3. Entry modes (source-explicit):
   - NORMAL: price within 40 pips of the channel at signal → market
     entry.
   - DELAYED: price further than 40 pips from the channel → pending LIMIT
     at the EMA33 value, refreshed per bar to the current EMA33 while the
     signal stays valid; cancelled when the signal invalidates (opposite
     cross).
4. Hard stop 40 pips (the restrictive end of "40-50"; input).
5. EXIT BASELINE = the source's "no tp" mode: close at the opposite
   signal (ExitSignal, level condition). The fixed-40/BE and 210/session
   modes = documented variants (the author's session close needs invented
   hours; the BE mode is management-heavy — both unbuilt). NO
   stop-and-reverse in baseline (close only; fresh entry needs its own
   evaluation; flagged vs the author's close&reverse wording).
6. One position.

Prior QM5_9989 deltas (codex T6): spread veto + 16-bar pending expiry +
hard-selected exit branch without reconciliation — this build documents
the exit selection explicitly.

## Inputs

```
strategy_ch_period   = 55
strategy_sig_period  = 33
strategy_delay_pips  = 40.0
strategy_sl_pips     = 40.0
```

## Hooks sketch

Filter: M15/params/warmup ≥ 60/handles (3×iMA: high/low/close applied
prices). Entry: cross detection + normal/delayed mode (pending refresh
via Manage). Manage: delayed-pending refresh/cancel lifecycle.
ExitSignal: opposite-signal close (bar-gated). News: default.
