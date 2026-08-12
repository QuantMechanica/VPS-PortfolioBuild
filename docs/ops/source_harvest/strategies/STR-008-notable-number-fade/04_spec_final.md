# STR-008 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_notable-number-fade-m5` · TF M5 · Symbols (slots 0–7):
EURUSD.DWX, GBPUSD.DWX, EURGBP.DWX, AUDUSD.DWX, USDCAD.DWX, AUDNZD.DWX,
AUDCAD.DWX, EURCAD.DWX (USDJPY EXCLUDED — reconciliation #4, frequency
floor). Base: `framework/templates/EA_Skeleton.mq5`. Faithful-variant
rationale: QM5_10042 = M15 approximation with invented session-end close
(Q03-FAIL); this build = the author's corrected M5-openings semantics, pure
TP/SL exits.

## Inputs (group "Strategy"; defaults = EURUSD row; per-symbol values via
## card-table-patched set files)

```
input string strategy_notable_suffix     = "66";  // 2-4 digits, literal (leading zeros count)
input int    strategy_lookback_d1_bars   = 2;
input double strategy_sl_price_pct       = 0.50;  // percent of entry price
input double strategy_tp_price_pct       = 0.80;
input int    strategy_window_start_hhmm  = 1100;  // broker-clock window [start, end); start==end => all day
input int    strategy_window_end_hhmm    = 1600;
```

Per-symbol set values (source-fixed, reconciliation #1 broker-hours):
| Symbol | suffix | N | SL% | TP% | window broker |
|---|---|---|---|---|---|
| EURUSD | 66 | 2 | 0.50 | 0.80 | 1100-1600 |
| GBPUSD | 00 | 22 | 0.40 | 0.40 | 0000-0900 |
| EURGBP | 66 | 13 | 0.90 | 0.35 | 0200-0900 |
| AUDUSD | 33 | 42 | 0.55 | 0.85 | 0200-1900 |
| USDCAD | 88 | 9 | 0.75 | 0.15 | 0900-1100 |
| AUDNZD | 333 | 1 | 0.80 | 0.35 | 0000-0000 (all day) |
| AUDCAD | 55 | 43 | 0.60 | 0.40 | 1500-1800 |
| EURCAD | 44 | 23 | 0.55 | 0.65 | 1700-2000 |

## Lattice (codex 02 §2.1 verbatim)

pip_size = 0.01 (JPY-quote) else 0.0001; suffix width w=len(suffix);
level(q) = (q*10^w + suffix_value) * pip_size; a price is on-lattice when its
pip integer ends with the literal suffix. Levels normalized to trade tick.

## Hook 1 — NoTradeFilter (TRUE=block)

Block on: `_Period != PERIOD_M5`; suffix invalid (len<2 or >4, non-digits);
lookback<1; pcts<=0; window fields invalid; symbol trade disabled; warmup:
< lookback+2 closed D1 bars or <3 M5 bars. Nothing else.

## Hook 2 — EntrySignal

Own new-bar guard (M5). ZeroMemory + symbol_slot. No own position → else
false. Window: broker-time HHMM of the NEW bar's open in [start,end)
(start==end → always true). Compute prev_open = M5 open(1) (via QM_ReadBar),
cur_open = open(0) captured at first tick (iTime/iOpen shift 0 —
`// perf-allowed: immutable open of the just-formed bar, once per bar`).
Enumerate lattice levels strictly between the two opens (inclusive current):
- descending (prev>cur): candidate = HIGHEST crossed level; fade BUY iff
  min(Low(D1,1..N)) > level (strict; equality invalidates).
- ascending (prev<cur): candidate = LOWEST crossed level; fade SELL iff
  max(High(D1,1..N)) < level.
One-fire latch: static (last_d1_time, direction, level_pip_int) — if equal to
the candidate → false; set on fire. Bounded D1 scan gated by cached per-day
min/max (recompute on new D1 bar only, `// perf-allowed`).
Order: market; SL/TP = fill*(1∓sl_pct/100) / fill*(1±tp_pct/100) — computed
from request price at entry, normalized; framework sizes off the SL. Log
STRATEGY_ENTRY {dir, level, suffix, n_days, window}.

## Hooks 3–5

Manage: empty. ExitSignal: false. NewsFilterHook: framework default.

## Compliance

Registry magic (8 slots); RISK_FIXED/RISK_PERCENT convention; ≤1%/trade;
params are the author's optimizer output 1:1 (overfit risk recorded; Q02+
judges on FULL history); expected portfolio frequency ~50-70/yr across 8
symbols — per-symbol floor watch flagged (below-floor symbols RETIRE at
Q02 per economics rule).
