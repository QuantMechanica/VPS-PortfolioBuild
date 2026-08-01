# DL-065 DENY-audit persistence

- Evidence date: 2026-08-01
- Router task: `80712802-9f39-48e4-a51e-622dab9ecfef`
- Predecessor finding: `c1427cb7-1449-4a12-a191-e8438925102a`
- Board-advisor code commit: `35e27a551`
- Main merge commit: `2dab9b85c`
- Verdict: **FIXED_AND_REGRESSION_TESTED**

## Result

DL-065 scope decisions made against the file-backed farm database now write the
`agent_audit` event through a short-lived autonomous SQLite connection and
commit it before the authorization result returns. A `ScopeDenied` exception
can therefore roll back the rejected caller transaction without erasing its
`DENY` row.

Authorization semantics did not change. Unknown identities and ungranted scopes
still fail closed, explicit denies still win, trusted deterministic identities
retain their existing handling, and audit failures still do not override the
authorization decision. No capability-policy grant was edited.

## Root cause

`agent_scopes._audit()` previously used a supplied connection directly:

```text
farmctl.event(conn, "agent_audit", ...)
```

`enqueue_backtest()` supplies the same connection used by its enclosing
transaction. On a denied `mt5.backtest.dispatch` call, `_audit()` inserted the
event and `require()` raised `ScopeDenied`. The exception unwound the connection
context and SQLite rolled back both the rejected operation and its audit event.
This is why the 27 worker-identity incident denials existed in stderr but not in
`farmctl audit`.

The historical 27 rows were not fabricated or backfilled. Their incident
evidence remains the predecessor stderr/DB reconciliation; this change makes
future decisions durable.

## Implementation

`agent_scopes._file_backed_audit_connection()` resolves the supplied
connection's main database with `PRAGMA database_list`, opens that same database
independently, writes exactly one event through the existing `farmctl.event()`
primitive, commits, and closes the autonomous connection. It does not commit,
roll back, or otherwise end the caller transaction.

Private in-memory and mock connections have no reopenable database path and
retain the prior same-connection fallback for isolated tests. Production farm
connections are file-backed.

The change is centralized in `_audit()`, so it covers every current guard path
that supplies a caller connection, including:

- `enqueue_backtest()` / `mt5.backtest.dispatch`;
- `reserve_ea_ids()` / `registry.reserve_ea_ids`;
- `guarded_db_delete()` and direct `guard()` / `require()` callers.

No call-site exception handling or guard ordering was weakened.

## Focused verification

Two transaction-level regressions use a real WAL-mode file database:

1. Begin a caller transaction, deny `codex` for `git.push.main`, catch
   `ScopeDenied`, roll the caller transaction back, and assert exactly one
   durable `DENY` audit row.
2. Begin a caller transaction, allow `claude` for `git.push.main`, assert the
   caller transaction is still open, commit caller work, and assert exactly one
   `ALLOW` row plus the committed caller record.

Commands and results on `agents/board-advisor`:

```text
python -m pytest tools/strategy_farm/tests/test_agent_scopes.py \
  tools/strategy_farm/tests/test_terminal_worker_identity.py \
  tools/strategy_farm/tests/test_mnt009_010_reconciliation.py -q

43 passed in 3.50s

python -m py_compile tools/strategy_farm/agent_scopes.py \
  tools/strategy_farm/farmctl.py

exit 0
```

`git diff --check` passed for both changed code paths. The isolated code commit
was cherry-picked into the registered local `main` worktree as `2dab9b85c`;
unrelated dirty worktree files were not staged or modified. On that main
worktree, its available DL-065 suite also passed:

```text
python -m pytest tools/strategy_farm/tests/test_agent_scopes.py -q

21 passed in 0.47s

python -m py_compile tools/strategy_farm/agent_scopes.py \
  tools/strategy_farm/farmctl.py

exit 0
```

## Safety record

This repair did not start or stop terminals, interrupt backtests, enable
AutoTrading or T_Live, change pipeline verdicts, mutate scope grants, requeue
work, or alter news/risk guardrails.
