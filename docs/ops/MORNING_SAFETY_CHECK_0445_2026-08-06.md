# Daily 04:45 morning safety check

Status: BUILT — pending Claude approval and explicit installation

OWNER requested a pre-placement verify-and-start sweep after the 2026-08-06
dual live-MT5 outage. The task is scheduled for 04:45 Europe/Berlin so it can
finish before QM5_13213's nominal 05:00 local bracket (06:00 broker). Broker and
local DST transitions do not always align; edge weeks can shift the relationship
by approximately one hour. OWNER may retune the local trigger after observation.

## Safety boundary

`Morning_Safety_Check.ps1` is start-only. It never stops or restarts a running
terminal, invokes `terminal64.exe`, stops a worker, reboots Windows, or changes
AutoTrading. Unknown process inventory is FAILED and no live launch is attempted.

Live healing occurs only by ensuring the `QM_T_Live_Watchdog` cadence is enabled
and invoking that same watchdog script with `-NoReboot`. The watchdog owns the
hardened SYSTEM-to-interactive chain: Task Scheduler RunEx binds the resident
supervisor to the existing qm-admin session, and the resident supervisor uses
the idempotent launchers. The morning sweep does not duplicate that chain or
inherit the regular watchdog task's separately OWNER-approved reboot authority.

Factory healing uses only the registered pump, tick, factory-watchdog, and
worker-dedupe tasks. A duplicate-worker observation is reported as FAILED and
left untouched, preserving active T1-T10 work. News staleness is repaired only
by the governed `QM_NewsCalendar_Refresh` task; `MaxNewsAgeHours` cannot exceed
336. Disk shortage is observational—this task never deletes files.

`LIVE_UPTIME_MAINTENANCE.flag` suppresses the live domain. `FACTORY_OFF.flag`
suppresses factory starts and news refresh. Suppressed checks are recorded as
`SUPPRESSED`, never silently treated as healed.

## Outcome and paging contract

Every check records `OK`, `HEALED`, `FAILED`, or `SUPPRESSED` in:

- `D:\QM\reports\state\morning_safety_check.json`
- `D:\QM\reports\state\morning_safety_check.jsonl`

Any `FAILED` check uses the WS-E2 `live_alarm_mailer.py` transport and is mailed
once per run. All-OK/HEALED runs send no mail. The 06:00 morning briefing reads
the JSON and renders one compact 04:45-Safety line.

The installer and canonical task manifest both define
`QM_Morning_Safety_Check_0445` as SYSTEM, daily 04:45, hidden, `IgnoreNew`, with
a 14-minute execution limit. Do not register it until Claude approves the
routed review.

Evidence: `docs/ops/evidence/2026-08-06_morning_safety_check_0445_codex.md`.
