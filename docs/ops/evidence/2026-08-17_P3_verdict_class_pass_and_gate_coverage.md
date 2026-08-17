# P3 — Verdict-class pass and the gate coverage matrix

## First, a correction that changes the arithmetic

`attempt_count` is **not** an attempt counter. It is incremented only on retry/requeue paths —
`terminal_worker.py:3006` (cold-cache retry) and `farmctl.py:11603` (review-fail requeue) — never
on first dispatch. I noticed because 89 % of **PASS** rows carry `attempt_count=0`, which cannot
mean "never dispatched" since a PASS requires a run.

So the field counts **retries consumed**, and my first reading ("77.6 % of INFRA_FAIL never
dispatched") was wrong in the safe direction: the true retry cost is *higher*, not lower.

## Where the retries actually go

Since 2026-07-15, 16,526 terminal rows:

| Verdict | rows | retries | retries/row |
|---|---:|---:|---:|
| **INFRA_FAIL** | 5,563 | **3,701** | 0.67 |
| PASS | 4,167 | 794 | 0.19 |
| FAIL | 4,599 | 220 | 0.05 |
| ZERO_TRADES | 1,162 | 168 | 0.14 |
| INVALID | 230 | 20 | 0.09 |
| everything else | ~800 | ~65 | — |

**INFRA_FAIL consumes 3,701 of roughly 4,970 retries — three quarters of all retry work in the
farm.** Every other class is under 0.2 retries per row. So the question "is INFRA_FAIL correctly
classified?" is the throughput question, not a bookkeeping nicety.

## The 1,939 `run_smoke_fail` rows — and where my own thesis is wrong

I expected to find economic outcomes hiding under this label. Decomposed:

| Sub-reason | rows | what it actually is |
|---|---:|---|
| `ONINIT_FAILED` | **1,013** | the **EA refused its own initialisation** — configuration/authoring |
| `NO_HISTORY` | 475 | genuine data/cold-cache (known first-attempt transient, self-heals) |
| `BARS_ZERO` | ~200 | proven today to be an **OnInit configuration rejection** |
| `LOG_BOMB` | 129 | EA authoring — e.g. per-tick news checks on a synthetic host |
| `TIMEOUT` / `METATESTER_HUNG` | 109 | genuine infrastructure |
| `REPORT_FORMAT_DRIFT` | 5 | genuine infrastructure |
| **`MIN_TRADES_NOT_MET`** | **1** | economic |

**`MIN_TRADES_NOT_MET` appears once.** My thesis that "economic results are broadly hiding under
infra labels" does **not** generalise into this bucket, and I am recording that against myself:
the Q07 case and the BARS_ZERO case are real, but they are not evidence of a widespread pattern
of *economic* mislabelling.

The finding is a different and larger one:

> **~1,342 of 1,939 rows (69 %) are EA-level rejections, not infrastructure** — the EA refused to
> start, or wrote a log bomb, under this configuration. Genuine infrastructure is ~589 (30 %):
> NO_HISTORY, TIMEOUT, REPORT_FORMAT_DRIFT.

That matters because the two classes need opposite handling. Infrastructure failures are
transient and a retry is the correct response. **An EA refusing its own OnInit is deterministic —
the retry cannot succeed**, which is exactly what QM5_41033 demonstrated: three retries against a
setfile the EA was always going to reject.

## The slot cost, with the method stated

If ~69 % of INFRA_FAIL is deterministic EA-level failure, roughly **2,550 of the 3,701 retries
were re-runs of a deterministic outcome**. Bounding the wall cost:

- at the Q02 full-history timeout ceiling (`P2_FULL_TIMEOUT` 7200 s): up to **~5,100 slot-hours**
- at a conservative 30-minute average per dispatch: **~1,275 slot-hours**

Across 10 slots that is between roughly **5 and 21 days of whole-factory time** since 2026-07-15.
I am giving a band rather than a point because per-attempt durations are not stored on the row —
the honest measurement would need the summaries, and `prune_workitem_logs` has removed the
journals. The band is wide; the conclusion does not depend on which end is right.

## Gate coverage matrix

| Gate | Where it runs | Phases covered |
|---|---|---|
| `_manifest_pinned_staged_ex5_gate` | before the phase branch | **all phases** (this caught QM5_11288's phantom binary at Q08) |
| `_compile_gate_check` — symbol scope **+ compile freshness** | `farmctl.py:5824`, `if phase in ("Q02","P2")` | **Q02 / P2 only** |
| Q02 window scaling by period | `:5863` | Q02 / P2 |
| Q02 prescreen | `:5905` | Q02 |
| paired-Q09 dependency | `:6791` | Q10 |
| report-root isolation | `:7117` | Q04–Q10 |
| 5-seed multiseed | `:8389` | Q07 |

Binary **identity** is checked everywhere; binary **provenance against its source** is checked
only at the entry phase.

## The hole is live, and here is the demonstration

QM5_41023 leaks a foreign symbol — `const string g_strategy_symbol = "XTIUSD.DWX";` at
`QM5_41023_wti-mends-mom.mq5:55`, validator `MULTI_SYMBOL_LEAK_NOT_DECLARED`. Timeline from
mtimes and the work-item rows:

```
2026-08-16 13:55  Q02 PASS          (compile gate ran)
2026-08-16 14:45  .mq5 edited       (source now leaks)
2026-08-16 14:49  .ex5 recompiled   (binary is CURRENT, not stale)
2026-08-17 11:54  Q04 FAIL          (no compile gate at Q04 — leak never re-checked)
```

So a source change after Q02 propagated into a Q04 verdict without ever facing the gate that
exists to catch it. The binding chain cannot help: the Q04 row was bound to the *new* binary at
dispatch, so the hashes matched.

**What the risk actually is** — and it is not the verdict that already exists. QM5_41023 ran on
`XTIUSD.DWX` and the hardcoded symbol *is* `XTIUSD.DWX`, so its Q04 FAIL is economically valid for
that symbol, and it has rows on no other symbol. The exposure is forward:

> If this EA is ever dispatched on a different symbol, it will read XTIUSD data while the verdict
> is recorded against the other symbol. That is a silently wrong-symbol verdict, and nothing
> currently prevents it.

Fixing the source (use `_Symbol`) is therefore the actual remedy, and widening the gate to later
phases is the systemic one. Doing only the latter would leave the EA unportable; doing only the
former leaves the class open.

## Priority by slot cost

1. **Reclassify `ONINIT_FAILED` (1,013 rows) out of the retry ladder.** Largest single block, and
   deterministic by nature — the retries cannot succeed. This is the highest-value item in P3.
2. **`BARS_ZERO` (~200)** — root cause fixed today at the generator; the remaining work is
   reclassification of the historical rows.
3. **`LOG_BOMB` (129)** — EA authoring, deterministic, same argument.
4. **Extend `_compile_gate_check` beyond Q02/P2**, or re-verify source-to-binary provenance at
   each phase transition. Cheap relative to a wrong-symbol verdict.
5. **Repair QM5_41023's source** to `_Symbol`.
6. `NO_HISTORY` (475) and `TIMEOUT` (109) stay where they are: genuinely infrastructure, retry is
   the correct response, and NO_HISTORY is a documented self-healing transient that must **not** be
   answered with a history re-import.

## Evidence

- 16,526 terminal rows since 2026-07-15 from `work_items`
- `terminal_worker.py:3006`, `farmctl.py:11603` — the retry-only increment sites
- `farmctl.py:5293-5300` (`_work_item_compile_gate` phase scope), `:5824-5828` (call site),
  `:6791` (Q10 dependency), `:7117` (report-root), `:8389` (Q07 seeds)
- `framework/EAs/QM5_41023_wti-mends-mom/QM5_41023_wti-mends-mom.mq5:55` + file mtimes
- related: `2026-08-17_q07_low_trades_misclassified_as_infra.md`,
  `2026-08-17_bars_zero_root_cause_closed_at_the_generator.md`
