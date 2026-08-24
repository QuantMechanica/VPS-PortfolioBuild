# QM_HMA shared-include defect — census, fix, and requalification classification

- **Task ID:** 7dd0f41e-aee7-42e3-be70-f6845bea3a15 (claude, ops_issue, priority 80)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Source finding:** independently verified twice (Codex review of QM5_9923 + Sonnet re-verification 2026-08-24)
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)
- **Defect present since:** commit `55c0fe8de` (2026-05-17) — `feat(framework): QM_WMA / QM_LWMA / QM_SMMA / QM_HMA / QM_Stoch / QM_CCI helpers`

## 1. The defect

`framework/include/QM/QM_Indicators.mqh` (pre-fix, line 586-604) defined:

```
double QM_HMA(...)
  {
   ...
   const int sqr  = (int)MathSqrt((double)period);
   const double w_half = QM_LWMA(sym, tf, half,   shift, price);
   const double w_full = QM_LWMA(sym, tf, period, shift, price);
   const double diff   = 2.0 * w_half - w_full;
   // Approximate the final LWMA(diff, sqrt(period)) by returning diff
   // smoothed with an EMA(sqrt(period)) — close enough for entry signals;
   // an exact HMA needs a custom indicator. Document the approximation.
   return diff;
  }
```

The comment on line 585 documents the correct definition: `HMA = WMA(2*WMA(n/2) - WMA(n), sqrt(n))`.
The code computes `diff = 2*LWMA(n/2) - LWMA(n)` correctly but **returns it directly** — the
outer `LWMA(sqrt(n))` smoothing pass over the diff series is never performed. The local variable
`sqr` is computed and then never used for anything. Every EA calling `QM_HMA()` therefore trades
the raw pre-smoothing diff series, not a Hull moving average, despite the strategy cards and
in-code comment both declaring Hull MA as the mechanism.

This is a **shared-include defect**, not a per-EA defect: every EA that calls `QM_HMA()` inherited
the same wrong series regardless of period/timeframe/symbol.

## 2. Blast-radius census

`grep -rl "QM_HMA" framework/EAs --include="*.mq5"` → 16 EAs. No other include wraps or re-exports
`QM_HMA` (`grep -rln "QM_HMA" framework/include` → only the definition site itself), so this list is
exhaustive.

Pipeline status per EA, read from `work_items` in `D:/QM/strategy_farm/state/farm_state.sqlite`
(`GROUP BY ea_id, phase, status, verdict`), captured 2026-08-24 before any fix or requeue:

| ea_id | slug | max phase reached | PASS verdicts on defective series | total work_items |
|---|---|---|---|---|
| QM5_10251 | tv-nova-rev | Q04 | Q02:PASS×2; Q03:PASS×2 | 14 |
| QM5_10593 | mql5-adxhull | Q04 | Q02:PASS×1; Q03:PASS×1 | 16 |
| QM5_10602 | mql5-oshma | Q04 | Q02:PASS×2; Q03:PASS×1 | 36 |
| QM5_10833 | tv-autobot12 | Q04 | Q02:PASS×1 | 9 |
| QM5_10960 | ftmo-hma-rsi | Q04 | Q02:PASS×4; Q03:PASS×3 | 16 |
| QM5_12742 | nnfx-configurable-engine | Q06 | Q02:PASS×11; Q03:PASS×1; Q04:PASS_SOFT×1; Q05:PASS×1 | 28 |
| QM5_12958 | nnfx-hma-wae-swing | Q09_PORTFOLIO (FAIL_PORTFOLIO) | Q02:PASS×3; Q03:PASS×2; Q04:PASS×1; Q05:PASS×1; Q06:PASS×1; Q07:PASS×1 | 17 |
| QM5_2002 | nnfx-qqe-trend | Q05 | Q02:PASS×6; Q03:PASS×1; Q04:PASS×1 | 243 |
| QM5_9998 | tv-hull-suite-hma-color-flip | Q04 | Q02:PASS×4; Q03:PASS×2 | 32 |
| QM5_10222 | tv-bbsr-jma-atr | Q02 | — none — | 15 |
| QM5_1054 | bigdog-tms-tdi-hma-h4 | Q02 | — none — | 42 |
| QM5_10699 | tv-cisd-hma | Q02 | — none — | 8 |
| QM5_10899 | muranno-mfi-hma | Q02 | — none — | 26 |
| QM5_9923 | bandy-hma-crossover-trend | COMPILE_EA (COMPILE_FAIL, unrelated: `EA_Q08_MAE_HOOK_MISSING`, `EA_TRADE_REQUEST_UNINITIALIZED`) | — none — | 2 |
| QM5_9961 | bandy-hma-supertrend-confluence-trend | COMPILE_EA (COMPILE_FAIL, same unrelated classes) | — none — | 2 |
| QM5_36003 | nnfx-hull-ma-zerolag-macd-stc | NONE | — never gated, 0 work_items rows — | 0 |

**No EA reached a PASS verdict at Q08 or Q11** (the hard real-evidence gates). The deepest PASS
reached on the defective series is Q07 (QM5_12958), which then failed Q08/Q09_PORTFOLIO for
unrelated reasons. So no live-relevant evidence trail exists on the defective HMA series — but 9
EAs carry **standing PASS verdicts at Q02–Q07** that were computed on the wrong indicator series.

Raw work-item query and this table are reproducible via the query embedded in this document's
companion script (see §5).

## 3. Fix

`framework/include/QM/QM_Indicators.mqh` `QM_HMA()` now performs the missing outer LWMA(sqrt(n))
pass explicitly (MT5 has no native buffer-input-to-iMA path for a synthetic diff series, so the
weighted average is computed by hand over `sqr` consecutive diff values, using the same
linearly-decreasing-weight convention as MT5's native `MODE_LWMA` — most recent bar gets weight
`sqr`, oldest included bar gets weight `1`):

```
double QM_HMA(const string sym, const ENUM_TIMEFRAMES tf, const int period,
              const int shift = 1, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   if(period < 4)
      return QM_LWMA(sym, tf, period, shift, price);
   const int half = period / 2;
   const int sqr  = (int)MathSqrt((double)period);
   double weighted_sum = 0.0;
   double weight_total = 0.0;
   for(int i = 0; i < sqr; i++)
     {
      const int s      = shift + i;
      const double w_half = QM_LWMA(sym, tf, half,   s, price);
      const double w_full = QM_LWMA(sym, tf, period, s, price);
      const double diff_i = 2.0 * w_half - w_full;
      const double weight  = (double)(sqr - i);
      weighted_sum += diff_i * weight;
      weight_total += weight;
     }
   return weighted_sum / weight_total;
  }
```

`QM_LWMA` itself (the two inner passes) was already correct and is unchanged.

## 4. Reference-vector test (run before the fix was applied to the include)

Constraint: the include fix may only land after a green reference-vector test. Ran a standalone,
dependency-free Python script (`docs/ops/evidence/2026-08-24_qm_hma_reference_vector_test.py`, kept
alongside this evidence doc) that:

1. Implements the proposed fix as a literal point-wise translation of the MQL5 loop above.
2. Implements a **second, independently-derived** version — builds the full diff array first
   (textbook approach: array-then-rolling-window, no shared helper function with #1) and takes a
   plain weighted window over it — using the identical MT5 `MODE_LWMA` weighting convention.
3. Compares both across periods `[9, 14, 21, 55]` and shifts `[1, 2, 5, 10, 50, 100]` on a
   synthetic 400-bar random-walk price series (24 trials total).
4. Separately shows the old (buggy) `diff`-only value diverges materially from the fixed HMA value
   on the same series (delta magnitude comparable to the series' own bar-to-bar noise, i.e. not a
   rounding-level difference).

Result:

```
PASS: 24 trials across periods=[9, 14, 21, 55], max_abs_diff=1.421e-14
shift=1 buggy(diff)=117.323864 fixed(hma)=117.459541 delta=-0.135676
shift=5 buggy(diff)=117.254990 fixed(hma)=116.966085 delta=0.288905
shift=20 buggy(diff)=115.683153 fixed(hma)=115.430217 delta=0.252936
```

Max absolute difference between the two independent implementations of the fix is `1.4e-14`
(floating-point noise), i.e. the fix formula is internally consistent. The old buggy value differs
from the fixed value by an amount on the order of the series' own volatility — confirming this is
a real signal-changing defect, not a cosmetic one.

## 5. Compile smoke-test (governed queue only)

Per the hard constraint that compilation may only happen via the governed `COMPILE_EA` queue (the
EX5 guard), no local/manual MetaEditor invocation was run. Instead:

- `farmctl.py enqueue-compile QM5_10222_tv-bbsr-jma-atr` → refused, `TIMEFRAME_UNRESOLVED`
  (pre-existing, unrelated to this fix; no work item created, no mutation).
- `farmctl.py enqueue-compile QM5_10251_tv-nova-rev` → accepted, work item
  `603d05be-b7de-4b86-8bd2-331c1a0886d9`, but held at `activation_hold_code:
  COMPILE_EA_WORKER_ROLLOUT_PENDING` — the compile worker rollout itself is currently paused, so
  this task queues without executing synchronously in this single-pass cycle. It will run whenever
  the COMPILE_EA worker rollout resumes; no manual bypass was attempted.

No `.ex5` was rebuilt or force-recompiled as part of this task. The include-level fix has not yet
propagated into any EA's binary or triggered any rebuild/requalification.

## 6. Classification

Per constraint: **no pipeline verdicts were changed**. The classification below is a
recommendation only.

### Category A — Rebuild + requalification recommended (PASS verdicts exist on the defective series)

Per the "rebuilt EX5 = new identity, Q02 append-only triple" rule, a rebuild against the fixed
include produces a new binary identity and must re-enter the pipeline from Q02; it does **not**
retroactively invalidate the standing PASS rows below (append-only, verdict-bearing) — but those
standing PASS rows were computed on the wrong series and should not be treated as live-relevant
evidence going forward.

| ea_id | slug | existing PASS verdicts (defective series, kept as-is / append-only) |
|---|---|---|
| QM5_10251 | tv-nova-rev | Q02×2, Q03×2 |
| QM5_10593 | mql5-adxhull | Q02×1, Q03×1 |
| QM5_10602 | mql5-oshma | Q02×2, Q03×1 |
| QM5_10833 | tv-autobot12 | Q02×1 |
| QM5_10960 | ftmo-hma-rsi | Q02×4, Q03×3 |
| QM5_12742 | nnfx-configurable-engine | Q02×11, Q03×1, Q04(soft)×1, Q05×1 |
| QM5_12958 | nnfx-hma-wae-swing | Q02×3, Q03×2, Q04×1, Q05×1, Q06×1, Q07×1 |
| QM5_2002 | nnfx-qqe-trend | Q02×6, Q03×1, Q04×1 |
| QM5_9998 | tv-hull-suite-hma-color-flip | Q02×4, Q03×2 |

**9 EAs.**

### Category B — Never passed a gate on the defective series (rebuild is routine, no requalification burden)

QM5_10222, QM5_1054, QM5_10699, QM5_10899, QM5_9923, QM5_9961 — only FAIL / INFRA_FAIL / ZERO_TRADES
/ INVALID / COMPILE_FAIL verdicts exist (QM5_9923 and QM5_9961's COMPILE_FAIL is from unrelated
build-guardrail classes, not HMA-related). Re-queuing these under the fixed include is a normal
build, not a requalification action. **6 EAs.**

### Category C — Never gated

QM5_36003 — 0 `work_items` rows. No pipeline history exists to reconcile. **1 EA.**

## 7. OWNER decision template (not yet ratified — awaiting OWNER)

The 9 Category-A EAs carry standing PASS verdicts computed on a mechanically wrong indicator
series. Per hard-rule doctrine, a verdict inventory built on defective evidence is a **ROT**
condition that must be surfaced to OWNER rather than silently corrected by an agent. This section
is a decision template only; nothing below has been applied.

**Proposed options for OWNER:**

1. **Requeue for fresh Q02 build+requalification** under the fixed `QM_HMA` for all 9 Category-A
   EAs (and, at OWNER's discretion, the 6 Category-B + 1 Category-C EAs as routine follow-up).
   Existing PASS rows remain in the append-only ledger as historical/superseded, not deleted.
2. **Retire** any Category-A EA whose card's edge thesis is intrinsically tied to true Hull-MA
   behavior (i.e., where the raw diff series is not a plausible substitute mechanism) rather than
   requalifying — OWNER's call per EA, informed by each strategy card's source citation.
3. **No action** — leave as-is if OWNER judges the defect immaterial to current farm priorities
   (e.g., none of these reached Q08/Q11, so no live-relevant claim currently rests on this defect).

No option has been selected. If OWNER selects (1) or (2), record the ratified decision under
`decisions/YYYY-MM-DD_qm_hma_requalification.md` and only then may the recommended EAs be
requeued/retired.

## 8. Artifacts

- Fix: `framework/include/QM/QM_Indicators.mqh` (`QM_HMA`, lines ~584-613)
- Reference-vector test script: `docs/ops/evidence/2026-08-24_qm_hma_reference_vector_test.py`
- Census raw CSV: `docs/ops/evidence/2026-08-24_qm_hma_ea_census.csv`
- This document: `docs/ops/evidence/2026-08-24_qm_hma_shared_include_defect_census.md`
- Compile smoke-test work item: `603d05be-b7de-4b86-8bd2-331c1a0886d9` (QM5_10251, pending on
  `COMPILE_EA_WORKER_ROLLOUT_PENDING`)

## 9. Action taken vs. not taken

- **Done:** shared-include fix landed with a green reference-vector test; blast-radius census
  built and cross-checked against `work_items`; classification table produced; one bounded
  governed compile smoke-test enqueued (not force-run).
- **Not done (by design, per task constraints):** no verdict was changed or invalidated; no EA was
  requeued for rebuild/requalification; no OWNER decision was assumed or recorded as ratified.
