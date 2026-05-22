# QM5_10260 — STRATEGY_FAIL verdict is a mislabel (infra/perf, not strategy)

**Date:** 2026-05-22
**Author:** Claude (headless orchestration cycle)
**EA:** QM5_10260 (`QM5_10260_cieslak-fomc-cycle-idx`)
**Status:** for OWNER awareness — no blanket re-run, analysis only

## Finding

The Q02/P2 pipeline has stamped QM5_10260 with:

- `current_stage = review_reject_rework`
- P2 `verdict = STRATEGY_FAIL`, `surviving_symbols = []`
- review `verdict = REJECT_REWORK`
- `last_activity = 2026-05-22T13:18:06Z`

A `STRATEGY_FAIL` implies the strategy was evaluated against price data and the
strategy itself underperformed. The run evidence shows that did not happen.

## Evidence

All 44 `summary.json` files under
`D:\QM\reports\work_items\*\QM5_10260\*\summary.json`:

| field | value |
|---|---|
| `result` | FAIL × 44 (0 PASS, 0 completed) |
| reason `TIMEOUT` | 40 |
| reason `METATESTER_HUNG` | 39 |
| reason `INCOMPLETE_RUNS` | 44 |
| reason `INVALID_REPORT` | 18 |

`work_items` for QM5_10260: 30 done, 7 failed, 0 pending, 0 active.

Sample — latest run (`run_tag 20260522_121714`, T7, XNGUSD.DWX, M30, Model 4):
every `run_NN` is `failure: "TIMEOUT"`, "Tester run timed out after 1800
seconds", `report_size_bytes: 0`.

**Not one of the 44 runs produced a completed backtest.** The strategy thesis
(cieslak-fomc-cycle-idx) has never been tested. The failure class is
infra/perf — the per-tick recompute hangs the MetaTester until the 1800s cap —
the same class as QM5_1044's perf rework.

## Why this matters

1. A `STRATEGY_FAIL` verdict wrongly retires a strategy direction that was
   never evaluated. The correct classification is an ops/perf failure
   (`OPS_FIX_REQUIRED`-class), not a strategy rejection.
2. `review_reject_rework` routes this as a thesis to redesign, when the real
   fix is the EA's per-tick performance.

## Recommendation (routes to existing tracked work — nothing new invented)

The perf fix is already tracked under two APPROVED codex `ops_issue` tasks —
not yet done:

- `a6a0679b` — P2 short real-tick pre-screen (window ≥6 months) with a short
  cap before the full long-timeout run.
- `8babdd08` — QM5_10260 M15 backtest `.set` files + Q02 re-queue.

Until those land, QM5_10260's `STRATEGY_FAIL` should be read as a perf artifact.
No blanket re-run; the EA needs a genuine per-tick perf rework + rebuild + clean
re-screen first. The `cieslak-fomc-cycle-idx` thesis is not refuted by this
verdict.

OWNER decision needed only on whether the pipeline's verdict classifier should
distinguish "all runs TIMEOUT/HUNG → INCOMPLETE" from genuine `STRATEGY_FAIL`,
so a never-tested EA cannot be retired on a perf hang.
