# STR-127 — Claude independent spec (pre-reconciliation)

Source: babypips thread 1260721 (tommor, 2024-10). Exec TF D1.
Cohort: NDX.DWX (the author's instrument; "US indices" family —
NDX-only baseline, flagged).

## Rules (closed D1 bars)

1. EMA(50, close, D1). Regime: Close[1] > EMA50[1] → long side;
   below → short side; equality = none.
2. Long side: each day, (re)place ONE BUY STOP at High[1] (the
   just-closed day's high); SL = Low[1] (that same day's low).
   Refreshed every qualifying day (the pending follows yesterday's
   high/low). Short mirror while below (sell stop at Low[1], SL
   High[1]).
3. Cancel the untriggered pending when the close flips to the other
   side of the EMA50 (source verbatim) — then arm the mirror.
4. On fill: exit at the NEXT PROFITABLE CLOSE — mechanize: at each D1
   close after entry, if close is strictly profitable vs fill → market
   close at that bar's close evaluation (next tick). Position may run
   multiple days until the first profitable close; SL (opposite
   extreme of the signal day) protects meanwhile. FLAGGED: "profitable"
   measured vs fill price, gross.
5. While positioned: no new pendings (one position per magic; the
   source implies a new order daily even when positioned — bounded
   projection, flagged).
6. No TP. Author's own caveat recorded: losses = full day's range,
   wins often fractional; drawdown-heavy (thread #3, #7-9) —
   falsification candidate.

## Inputs

```
strategy_ema_period = 50
```

## Hooks sketch

Filter: D1/params/warmup ≥ 60. Entry: false — pending state machine in
Manage (daily re-point, regime flip cancel/mirror, profitable-close
exit with per-bar retry). Manage: as above. Exit: false. News:
default. FTMO-Index-Swap caveat (overnight index positions — swap
DEFERRED memo applies at Q06+).

Overlap: QM5_20120 simple-daily-3rise is a D1 pattern-entry EA;
different logic. No NDX-D1-EMA-momentum prior known — reconciliation
verifies.
