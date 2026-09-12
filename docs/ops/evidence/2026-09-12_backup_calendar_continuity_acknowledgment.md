# Q-backup calendar continuity acknowledgment

Date: 2026-09-12  
Router task: `3b334176-a874-4003-b411-08e5fc1ab0bf`  
Result: **REVIEW — the known 2026-08-18 gap is acknowledged without being represented as a successful backup**

## Governed record

`docs/ops/evidence/backup_calendar_acknowledgments.json` now records the exact
missing date, an acknowledgment timestamp, the router-task authority, a reason,
and the durable root-cause evidence path. The evidence remains
`docs/ops/evidence/2026-08-22_sp_d6_backup_gap_root_cause_and_alarm.md`, which
binds the gap to the scheduled `qm-admin` session's missing GoogleDriveFS `G:`
mount after its 15-minute wait. It also records the healthy runs on 2026-08-17
and 2026-08-19.

The acknowledgment is not a synthetic success marker and does not modify
`D:/QM/reports/state/backup_nightly.log`. The continuity check accepts a due date
only when either the transcript contains its genuine `failures=0` end marker or
the date has a structurally valid governed acknowledgment whose evidence file
exists. An invalid schema, incomplete record, duplicate date, timestamp without
an offset, or missing evidence fails closed and leaves the calendar date missing.

## Current result

The production transcript contains successful nightly end markers after the
known gap through 2026-09-12. A direct read-only invocation returned:

```text
backup_calendar_continuity = OK
every nightly date 2026-08-18..2026-09-12 has failures=0 or a governed acknowledgment; governed acknowledgments=2026-08-18
```

No backup, scheduled task, DriveFS process, terminal, trading flag, verdict
evidence, or factory state was changed.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_backup_calendar_continuity.py -q
5 passed

python -c "from tools.strategy_farm.silent_failure_monitor import check_backup_calendar_continuity; print(check_backup_calendar_continuity())"
status=OK; governed acknowledgments=2026-08-18
```

Tests cover the original persistent-gap behavior with no acknowledgment,
complete calendars, the daily cutoff, valid governed closure, and fail-closed
invalid records.

**RESULT (Q-only):** Q-backup continuity is REVIEW — the acknowledged
2026-08-18 gap no longer creates a permanent health failure, while missing or
malformed evidence still does.
