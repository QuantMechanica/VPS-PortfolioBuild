# STR-004 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_daylight-wpr-smma-m15` · TF M15 · Symbols (slots 0–1): NDX.DWX,
GDAXI.DWX · Base: `framework/templates/EA_Skeleton.mq5`. Faithful-variant
rationale: QM5_9956 = H4/FX approximation with invented thresholds (0.05×ATR
gap, 1.2R TP, time stop) — Q02-FAIL; this build = LauraT's M15 indices
baseline, exit option 2, minimal mechanization.

## Inputs (group "Strategy")

```
input int    strategy_ma_period          = 5;    // SMMA close; red = same series read at +5 displacement
input int    strategy_ma_displacement    = 5;
input int    strategy_wpr_period         = 14;
input int    strategy_sub_fast_period    = 8;
input int    strategy_sub_slow_period    = 21;
input double strategy_sub_daylight_min   = 4.0;  // WPR units, source p.17 "around 4 or more"
input int    strategy_atr_period         = 14;
input double strategy_emergency_atr_mult = 4.0;  // mechanizes "emergency stops far away" (unsourced value, flagged)
input int    strategy_smma_seed_depth    = 400;  // fixed recursion seed depth (determinism)
```

## Indicators / state

- `g_h_ma` = iMA(sym, M15, 5, 0, MODE_SMMA, PRICE_CLOSE) — UNSHIFTED; green(s)
  = buffer[s]; red(s) = buffer[s + displacement] (≡ native plot-shift; one
  handle, both lines).
- `g_h_wpr` = iWPR(14); `g_h_atr` = iATR(14).
- Sub-window SMMAs computed in-EA on the WPR closed-bar series: recursion
  `s[i] = (s[i-1]*(n-1) + wpr[i]) / n`, seeded with SMA(n) starting exactly
  `strategy_smma_seed_depth` closed bars back; recomputed ONLY on a new closed
  bar (cached: values for shift 1 and shift 2), bounded O(seed_depth),
  `// perf-allowed` markers. WPR buffer read via CopyBuffer over the window.
- Full-condition truth cache per direction for shift 1 and shift 2 (edge
  trigger); `g_last_signal_bar` own new-bar guard (never QM_IsNewBar — the
  skeleton consumes that edge).

## Entry condition (LONG; short = exact mirror)

At new closed bar, all at shift 1 (prev values at shift 2):
C1: `green(1) − red(1) ≥ 1 trade tick` (main-chart daylight)
C2: `Close[1] > green(1)` (strict)
C3: **Sub-window daylight (ledger-bound colours: Red=SMMA8, Blue=SMMA21 of
    WPR(14)).** SHORT: `sub_fast8(1) − sub_slow21(1) ≥ 4.0` (Red above Blue —
    source rule 3 verbatim). LONG mirror: `sub_slow21(1) − sub_fast8(1) ≥ 4.0`.
    RESOLUTION NOTE: claude's 01 spec initially argued the inverse
    (trend-alignment reading); the validated SOURCE_LEDGER row explicitly
    binds Red=8/Blue=21 (from the original harvest read of the thread
    charts), confirming codex's literal mapping. Mechanically this makes C3 a
    PULLBACK-DEPTH condition: at a short entry the prior pullback lifted the
    fast WPR SMMA well above the slow one (≥4 units of "daylight"), and the
    close back through the green line catches the rollover; chop never
    separates the two SMMAs by ≥4 and is filtered — consistent with the
    author's anti-sideways framing. Decided; not an open item.
FULL condition true at shift 1 AND false at shift 2 (edge) → signal.
No own position; opposite condition never reverses.

## Order

Market at next-bar first tick (skeleton semantics). SL = fill ∓
`strategy_emergency_atr_mult × ATR(1)` (normalized away from fill;
stops-level clamp widen-only; sizing = framework RISK_FIXED at that stop).
TP = 0. Log STRATEGY_ENTRY {dir, close, green, red, sub_fast, sub_slow, atr,
sl}.

## Hooks

1. **NoTradeFilter (TRUE=block):** period ≠ M15; param sanity; warmup <
   seed_depth + slow_period + 30 closed bars; handles invalid /
   BarsCalculated insufficient (ma/wpr/atr). Nothing position-related.
2. **EntrySignal:** as above.
3. **Manage:** empty (no trailing, no widening; protection is server-side).
4. **ExitSignal:** own closed-bar read: long open AND `red(1) ≥ green(1)` →
   true (log STRATEGY_EXIT reason=ma_recross before returning); short mirror.
   Level condition (not cross event) — restart-safe. Bar-gated internally
   (evaluate once per closed bar; return cached false otherwise).
5. **NewsFilterHook:** framework default.

## Compliance

Magic registry; RISK_FIXED/RISK_PERCENT convention; ≤1%/trade at emergency
stop (wide stop → small size; if sizing floor impossible → skip, log);
no stacking/martingale/grid/ML; news/Friday/KS framework-owned. Frequency
est. 100–300/yr/symbol — churn judged by Q02+.
