# STR-049 — Claude independent spec (pre-reconciliation)

Source: thread 325369, Forexcube's "Do the Right Thing" CCI article
(p.19-22 — the mechanized core per ledger). Exec TF H1 (article: daily or
hourly; ledger H1). Cohort: EURUSD.DWX, GBPUSD.DWX (article names no
pairs; test-design, flagged).

## Rules (LONG; short mirror at −100)

1. CCI(20) on closed H1 bars.
2. Excursion tracking: when CCI drops back below +100, record the PEAK of
   the just-finished above-+100 excursion as prior_peak (state;
   replay-derived on restart).
3. Signal: CCI(1) > +100 AND CCI(1) > prior_peak (a NEW momentum high) →
   market entry next bar ("go long at market at the close of the candle").
   One fire per excursion; a later signal requires a fresh excursion
   exceeding the then-prior peak.
4. SL = Low(signal bar) (mirror: High).
5. MM (netted, 20101 partial-close machinery): at +1R close HALF and move
   SL to breakeven; TP remainder at +2R (server-side at entry).
6. One campaign; no reversal.

Prior-build deltas (QM5_10000, per codex G0_REVIEW_T6 contest): it added
an ATR stop buffer, max-range veto, CCI-zero exit and 36-bar time exit and
OMITTED the +1R half realization — all absent here (faithful build).

## Inputs

```
strategy_cci_period    = 20
strategy_trigger_level = 100.0
```

## Hooks sketch

Filter: H1/params/warmup >= 40/handle (iCCI). Entry: excursion state
machine (replay ~400 bars for prior_peak on restart). Manage: half-close
at +1R touch + BE move (per-bar retry latch); TP2 server-side. Exit:
false. News: default.

## Notes

Frequency est. 40-100/yr/symbol; article provenance (Investopedia-style
piece reposted in-thread, 2008) — quality tier C+.
