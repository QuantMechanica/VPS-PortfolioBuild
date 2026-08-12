# Q08 INVALID boundary fix — 2026-07-27

## Verdict

Fixed forward. A completed Q08 aggregate with `verdict=INVALID` now remains
`INVALID`, which is non-retryable. Only an explicit allow-list of transient
runner-loss reasons (`ACTIVE_TIMEOUT`, runner/worker loss, MetaTester hang,
launch fault, or process exit) maps that result to retryable `INFRA_FAIL`.
`FAIL_HARD` remains a strategy result and is never converted at this boundary.

No work item was requeued or mutated by this implementation. Hash binding is
intentionally deferred: it needs a schema/evidence-lineage design and was not
half-implemented.

## Measured before/after

The approved corpus audit selected all 204 Q08 `INFRA_FAIL` rows. Of the 158
whose current set files are valid, 32 row-bound aggregates are `INVALID`, one is
`FAIL_HARD`, two missing-aggregate rows explicitly say `ACTIVE_TIMEOUT`, and the
remainder belong to other historical input/evidence classes.

For the 32 completed `INVALID` aggregates, re-derivation changes:

| Class | Before | After |
|---|---:|---:|
| retryable `INFRA_FAIL` | 32 | 0 |
| non-retryable `INVALID` | 0 | 32 |

The two explicit `ACTIVE_TIMEOUT` rows remain `INFRA_FAIL`. The one historical
`FAIL_HARD` aggregate is already protected by the general hard-verdict branch;
this patch cannot turn it into infra. Existing database rows are not silently
rewritten: reclassification happens when a fresh result crosses the boundary.
A separately reviewed, hash-bound migration is required for historical rows.

## Surfaces and invariants

- `tools/strategy_farm/farmctl.py::_derive_phase_runner_verdict` owns the
  boundary. Its Q08 branch now precedes the generic invalid-report mapping.
- Work-item vocabulary already includes `INVALID`; dashboards/cockpit already
  consume it. No new verdict value was introduced.
- Operator-facing phase normalization remains unchanged and Q-only.
- The retry loop continues to retry only `INFRA_FAIL`; `INVALID` cannot enter it.
- No gate verdict can be promoted by this change.

## Verification

```
python -m unittest tools.strategy_farm.tests.test_verdict_taxonomy_ws2
```

Result: **22 tests passed**. Regression coverage asserts deterministic Q08
INVALID, missing evidence, and dominant sub-gate INVALID remain `INVALID`;
explicit `ACTIVE_TIMEOUT` remains retryable; soft/hard strategy results and the
zero-trade infra exception retain their prior behavior.

No factory switch, terminal, backtest, queue, or live setting was touched.
