# Pump De-Monolith Review Artifact - 2026-05-22

Task: `4a877cfb-b1a2-4a65-ab6a-93be72d94872`

## Scope Checked

Read `tools/strategy_farm/farmctl.py::pump()` around the active WS-3 follow-up area.

Current shape:

- One large in-process pump function still owns all sub-jobs.
- Several steps share local variables and spawn-budget state across build, review, G0, research, ablation, promotion, backup, and notifier logic.
- Some individual calls already have local exception handling, but the pump does not yet provide a uniform sub-job envelope with:
  - per-sub-job timeout,
  - per-sub-job duration,
  - per-sub-job structured log line,
  - continuation after a timed-out sub-job.

## Verification

Executed after the prior helper change:

```text
python -m unittest tools.strategy_farm.tests.test_basket_order_helper_static tools.strategy_farm.tests.test_basket_work_items
```

Result: `3 tests passed`.

No terminal was started, no T_Live path was touched, and no pipeline verdict semantics were changed.

## Finding

The requested acceptance is not complete in this cycle. A safe implementation should first extract pump sub-jobs into explicit top-level callables with a shared `PumpContext`, then wrap each callable in a structured runner. Trying to add hard timeouts around the current closure-heavy body would either fail to interrupt hung work on Windows threads or risk leaving orphaned worker state.

## Recommended Next Slice

- Introduce `PumpContext` and `PumpSubJobResult`.
- Extract low-coupling jobs first:
  - active timeout / verdict normalization,
  - `dispatch_tick`,
  - zero-trade detection,
  - research card extraction,
  - auto R-eval queue,
  - DB backup,
  - WS-0 notifier,
  - task-watch notifier.
- Add a pump contract test with a simulated timeout sub-job and a following success sub-job.
- Only after that, migrate the shared spawn-budget sections for Codex/Claude build, review, G0, and research.

## Verdict

`PUMP_DEMONOLITH_NOT_COMPLETED_REFACTOR_REQUIRED`
