# Scheduled-task contract correction package — 2026-07-28

Status: **UNEXECUTED**. Codex created and verified this package read-only. No
scheduled task was registered, started, stopped, enabled, or disabled.

The package contains exact semantic exports of the seven `0x800710E0` tasks
plus `QM_FTMO_AtLogon`, which is part of the same parked-terminal recovery
contract:

- `before/`: read-only exports taken on 2026-07-28.
- `after/`: proposed contracts.
- `rollback/`: the complete pre-change contracts.
- `Apply-TaskContractFix.ps1`: default read-only planner plus explicit,
  drift-refusing apply/rollback modes.

Proposed disposition:

| Task | Proposed execution contract |
|---|---|
| `QM_StrategyFarm_AgyGovernor` | LocalSystem task; user/DPAPI-dependent Python is launched in the existing `qm-admin` session via `run_in_console_session.ps1`. |
| `QM_StrategyFarm_CodexFleetPacer` | LocalSystem, direct `pythonw.exe`; existing 15-minute trigger retained. |
| `QM_StrategyFarm_GeminiOrchestration_15min` | LocalSystem task; `run_in_console_session.ps1` launches `pythonw.exe` as logged-on `qm-admin`, preserving Credential Manager and `LOCALAPPDATA\agy`; the 15-minute trigger is retained. |
| `QM_StrategyFarm_MailboxSourceIntake_Daily` | LocalSystem task; the same wrapper launches `pythonw.exe` as logged-on `qm-admin`, preserving Administrator `CODEX_HOME` and per-user auth; daily 06:07 and retry settings are retained. |
| `QM_StrategyFarm_WorkerDedupe` | LocalSystem task; worker launcher is placed in the existing `qm-admin` session via `run_in_console_session.ps1`, avoiding GUI children in session 0. |
| `QM_T_Live_AtLogon` | Remains `qm-admin` / `InteractiveToken`; one logon trigger; demand start explicitly disabled. |
| `QM_FTMO_AtLogon` | Remains `qm-admin` / `InteractiveToken`; one logon trigger; demand start explicitly disabled. `FTMO_ON.ps1` provides the baked PARKED no-launch guard. |
| `QM_Live_MT5_SessionSupervisor` | Remains `qm-admin` / `InteractiveToken`; the 15-minute time trigger is removed, leaving one logon trigger; demand start remains enabled only for the session-bound RunEx starter. |

OWNER/Claude interactive-session usage:

Apply this package only after this branch has been merged and deployed to
`C:\QM\repo`; the proposed task actions reference code at that canonical path.

```powershell
# Read-only comparison; safe default.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1

# Preview PowerShell's mutating operations.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1 -Apply -WhatIf

# Explicit apply, then explicit rollback if required.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1 -Apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TaskContractFix.ps1 -Rollback
```

The script accepts only the expected two-state transition (`BEFORE → AFTER` or
`AFTER → BEFORE`). Any third-state drift is refused. It contains no
`Start-ScheduledTask`, `Stop-ScheduledTask`, process control, terminal launch,
AutoTrading change, or task enable/disable command.

Registration-state caveat: `Register-ScheduledTask -Xml ... -Force` applies the
XML registration with the default enabled state when the XML does not carry an
explicit enablement setting. Before applying, confirm each target is intended
to be enabled. Do not apply this package to a deliberately disabled task
without an OWNER-reviewed procedure that preserves that disabled state.
