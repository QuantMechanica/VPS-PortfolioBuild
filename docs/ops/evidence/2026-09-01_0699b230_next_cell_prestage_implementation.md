# Next-cell pre-stage implementation — inert review handoff

- Date: 2026-09-01
- Router task: `0699b230-4ba6-4cba-8656-fcb168e2a86d`
- Approved proposal: `d4a1e0e9-52ad-444e-8d22-b08f4e70b3ec`
- Proposal file SHA-256: `ac23e3695ac016b136c6e5bfef99b8f31e06c5d2934471a309150c4c315aee5f`
- State: implementation complete, **INERT / NOT ACTIVATED**, submitted for review

## Result

Implemented the approved detached next-cell preparation cache behind two fail-closed controls:

- `NEXT_CELL_PRESTAGE_ENABLED=0` by default;
- `NEXT_CELL_PRESTAGE_TERMINAL_ALLOWLIST` is empty by default and requires an exact terminal match.

Both variables were absent from the implementation session environment. No worker was restarted, no canary terminal was enabled, and no T1-T10 process was interrupted. The existing post-finish claimant remains the only queue authority.

## Authority boundary preserved

The background job begins only after a runner child exists and its spawn binding has passed the existing durable-record attempt. It may:

- read one likely candidate through SQLite `mode=ro` + `PRAGMA query_only=ON` using the canonical pending-order SQL;
- hash the exact payload, set file, EX5, custom-history activation/manifest/master record and selected verified-master archives;
- perform a read-only DL-089 amendment/ledger/frontier/predecessor/pruning inspection;
- copy immutable bytes into `D:/QM/strategy_farm/cache/next_cell_prestage/<terminal>/...` under a fleet-wide non-blocking I/O semaphore, byte cap, rate cap, TTL, cancellation, and resource declines.

It cannot claim, reserve, pin, reprioritize, prune, write a receipt, acquire a launch right, or write into a terminal tree. The ordinary path still performs, after the current child exits:

1. resource/news/history gates and the new history lease;
2. unchanged `claim_atomic` selection and `BEGIN IMMEDIATE` CAS;
3. existing DL-089 eligibility and pruning application under their existing locks;
4. final source/payload/policy/dependency revalidation and local `PREPARED -> ADOPTED` CAS;
5. existing atomic EX5/history promotion, final hashes, post-copy audit, one canonical privatization receipt, launch-slot acquisition, and spawn.

A different claimed item, payload/policy/dependency drift, TTL expiry, source identity change, resource pressure, byte-cap excess, busy I/O budget, or cancellation is a cache miss/decline and falls back to the cold path. A corrupt detached EX5/archive cache also falls back to the canonical EX5/verified master before any authoritative failure can be produced.

## Instrumentation

Structured `next_cell_prestage` events now record UTC and monotonic timestamps for configuration, candidate observation, start/prepared/decline, bytes and resource snapshot, current child exit, next claim attempt/result, adoption, next child creation, idle gap, prior tester runtime, and calculated duty cycle. This supplies the approved canary measurements without activating the feature.

## Change surface

- `tools/strategy_farm/next_cell_prestage.py` — detached cache, controls, I/O semaphore, cancellation, token, TTL cleanup, CAS, and telemetry clock.
- `tools/strategy_farm/terminal_worker.py` — read-only snapshot construction, post-claim binding, and spawn/finish hooks; default path remains cold.
- `tools/strategy_farm/custom_history_copy_on_claim.py` — optional prepared-master copy source with hash-verified cold fallback.
- `tools/strategy_farm/opt_census_pruning.py` — pure `inspect_candidate_exclusion`; the existing mutation/apply function remains authoritative.
- `tools/strategy_farm/tests/fixtures/next_cell_prestage_replay.json` — deterministic two-cell replay fixture, SHA-256 `9b39b453a50a2c457732d6d0cdb35a13058806356e6e1acfe5a9b9b54456b2af`.

No queue status, verdict schema, gate criterion, DL-089 limit, set file, live path, or AutoTrading state was changed.

## Verification

Focused implementation/regression run:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_next_cell_prestage.py \
  tools/strategy_farm/tests/test_next_cell_prestage_replay.py \
  tools/strategy_farm/tests/test_custom_history_copy_on_claim.py \
  tools/strategy_farm/tests/test_opt_census_pruning.py

22 passed in 5.66s
```

Broader worker/claim/history/DL-089 suite:

```text
245 passed, 4 subtests passed in 85.09s
```

The broad run covers every `test_terminal_worker_*` suite plus custom-history admission/master/Variant-A, news-calendar claim admission, factory mutation lock, long-run scheduling, DL-089 replay, pruning, and the new replay tests.

The replay executes the real SQLite `claim_atomic` path twice from the same fixture. Feature-off and feature-on runs produced identical:

- claimed item sequence: `replay-cell-a`, `replay-cell-b`;
- `work_items` status/verdict/claimed-by/payload/updated-at surfaces;
- `claim_class_ledger` terminal/item/class/timestamp rows.

With the feature on, both exact candidates additionally reached local `ADOPTED`; with it off, no snapshot callback ran and no cache directory was created. `py_compile` and `git diff --check` also passed for the scoped files.

## Review / activation boundary

This handoff does not authorize a canary. Review should first confirm the no-authority boundary and replay evidence. Any later canary must follow the approved proposal: exact naturally idle terminal allowlist, no active-test interruption, paired control, at least 100 eligible handoffs or six hours per arm, and immediate stop on the proposal's first invariant violation.

## Verdict

`READY_FOR_REVIEW_INERT`: implementation and replay are green; authoritative runtime behavior is unchanged with the feature off; duty-cycle instrumentation is present; activation remains explicitly out of scope.
