# STR-027 — Claude independent spec (pre-reconciliation)

Source: thread 1394867 "VR Gap" (Voldemar227; complete EA description; MQL5
code links 9994/72239). Exec TF D1 (ledger: Indices — gaps structural on
index daily bars). Symbols: NDX.DWX, GDAXI.DWX.

## Core rules (verbatim EA description)

1. On each NEW bar: gap = |Close(1) − Open(0)| (Open(0) = immutable new-bar
   open, the only shift-0 read). If gap > strategy_min_gap_points × point:
   - Open(0) < Close(1) (down-gap) → BUY at market.
   - Open(0) > Close(1) (up-gap) → SELL at market.
2. **Deferred protection attach** (source-explicit!): position opens WITHOUT
   SL/TP; Manage attaches on subsequent ticks: SL = fixed points from OPEN
   PRICE; TP = entry ± gap size (the gap-closure level = Close(1) of the
   signal bar). Stops-level verified before modify.
   HOUSE ADAPTATION (mandatory, 20098 lesson): attach attempt paced once per
   bar on rejection; if the market already attained the TP level before
   attach → close at market (rr/gap attained) — prevents the wrong-side-TP
   retry storm class. ALSO: framework REQUIRES a protective stop at entry —
   deviation decision: attach SL **at entry time** via the request (req.sl =
   fixed points), defer ONLY the TP (dynamic gap target) to Manage. This is
   more restrictive than the source (never unprotected) — tie-break 2.
3. One position per symbol; no filters (source-explicit: no indicators/
   news analysis — house news filter still gates entries).
4. Params: strategy_min_gap_points (source gives NO default → flagged;
   default mechanization: 50 points ≈ index-typical overnight gap floor,
   Q03 sweeps), strategy_sl_points (source gives no default → 300 points
   flagged; both reviewable).

## Inputs

```
strategy_min_gap_points = 50    // unsourced default, flagged; Q03 domain
strategy_sl_points      = 300   // unsourced default, flagged
```

## Hooks sketch

- NoTradeFilter: params sane; ≥3 D1 bars.
- EntrySignal: own new-D1-bar guard; no own position; gap test; market
  order with req.sl = fixed points (house deviation), req.tp = 0.
- Manage: if own position && TP == 0: target = gap-closure level (Close(1)
  of signal bar, cached at entry via static); if market already at/beyond
  target → close at market (STRATEGY_EXIT reason=gap_closed_pre_tp); else
  attach TP via QM_TM_MoveTP with per-bar retry pacing.
- ExitSignal: false. NewsFilterHook: default.

## Risks / notes

- Overlap QM5_10044 (prior VR-Gap build) — check variant/status.
- D1 index "gaps" on .DWX: session-close to next-open differences exist on
  GDAXI (cash hours) and NDX; if .DWX daily bars are near-continuous
  (futures-like), gap frequency may be tiny → Q02 floor risk; document.
- Unsourced defaults (min_gap, SL) are the weak point — both flagged for
  codex counter-proposal; Q03 sweep is the calibrator.
