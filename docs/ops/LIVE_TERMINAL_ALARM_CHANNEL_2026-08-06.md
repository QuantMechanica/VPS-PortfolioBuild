# Live-terminal immediate alarm channel (WS-E2)

Status: BUILT — pending Claude approval and explicit installation

OWNER ratified this narrow exception on 2026-08-06 after the dual live-MT5
outage. It overrides the 2026-07-19 no-ping-email rule only for live-terminal
uptime transitions and bounded persistence escalation. It does not re-enable
the legacy pipeline FAIL/OK email task.

## Contract

- Producer: `QM_T_Live_Watchdog`, writing
  `D:\QM\reports\state\live_alarm_state.json` once per watchdog cycle.
- Consumer: `tools/strategy_farm/live_alarm_mailer.py`, intended to run as
  SYSTEM under windowless `pythonw.exe` every minute.
- Transport: the existing Gmail SMTP helper and secrets in `gmail_alarm.py`.
- Pages: new/changed critical conditions, all-clear after a paged condition,
  and persistent-condition escalation beginning at the watchdog's
  `escalation_threshold` (currently three cycles), with at most one further
  page per 30 minutes.
- Page-worthy facts: an expected-RUNNING terminal in a producer-declared alarm
  condition, an unexpected-running PARKED contract, a blocked recovery-task
  contract, or a reboot-suppressed/cancelled recovery state.
- Suppression: either producer `maintenance=true` or
  `LIVE_UPTIME_MAINTENANCE.flag` suppresses all mail without consuming a new
  alarm transition.
- Deduplication: consumer state is atomically reserved before SMTP handoff. A
  crash after reservation can lose one notification but cannot create a mail
  storm on the next cadence.

The consumer only reads state and sends mail. It never probes a process, starts
or stops a scheduled task, launches a terminal, changes AutoTrading, or calls
the watchdog. Its failures therefore cannot block or delay recovery.

## Installation gate

`install_live_uptime_tasks.ps1` and `qm_tasks.manifest.ps1` both define
`QM_Live_AlarmMailer_1min`. Do not install it until Claude approves the routed
review. Installation intentionally has no send-now option; use copied fixtures
with `--dry-run` for verification.

## Evidence

See `docs/ops/evidence/2026-08-06_ws_e2_live_alarm_mailer_codex.md`.
