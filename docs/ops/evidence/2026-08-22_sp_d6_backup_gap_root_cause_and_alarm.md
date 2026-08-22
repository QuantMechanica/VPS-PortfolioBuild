# SP-D6 — 2026-08-18 backup gap root cause and continuity alarm

Date: 2026-08-22  
Router task: `7e28c4be-0bb1-40c4-9252-348da99b76f1`  
Disposition: PASS — root cause established and a persistent missing-calendar-day alarm added

## Root cause

The canonical nightly-backup transcript proves that the 2026-08-18 run did not
complete because the scheduled-task session could not see the per-user Google
DriveFS mount after its bounded wait:

```text
1077:=== QM nightly backup end 2026-08-17 04:45:59Z elapsed=00:00:55.5709139 failures=0 ===
1082:2026-08-18 05:00:06Z FATAL drive G: not available after 15min wait -- GoogleDriveFS mount absent in this session
1116:=== QM nightly backup end 2026-08-19 04:45:34Z elapsed=00:00:30.6992817 failures=0 ===
```

Evidence source: `D:/QM/reports/state/backup_nightly.log`.

This is a session/mount-availability failure, not an archive-copy failure. The
current `QM_NightlyBackup_Vault` registration runs the canonical
`C:/QM/repo/scripts/backup_nightly.ps1` as `qm-admin`; its latest run was healthy
(`LastTaskResult=0`) and the task was Ready when inspected. That current health
does not repair or erase the 2026-08-18 calendar gap.

## Alarm gap and remediation

The pre-existing monitor checked only the backup transcript's modification age
(WARN after 26 hours, FAIL after 50 hours). A failed night followed by a healthy
night refreshes the file before that threshold and can therefore hide the
missing calendar date.

`tools/strategy_farm/silent_failure_monitor.py` now also performs an explicit
calendar-continuity check:

- the contract is armed from the audited date `2026-08-18`;
- only an explicit nightly end marker with `failures=0` counts as success;
- each date becomes due at 06:00 UTC, after the scheduled run and bounded DriveFS
  wait;
- missing dates remain FAIL findings after later successful runs;
- a matching `FATAL` transcript line is included in the finding detail.

This is monitoring-only. It does not launch DriveFS, change the backup task,
enable trading, or affect terminal processes.

## Verification

Focused automated tests:

```text
python -m pytest tools/strategy_farm/tests/test_backup_calendar_continuity.py tools/strategy_farm/tests/test_mnt003_heartbeat_ignorenew_benign.py -q
.......                                                                  [100%]
7 passed in 0.74s
```

Read-only production dry run:

```text
[DRY RUN - no state/sidecar written] overall=FAIL fail=1 warn=6 ok=7
[FAIL] backup_calendar_continuity: missing successful nightly backup date(s): 2026-08-18; logged causes=2026-08-18:drive G: not available after 15min wait -- GoogleDriveFS mount absent in this session
```

`git diff --check` passed for the implementation and focused test (only the
repository's existing LF/CRLF conversion warning was emitted).

## Operational conclusion

The 2026-08-18 gap was caused by DriveFS `G:` being absent from the scheduled
task's session after 15 minutes. Future missing calendar dates covered by the
continuity contract now alarm durably and cannot be masked by a later successful
backup.
