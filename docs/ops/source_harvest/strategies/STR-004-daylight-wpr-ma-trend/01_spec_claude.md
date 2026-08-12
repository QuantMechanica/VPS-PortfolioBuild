# STR-004 — Claude independent spec (pre-reconciliation)

Source: thread 1086170 "Daylight" (LauraT), first 3 pages (60 posts). Exec TF
M15, market indices (author: "indices can be traded on 5m"; 15m = base).
Symbols: NDX.DWX, GDAXI.DWX (M15).

## Indicator set (all closed-bar, shifts ≥1)

- Main chart: `green = SMMA(5, close)`, `red = SMMA(5, close, shift +5)`
  (native `iMA(sym, tf, 5, 5, MODE_SMMA, PRICE_CLOSE)`).
- Sub-window: `wpr = iWPR(14)`; on the WPR SERIES two smoothed MAs computed
  in-EA (no indicator-on-indicator handle in an EA): `sub_fast = SMMA(8) of
  wpr`, `sub_slow = SMMA(21) of wpr`. SMMA recursion
  `s[i] = (s[i-1]*(n-1) + x[i]) / n`, seeded with SMA(n) at a FIXED depth
  (default 400 closed bars back) — deterministic and restart-safe.

## Entry rules (short; long mirror)

On each new closed M15 bar (all reads shift 1 / shift 2):
1. **Main-chart daylight:** `red(1) > green(1)` AND `red(2) > green(2)`
   (separation exists now and on the prior bar — mechanization of "daylight
   exists"; strictly positive gap, 2-bar persistence).
2. **Trigger:** `close(1) < green(1)` AND `close(2) >= green(2)` (the CLOSE
   crosses below the green MA — first close beyond, not every bar below).
3. **Sub-window daylight:** `sub_fast(1) > sub_slow(1)` AND
   `sub_fast(1) − sub_slow(1) >= strategy_sub_daylight_min` (author p.17:
   "difference ... should be around 4 or more" → default 4.0 WPR points).
4. No own position (no stacking; author's add-to-winner = variant, not built).

## Exit (variant 1 = rules-based option 2 of the source)

- **Rule exit:** main-chart MAs cross back (`red` vs `green` relation flips on
  a closed bar) → close at market. (Option 2 chosen: it is the tightest fully
  mechanical rule of the four source options; options 1/3/4 documented in the
  card as variants.)
- **Emergency stop (source: "emergency stops far away from price"):**
  SL = entry ∓ `strategy_emergency_atr_mult` × ATR(14, M15) (default 3.0),
  set at order time (framework requires a protective stop; mechanizes the
  author's far-away emergency stop). Never trailed, never widened.
- No TP (author takes discretionary profits; nearest mechanical analogue is
  the cross-back exit).

## Inputs

```
input int    strategy_main_ma_period      = 5;
input int    strategy_main_ma_shift      = 5;
input int    strategy_wpr_period          = 14;
input int    strategy_sub_fast_period     = 8;
input int    strategy_sub_slow_period     = 21;
input double strategy_sub_daylight_min    = 4.0;  // WPR points, source p.17
input int    strategy_atr_period          = 14;
input double strategy_emergency_atr_mult  = 3.0;
input int    strategy_smma_seed_depth     = 400;  // fixed recursion seed
```

## Hooks sketch

- **NoTradeFilter:** params sane; warmup ≥ seed_depth+30 M15 bars; handles
  (iMA green, iMA red-shift, iWPR, iATR) valid.
- **EntrySignal:** rules above; market order; SL emergency-ATR; TP 0.
- **Manage:** per new closed bar: cross-back check → `QM_TM_ClosePosition`
  (log `STRATEGY_EXIT reason=ma_cross_back`). No SL moves.
- **ExitSignal:** false (exit lives in Manage's bar-gated check).
- **NewsFilterHook:** framework default (author: flat before major news —
  house filter covers).

## Notes / risks

- The in-EA SMMA-on-WPR series is the one non-trivial computation: cache per
  closed bar (recompute on new bar only), O(seed_depth) per bar worst case —
  gate strictly by new-bar; add `// perf-allowed` markers.
- WPR shift semantics: sub-window MAs computed on WPR values at closed bars
  only; the author's "First Indicator Data" application = plain series MA.
- Frequency: M15 indices trend-pullback — est. 100-300 signals/yr/symbol;
  churn risk high; Q02 economics judge.
- Overlap QM5_9956 (ledger): verify distinction in reconciliation (9956 =
  earlier WPR/daylight-family build from the pre-harvest funnel; this build is
  the faithful LauraT variant with shifted-SMMA main chart).
- The -50 trend-filter and standalone--50 variants (thread EDITs) are NOT in
  the first-3-pages extract detail — out of scope, noted as variants.
