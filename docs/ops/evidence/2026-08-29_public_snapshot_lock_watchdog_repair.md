# Public snapshot lock/watchdog repair (2026-08-29)

- Router task: `c5ee7b2c-78d2-48c6-8569-0680d9341de0`
- Branch: `agents/board-advisor`
- Scope: public-snapshot scheduling and mutation-lock health only
- Live controls: no terminal was started, stopped, or interrupted; AutoTrading and `T_Live` were untouched.

## Incident and root cause

`QM_Public_Snapshot_Hourly` started at `2026-08-29T06:07:03Z`. Its last log line was the Python startup warning at `06:07:04Z`; it never emitted the normal `Snapshot files updated` or exit line. The wrapper's pre-repair order was:

1. acquire `FACTORY_MUTATION.lock` as owner `public_snapshot`;
2. query the live farm database in `public_snapshot_incident_guard.py`;
3. query and aggregate the live farm database in `build_pipeline_state.py`;
4. run the exporter; and
5. release the lock.

The measured incident overlapped the long `ea_metrics.build` write window. The child was waiting in the DB-heavy pre-publication path while the parent retained the no-sharing global writer lock. This explains both observations: no exporter output in the task log and 45 minutes of `factory_mutation_lock_busy` claim refusals. The wrapper had no deadline, so a live blocked child could retain the lock indefinitely.

## Repair

`scripts/run_public_snapshot_task.ps1` now:

- applies one 600-second wall-clock deadline to the incident guard, pipeline-state builder, and exporter;
- starts each child hidden, captures its output, and kills the verified child process tree on deadline expiry;
- runs every DB-heavy child before acquiring `FACTORY_MUTATION.lock`;
- renders the four public JSON files to a unique temp staging directory;
- acquires the mutation lock only for hash comparison and atomic tracked-file replacement;
- opens its lock record read-shared so read-only health can name `owner=public_snapshot` and the PID while still denying writers/deleters; and
- retains nonce/content-CAS lock release and a guarded temp-directory cleanup.

`scripts/export_public_snapshot.ps1` gained an optional `OutputDir`. Schemas and the company-model input remain anchored in canonical `public-data`, while generated files can be staged away from the tracked tree.

`health.chk_factory_mutation_lock` now returns `FAIL` for a positively live, readable holder aged at least 600 seconds and includes the owner/PID in `detail`. It never reaps a live holder. Unreadable/unknown identity remains fail-closed at `WARN` rather than guessing.

## Verification

- PowerShell parser: both modified scripts parse with zero errors.
- Focused tests:
  - `test_health_factory_mutation_lock.py`
  - `test_public_snapshot_incident_guard.py`
  - `test_factory_mutation_lock.py`
  - `test_factory_quiescence.py`
- Result: `36 passed in 6.76s`.
- Static contract test proves the exporter call precedes mutation-lock acquisition, the lock is health-readable, and the watchdog marker exists.

The task was not executed manually against production because doing so would duplicate the scheduled publisher and mutate tracked public data outside its next normal cadence. The next scheduled run is the production canary; its lock-hold interval should cover only the final file publication.
