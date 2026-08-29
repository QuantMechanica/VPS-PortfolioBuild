# Post-claim SQLite write-budget repair

- Router task: `07152f6c-e12a-417d-91f8-c851aaa095aa`
- Date: 2026-08-29
- State requested after implementation: `REVIEW`
- Scope: worker run-path persistence only; no pipeline verdict or claim-order change

## Defect

After `claim_atomic` committed an active row, `_run_claimed_item` persisted its
pre-spawn payload with the same short SQLite retry policy used by the atomic
claim scramble. A pump write window could exhaust that budget. The recovery
write in `_defer_item_after_sqlite_busy` then had only 12 default-delay attempts,
so the worker could emit `run_item_sqlite_busy_deferred` with
`deferred_to_pending=false`, exit, and waste the claim cycle.

## Repair

`terminal_worker.py` now has a dedicated, bounded post-claim retry envelope:

- 20 attempts;
- 0.5-second base delay;
- the shared retry helper's existing 1-second delay cap and jitter;
- a fresh connection/transaction on every attempt.

The policy is used by active-payload persistence, unspawned terminal-state
persistence, stale-preflight cleanup, child adoption/spawn recording, and the
SQLite-busy defer fallback. `claim_atomic` and `claim_specific_atomic` still use
the original 8-attempt, 0.05-second policy, preserving the short XCU claim
doctrine.

## Focused verification

Run from `C:/QM/repo`:

```text
python -m pytest tools/strategy_farm/tests/test_terminal_worker_sqlite_busy_defer.py -q
3 passed in 0.81s

python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
73 passed in 42.64s
```

The new tests inject 12 consecutive `database is locked` failures before
allowing the 13th connection. Both the post-claim record write and the defer
fallback succeed; this deterministically exceeds the previous fallback's
12-attempt ceiling. The tests also assert the 20/0.5 policy explicitly.

## Runtime acceptance still required

The requested six-hour mixed-operation observation cannot be manufactured by a
single orchestration pass. Review/operations should confirm that
`run_item_sqlite_busy_deferred` has zero events with
`deferred_to_pending=false` over a real six-hour pump/worker window. This code
artifact supplies the bounded retry repair and regression coverage; it does not
claim that production-duration acceptance evidence already exists.
