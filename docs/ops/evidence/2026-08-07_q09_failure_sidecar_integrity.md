# Q09 failure-sidecar integrity — attempt snapshots and authoritative pointer

Date: 2026-08-07 (Europe/Berlin)  
Router task: `cec668da-21a1-4015-aaac-accf8ef0469b`  
Parent evidence: `2026-08-06_error32_history_sharing_violation_class.md`, section 5  
Status: IMPLEMENTED AND TESTED / REVIEW REQUIRED / NOT DEPLOYED

## Finding reproduced

The numbered `cell_failure*.json` sidecars were append-only, but each one
authenticated artifacts at mutable paths under the cell directory. A later
attempt overwrote `runs/.../run_smoke.log`; the collector then hard-coded
`cell_failure.json` (attempt 1) even when `execution_failure.json` named
`cell_failure_6.json` as the terminal occurrence. A valid later occurrence
therefore made the first occurrence appear mutated and the aggregate emitted
the misleading `cell_receipt_invalid` reason despite no receipt existing.

## Implemented contract

Changed files:

- `tools/strategy_farm/q09_news_runner.py`
- `tools/strategy_farm/tests/test_q09_news_runner_v2.py`

The correction is fail-closed and has five parts:

1. Before a sidecar is written, every available cell artifact is copied into
   `failure_attempts/attempt_NNNN/`. The copy completes under a temporary
   directory and is renamed into its final attempt namespace before the
   sidecar is published. The sidecar records both the immutable snapshot path
   and each artifact's original cell-relative path.
2. New sidecars use `q09-news-cell-failure/v2`, carry an explicit occurrence,
   and may authenticate artifacts only inside their own attempt snapshot.
   Duplicate/malformed paths, snapshot escapes, missing files, size drift, or
   SHA-256 drift remain evidence failures.
3. New top-level pointers use `q09-news-execution-failure/v2` and bind the
   work item, run identity, terminal sidecar path, sidecar SHA-256, and
   occurrence. When a missing receipt has this pointer, the collector follows
   it and may not fall back to an older numbered sidecar.
4. Read compatibility remains for v1 failure sidecars and v1 execution
   pointers. A legacy run without any execution pointer may still use the
   base-sidecar read path; an invalid pointer cannot be bypassed by that path.
   A valid receipt continues to take precedence over stale failure sidecars.
5. Failure-sidecar or pointer authentication errors now produce
   `cell_failure_manifest_invalid`. `cell_receipt_invalid` is reserved for an
   actual receipt/evidence contradiction. Both outcomes remain
   `INVALID_EVIDENCE`; there is no relaxation of selector or pipeline gates.

No retry ceiling, factory-capacity check, terminal handling, Q09 selector,
economic metric, or fail-closed direction changed.

## Regression fixture

The new fixture executes two failed attempts for one cell. Its dispatcher
overwrites the same live `runs/selection/run_smoke.log` with different bytes
on each attempt. Verification establishes that:

- attempt 1 and attempt 2 produce different immutable snapshot paths;
- the snapshots retain `attempt 1 log` and `attempt 2 log` respectively;
- both numbered sidecars authenticate independently;
- `execution_failure.json` points to occurrence 2;
- a third mutation of the live log does not invalidate either snapshot;
- mutating the terminal snapshot produces `INVALID_EVIDENCE` with
  `cell_failure_manifest_invalid`.

## Focused verification

Commands and results:

```text
python -m py_compile tools/strategy_farm/q09_news_runner.py
PASS

python -m pytest tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q09_live_news_diagnostic.py -q
38 passed in 35.40s

git diff --check -- tools/strategy_farm/q09_news_runner.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py
PASS
```

Post-change SHA-256 bindings before commit:

| File | SHA-256 |
|---|---|
| `q09_news_runner.py` | `884d43560ffd59b0efcbcc49f1a02e533129a781793605bb699157c7ea0658fe` |
| `test_q09_news_runner_v2.py` | `b57d8dbba92fe6e1d4ce48e3502f00eda328fcf7609962e36324440b847cb95e` |

## Review and deployment boundary

This is builder evidence, not approval. The code is left for independent
review and is not moved into a runtime deployment by this task. Acceptance
should confirm the schema/read-compatibility choices, the authoritative
pointer behavior, and the two-attempt fixture. No terminal was started or
stopped, no queue item was changed, and neither T_Live nor AutoTrading was
touched.
