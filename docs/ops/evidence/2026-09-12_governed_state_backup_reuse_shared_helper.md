# Governed state backup reuse shared helper — 2026-09-12

Router task: `4ce6ec32-a28a-491a-b4ec-5d17a756ff0c`  
Disposition: **REVIEW**  
Production database mutation: **none**

## Outcome

The established rolling-window backup policy is now implemented once in
`tools/strategy_farm/db_backup_reuse.py` and consumed by all three bounded
writer surfaces named by the task:

| Writer surface | Integration | Reuse receipt |
|---|---|---|
| `release_compile_wave.apply_wave` | delegates its existing `_resolve_backup` compatibility surface to the shared resolver | existing `backup.reused`, `reused_from_sidecar`, identity and cap-receipt fields |
| `farmctl.record_q01_smoke_successor` and `farmctl.release_work_item_hold` | resolve through `_governed_state_backup_resolution`; the tuple helper remains for other callers | return receipt now includes the full resolution and audit events/ledger include `backup_reused` |
| `governed_work_item_hold.apply_holds` | replaces its unconditional SQLite copy with `sqlite_backup_resolution` | return receipt includes the full resolution and hold events include `backup_reused` |

The shared contract preserves the already-approved semantics: a fresh sidecar
may be reused only for the same resolved database path, unchanged SQLite schema
generation, and configured age window. Normal governed DML intentionally shares
the pre-window rollback anchor. Missing/unreadable identity, a schema change,
an expired sidecar, a missing backup, or a non-positive reuse window fails
closed to a fresh online SQLite backup. The per-tool keep-three cap and exact
deletion receipt are unchanged. No retention policy or verdict logic changed.

`QM_TOOL_BACKUP_REUSE_MAX_AGE_MINUTES` governs the farmctl and governed-hold
callers (default 60 minutes). The compile-wave CLI/environment contract remains
unchanged. Compatibility tuple functions remain available to existing callers.

## Verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_release_compile_wave.py \
  tools/strategy_farm/tests/test_first_q02_intake.py \
  tools/strategy_farm/tests/test_farmctl_requal8_tools.py \
  tools/strategy_farm/tests/test_governed_work_item_hold.py
55 passed

python -m compileall -q \
  tools/strategy_farm/db_backup_reuse.py \
  tools/strategy_farm/release_compile_wave.py \
  tools/strategy_farm/governed_work_item_hold.py \
  tools/strategy_farm/farmctl.py
PASS

git diff --check -- <the scoped paths>
PASS
```

The cross-writer fixture produces one fresh `q01_smoke_successor` backup and
then proves `release_work_item_hold` returns `reused=true` with the same path
and SHA-256. The governed-hold fixture likewise proves a second apply returns
`reused=true`, the same path/SHA-256, one SQLite file, and a matching identity
sidecar. Compile-wave tests retain fresh, reuse-after-DML, expiry, schema-change,
disabled-window, timeout, and keep-three receipt coverage.

Only temporary fixture databases were mutated. The canonical farm database,
factory queue, terminals, `T_Live`, FTMO, AutoTrading, verdicts, and backup
retention directory were not touched.

## Orchestrator addendum 2026-09-12 (PARK reason of 2026-09-03 addressed explicitly)

This row was parked on 2026-09-03 05:40Z because the backup-reuse identity predicate of 615608abd0 was judged
fail-open and a monotonic mutation sequence written by every governed writer was demanded. That demand was not
implemented; task 70f55cbf (APPROVED 2026-09-06, merged 65be85ab90) superseded it with the "one rollback anchor
per window" scheme (identity = source_path + PRAGMA schema_version, DML-insensitive by design). This ticket
extends that live scheme to farmctl._governed_state_backup / release_work_item_hold / record_q01_smoke_successor
and governed_work_item_hold; it does not re-litigate it. Residual risk, stated: a reused anchor may predate
intervening DML inside the window, so a rollback to it undoes every governed mutation of that window, not only
the last one. Hardening follow-up (orchestrator ticket): compare the already collected source_mtime_ns,
source_size and WAL size before reuse, restoring DML sensitivity cheaply.
