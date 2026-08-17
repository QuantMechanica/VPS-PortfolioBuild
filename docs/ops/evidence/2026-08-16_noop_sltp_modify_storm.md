# No-op SLTP modify storm — 6.2 M rejected requests in one day (2026-08-16)

## Symptom

Two Q02 rows died as `summary_missing` / `INFRA_FAIL` after ~90 minutes each,
three attempts apiece, producing no report at all:

| Work item | EA | Symbol | Phase | Ended (UTC) |
|---|---|---|---|---|
| `7771ffb7` | QM5_20176 | XAUUSD.DWX | Q02 | 18:46:45 |
| `da89eae6` | QM5_20178 | XAUUSD.DWX | Q02 | 20:40:01 |

Both payloads: `final_failure = summary_missing_retries_exhausted`,
`failure_class = UNCLASSIFIED`, `failure_class_evidence = "no terminal_exit
signature and no discriminating token"`, `run_smoke_exit_code = None`.

The classifier was right that it had nothing to go on. The cause was not in the
work item at all — it was in the terminal's I/O.

## Measurement

Tester journals for 2026-08-16, all ten factory terminals:

| Terminal | Journal | `failed modify … [Invalid stops]` |
|---|---|---|
| T3 | 782 MB | 2,359,039 |
| T1 | 485 MB | 1,407,818 |
| T8 | 367 MB | 1,139,948 |
| T5 | 241 MB | 704,651 |
| T2 | 207 MB | 592,793 |
| T4, T6, T7, T9, T10 | 32–66 MB | 0 – 162 |
| **Total** | **2,299 MB** | **6,204,547** |

Attribution by the `Tester "QM\<ea>.ex5"` marker that precedes each run:

| EA | Rejections | Symbols |
|---|---|---|
| **QM5_20176** | **6,204,436** | NDX, GBPUSD, USDJPY, XAUUSD, EURUSD, WS30 |
| QM5_21001 | 172 | USDJPY, EURUSD |
| QM5_1626 | 66 | EURUSD |

So it is **one EA on every symbol it touched**, not a symbol-specific effect.
The earlier working hypothesis ("XAUUSD-specific log bomb") was wrong: XAUUSD
was simply where the failure crossed the run budget first.

## Root cause

The rejected requests are literally no-ops. Sample from T8:

```
2019.04.10 01:01:01  failed modify #12 buy 0.89 XAUUSD.DWX
                     sl: 1294.87, tp: 0.00 -> sl: 1294.87, tp: 0.00 [Invalid stops]
2019.04.10 01:01:03  (identical)
2019.04.10 01:01:03  (identical)
2019.04.10 01:01:04  (identical)
```

Before and after are the same stop. The mechanism:

1. A trail caller reads `cur_sl = PositionGetDouble(POSITION_SL)` and compares
   its **raw** target against it — e.g. QM5_20176 stage 2:
   `if(sar_1 > 0.0 && sar_1 < bid && (cur_sl <= 0.0 || sar_1 > cur_sl))`.
2. `QM_TM_SendSLTPModify` then **normalizes** the target:
   `request.sl = QM_TM_NormalizePrice(symbol, new_sl)` →
   `NormalizeDouble(price, digits)`.
3. When `raw > cur_sl` but `NormalizeDouble(raw) == cur_sl` — trivially common
   on a 2-digit symbol like XAUUSD, where anything under half a cent of
   improvement rounds away — the request asks the server to change nothing.
4. MT5 rejects a no-op SLTP modify as `[Invalid stops]`, which is why this was
   repeatedly mis-read as a stop-distance problem.
5. The position is unchanged, so the caller's condition is still true on the
   next tick, and it re-sends the identical request. Forever.

Each rejection is a synchronous journal write inside the run. That is the
throughput cost: ~2.3 GB of writes, and heavy-symbol runs crossing their budget.

Note what is **not** wrong: the trail still progresses. Once PSAR/ATR moves far
enough that the normalized target genuinely differs, the modify succeeds. The
completed Q02 verdicts from these runs are therefore economically valid — the
damage is runtime, not evidence.

## Why the existing guard did not catch it

The 2026-07-20 modify-hygiene audit had already diagnosed this exact symptom
("re-send the identical request every tick — `[Invalid stops]` journal spam +
wasted round-trips") and built both a retry-window suppressor and a stops-level
pre-check. It then gated **the whole machinery** behind:

```mql5
const bool live_hygiene = (MQLInfoInteger(MQL_TESTER) == 0);
```

That containment is correct for the retry *window*: suppressing a target for
30 s can delay a legitimately changed break-even and shift tester fills against
the historical `RISK_FIXED` evidence. It was too broad for the no-op case, and
the no-op case is where the cost lives.

## Fix (commit `8cabfe613`)

A stateless identity guard in `QM_TM_SendSLTPModify`, placed **before** the
live-only block and active in tester and live alike:

```mql5
const double live_sl = PositionGetDouble(POSITION_SL);
const double live_tp = PositionGetDouble(POSITION_TP);
const double price_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
const double same_eps = (price_point > 0.0) ? (price_point * 0.5) : 1e-10;
if(MathAbs(request.sl - live_sl) < same_eps && MathAbs(request.tp - live_tp) < same_eps)
   return false;   // request changes nothing — the server would reject it unchanged
```

### Equivalence argument

- The server rejects a no-op SLTP modify and leaves SL/TP untouched. Not
  sending it leaves SL/TP untouched. **Position state is identical.**
- Both paths return `false` to the caller. **Control flow is identical.**
- The guard writes no state — in particular it does not call
  `QM_TM_RememberFailedModify`, so the live retry window behaves exactly as
  before for genuine rejections.
- It has no time window, so it can never delay a target that *does* change.
  This is the property the 2026-07-20 containment was protecting, and it is
  preserved.

### Observable differences

- One MT5 journal line per suppressed no-op is no longer written. This is the
  entire point.
- One `QM_WARN` `TM_MODIFY` stream event per suppressed no-op is no longer
  emitted. The only consumer is
  `tools/strategy_farm/ftmo_trial_pulse.py` → `SERVER_REQUEST_EVENTS`, which
  counts **live server requests**. Not sending a request the server rejects
  makes that count more accurate.

## Verification

Equivalence canary enqueued as an append-only Q02 rerun of
`899fb1b4-3532-4cac-9f28-40485ea8c448` (QM5_20176, GBPUSD.DWX), bound to the new
`ex5` `9c06c386…`.

Baseline to reproduce **exactly**: `PASS`, net −1930.20, PF 0.89, 51 trades,
drawdown 6435.34 / 6.29 %.

If the metrics differ at all, the neutrality claim above is false and the guard
must be reverted — a divergence would mean some rejected modify was not in fact
a no-op.

## Blast radius and follow-up

- The include change is inert for every EA until that EA is recompiled. Only
  QM5_20176 is rebuilt in this commit, so nothing else moves.
- QM5_20176's outstanding rows carry the previous `expected_ex5_sha256` and will
  refuse with `current_ex5_hash_mismatch` at claim time. That is the evidence
  binding doing its job; they requalify against the new binary.
- **Upstream defect, not yet fixed:** the callers compare a *raw* target against
  a *normalized* stored stop. The framework guard makes that harmless, but the
  comparison is still wrong at the source. Every trail helper that returns
  "improves" on a raw value (`QM_TM_TrailATR`, `QM_TM_MoveToBreakEven`,
  `QM_TM_TrailStep`, and each EA-local trail such as QM5_20176 stage 2) should
  normalize before comparing.
- QM5_20176 additionally received a per-closed-bar submission cap earlier the
  same day (commit `a26001bca`, 20:49 local). All runs measured above used
  binaries built **before** that commit, so the two fixes are independent and
  neither is disproven by this data.

## Method note

The failure classifier reported `UNCLASSIFIED` with "no discriminating token"
and was correct to do so: nothing in the work item, the worker log or the
run_smoke log names this failure. It was only visible by measuring the
terminal's own journal. When a run dies with no summary and no signature, the
next place to look is the size and composition of `Tester/logs/<date>.log` —
2.3 GB of one repeated line is not a symptom the pipeline can see from inside.

## Pre-registered reading of the QM5_20176 XAUUSD rerun (written 2026-08-17 01:10Z, before the result)

The requeued XAUUSD Q02 row was claimed on T7 at 00:55Z with the fixed binary. Its
outcome has two possible causes and they must not be confused after the fact, so the
interpretation is fixed here in advance:

- **Completes with a verdict** → the 6.2 M rejected modifies were the reason its earlier
  attempts exceeded their budget. The no-op guard did its job.
- **Dies at ~90 minutes with `summary_missing` / `UNCLASSIFIED`** → that is the outer
  watchdog (task `738e9396`, fix committed as `e607a1bc3` but *not yet deployed* —
  `terminal_worker.py` is resident in the worker from process start, so the running
  worker still enforces the 90-minute CLI default). Such a result says **nothing** about
  the modify fix and must not be read as one.

The 90-minute mark for this run falls at approximately 02:25Z. The two changes are
independent and only the second one is currently live in the workers, so a failure in
that window is the expected behaviour of a known, already-fixed defect — not new
evidence.
