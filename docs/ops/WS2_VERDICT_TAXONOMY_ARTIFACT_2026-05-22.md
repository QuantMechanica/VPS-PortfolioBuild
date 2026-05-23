# WS-2 Verdict Taxonomy Artifact - 2026-05-22

Task: `6d365393-9a2a-4784-aa60-ba519365e5b3`

## Scope

Implemented the first WS-2 cut in the hot Strategy Farm work-item paths:

- `tools/strategy_farm/farmctl.py`
  - `_derive_verdict_from_summary()` now classifies missing real-tick evidence, missing runs, missing reports, parse errors, incomplete runs, no-history, and timeout-style run-smoke evidence as `INFRA_FAIL`.
  - `_derive_phase_runner_verdict()` preserves genuine strategy `FAIL` outcomes while mapping phase-runner `INVALID`, `ERROR`, `TIMEOUT`, missing real MT5 P5b evidence, and P8 proxy-only mode selection to `INFRA_FAIL`.
  - Work-item timeout / worker-death / terminal-death retry exhaustion now persists `INFRA_FAIL` instead of final generic `INVALID`.
  - Classified work-item payloads now carry `evidence_provenance` and `verdict_taxonomy`.
- `tools/strategy_farm/terminal_worker.py`
  - Summary-missing retry exhaustion, preflight failures, and spawn failures now persist `INFRA_FAIL`.
  - Aggregation counts include `INFRA_FAIL`.
  - Finished work-item payloads carry `evidence_provenance` and `verdict_taxonomy`.

No gate thresholds were loosened. Q-only operator naming remains unchanged in artifacts and task routing.

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

Focused WS-2 assertions added:

- G1/no-real-tick evidence derives `INFRA_FAIL`.
- A genuine losing run-smoke reason remains `FAIL`.
- P8 proxy-only mode selection derives `INFRA_FAIL`, not a strategy failure.

## Residual Risk

Legacy scripts and dashboards still display historical `INVALID` wording in places outside the hot work-item classifier path. This artifact covers the routed WS-2 implementation slice named in the task payload; a later dashboard cleanup can rename historical presentation without changing gate verdict semantics.

## Verdict

`WS2_VERDICT_TAXONOMY_IMPLEMENTED_TESTED`
