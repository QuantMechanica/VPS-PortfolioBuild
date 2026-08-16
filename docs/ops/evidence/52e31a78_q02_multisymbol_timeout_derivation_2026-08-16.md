# Q02 multisymbol timeout derivation

- Router task: `52e31a78-e9ee-4395-abec-a14636361356`
- Branch: `agents/board-advisor`
- Scope: queue-row construction only; no terminal launch, backtest interruption, live setting, or pipeline verdict

## Defect

Q02 basket and multisymbol work created through repair, fresh-seed, or sweep recovery paths could omit the explicit `timeout_min` payload override. Those rows then inherited the ordinary active-age ceiling even though the worker already treats them as serialized multisymbol jobs. The live examples were QM5_20206 and QM5_20236; their interim rows were patched separately before this code repair.

## Repair

`farmctl` now applies one Q02-only timeout rule before row insertion. It recognizes:

- logical basket symbols that are not `.DWX` chart symbols;
- durable basket payload markers;
- an EA dependency manifest containing the host symbol; and
- the farm multisymbol registry.

For a matching row, `timeout_min` becomes `max(existing, 450)`, so a larger explicit budget is preserved. The rule is wired into normal backtest fanout, fresh Q02 seed creation, exact append-only Q02 reruns, post-build Q02 enqueue, and the sweep's never-tested/recovery/deferred insert path. Worker-side timeout handling is unchanged.

## Verification

Passed focused tests:

```text
3 passed in 3.69s
3 passed in 1.27s
3 passed in 1.12s
```

The focused cases cover logical-symbol detection, registry-only multisymbol detection with a `.DWX` host, preservation of an existing 600-minute override, normal basket fanout, post-build enqueue, fresh-seed recovery, active-timeout rerun, and dependency-manifest append-only repair.

Additional checks:

```text
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/sweep_enqueue_built_eas.py
git diff --check -- <changed paths>
```

Both passed. The pre-existing sweep subprocess integration test was not counted: its child process exceeded the test's 60-second timeout before reaching assertions in this environment.

## Files

- `tools/strategy_farm/farmctl.py`
- `tools/strategy_farm/sweep_enqueue_built_eas.py`
- `tools/strategy_farm/tests/test_basket_work_items.py`
- `tools/strategy_farm/tests/test_candidate_repair_enqueue.py`
- `tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py`
