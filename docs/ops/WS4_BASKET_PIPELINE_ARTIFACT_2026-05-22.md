# WS-4 Basket Pipeline Artifact - 2026-05-22

Task: `d6e2f4d9-8351-4503-9f83-b33770095841`

## Scope

Implemented and tested the basket-aware queue branch required by `docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md`.

Behavior now implemented in `tools/strategy_farm/farmctl.py`:

- During Q02/P2 enqueue, an EA with `framework/EAs/<ea_dir>/basket_manifest.json` is treated as a basket EA.
- The queue creates exactly one work item with `symbol=FX8_BASKET_D1` instead of expanding to per-symbol DWX fanout.
- The work-item payload stores:
  - `portfolio_scope=basket`
  - `logical_symbol`
  - `host_symbol`
  - `host_timeframe`
  - `basket_manifest`
  - `basket_symbol_count`
- The MT5 runner uses the host chart from payload (`EURUSD.DWX` / `D1`) while retaining `FX8_BASKET_D1` as the queue/report identity.

No Q02+ gate verdict semantics were changed.

## Verification

Executed with the available venv interpreter:

```text
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/terminal_worker.py
python -m unittest tools.strategy_farm.tests.test_basket_work_items tools.strategy_farm.tests.test_verdict_taxonomy_ws2 tools.strategy_farm.tests.test_index_symbol_dispatch_serialization tools.strategy_farm.tests.test_dwx_history_range_filter
```

Result:

```text
10 tests passed
```

Focused WS-4 assertion added:

- A synthetic `QM5_10717` basket EA with `basket_manifest.json` and `FX8_BASKET_D1` setfile enqueues one Q02/P2 work item only, with host metadata preserved in payload.

## Not Completed In This Pass

No `framework/EAs/QM5_10717_*` or `framework/EAs/QM5_10718_*` directories existed at cycle start, so the two EAs could not be truthfully built, compiled, deployed, G0-approved, or Q02-enqueued in this single pass.

This artifact is therefore the durable implementation evidence for the basket pipeline wiring portion of WS-4. The EA build portion remains dependent on creating the actual `QM5_10717` and `QM5_10718` EA directories, source, manifests, setfiles, and build artifacts.

## Verdict

`WS4_BASKET_QUEUE_WIRING_IMPLEMENTED_BUILD_PENDING`
