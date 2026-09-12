# Governed backup reuse DML identity hardening — 2026-09-12

Task: `e93dffb6-92e2-441f-9826-091a79ac12bd`  
Disposition: **REVIEW — cheap DML-sensitive identity restored**

## Result

`db_backup_reuse.identities_match` now requires equality of all collected
identity fields:

- resolved source path;
- SQLite `schema_version`;
- source database `mtime_ns`;
- source database byte size; and
- `-wal` byte size (zero when no WAL file exists).

A legacy sidecar without the WAL field cannot match a current identity and
therefore falls back to a fresh online SQLite backup. Any observed difference
in database metadata or WAL size likewise forces a fresh backup. The existing
age window, online-backup implementation, per-tool keep-three cap, and exact
deletion receipt are unchanged.

This restores cheap DML sensitivity to the shared helper without adding a
database write, a new mutation-sequence table, or a change to any caller's
locking contract. It is deliberately an identity check over the listed file
facts; it does not claim to be a monotonic transaction sequence.

## Focused evidence

- unchanged database between two resolver calls: second call reuses the first
  path and SHA-256;
- ordinary committed DML: second call returns `reused=false` and a distinct
  backup path;
- WAL mode with autocheckpoint disabled and committed growth: WAL size changes,
  second call returns `reused=false`;
- cross-tool and repeated governed-writer fixtures now expect a new anchor
  after the first tool's committed DML.

Only temporary pytest databases and backup directories were mutated. The
canonical farm database, live backup directory, queue, registry, workers,
terminals, T_Live, AutoTrading, and verdicts were untouched.

## Verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_release_compile_wave.py \
  tools/strategy_farm/tests/test_first_q02_intake.py \
  tools/strategy_farm/tests/test_farmctl_requal8_tools.py \
  tools/strategy_farm/tests/test_governed_work_item_hold.py

56 passed in 14.33s

python -m compileall -q tools/strategy_farm/db_backup_reuse.py
PASS
```
