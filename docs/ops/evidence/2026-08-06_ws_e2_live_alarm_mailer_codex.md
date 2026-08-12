# WS-E2 immediate live-terminal alarm consumer — Codex build evidence

Date: 2026-08-06

Router task: `2cb609e1-ccd0-4ffd-baca-4954881aa3c4`

Verdict: READY_FOR_CLAUDE_REVIEW; not installed and not approved

## Scope and safety boundary

Codex built a separate SYSTEM-task consumer for the existing WS-E1 alarm state.
The consumer is read-only with respect to the watchdog, Task Scheduler, and both
live MT5 terminals. No terminal was stopped, restarted, launched, or probed; no
AutoTrading setting was touched; no SMTP message was sent during verification.

This mail channel is the OWNER-ratified 2026-08-06 exception to the 2026-07-19
no-ping-email rule. The exception is limited to live-terminal alarm transitions,
all-clears, and bounded persistent-alarm repeats. The legacy pipeline FAIL/OK
channel remains disabled.

## Delivered artifacts

- `tools/strategy_farm/live_alarm_mailer.py`: atomic transition state,
  maintenance suppression, recovery-block and reboot-suppression pages,
  three-cycle escalation, and 30-minute repeat ceiling. It reuses
  `gmail_alarm._send_mail_with_retries` and its existing secrets/config.
- `tools/strategy_farm/Live_Alarm_State.ps1` and `T_Live_Watchdog.ps1`: additive
  schema-v3 export of the watchdog's already-computed recovery-task contract
  verdict. The producer remains independent of all consumer outcomes.
- `tools/strategy_farm/install_live_uptime_tasks.ps1`: SYSTEM registration at a
  one-minute cadence via windowless `pythonw.exe` (`CREATE_NO_WINDOW` pattern),
  `IgnoreNew`, and a bounded execution limit.
- `tools/strategy_farm/qm_tasks.manifest.ps1`: matching ALWAYS_ON task entry.
- `tools/strategy_farm/tests/test_live_alarm_mailer.py` and two copied-state
  fixtures.
- `docs/ops/LIVE_TERMINAL_ALARM_CHANNEL_2026-08-06.md`: operating contract and
  approval/install gate.

## Focused verification

```
python -m pytest tools/strategy_farm/tests/test_live_alarm_mailer.py -q
......                                                                   [100%]
6 passed in 0.62s
```

PowerShell parser checks passed for the producer, watchdog, installer, and task
manifest. The existing WS-E1 suite also passed:

```
WS-E1 alarm-state tests PASS (212 assertions).
```

## Forced-transition dry run

A fixture was copied to
`C:\Windows\Temp\qm_live_alarm_evidence_f992aed443ee490bbb612b3dbf940cd9\live_alarm_state_fixture.json`.
Only that copied file was switched from the healthy fixture to the
`T_LIVE/missing` fixture and back; production state and terminals were untouched.
The consumer used a fixture-local state/log and `--dry-run` throughout.

Observed decision sequence:

| UTC | Fixture state | Decision | Mail transport |
|---|---|---|---|
| 06:00 | healthy | `NONE` | not called |
| 06:01 | T_LIVE missing | `RAISE` | dry-run only |
| 06:02 | unchanged missing | `NONE` | not called |
| 06:03 | third identical cycle | `ESCALATION` | dry-run only |
| 06:04 | healthy | `CLEAR` | dry-run only |

The rendered subjects were `[QM LIVE] CRITICAL - T_LIVE missing`,
`[QM LIVE] STILL CRITICAL - T_LIVE missing`, and
`[QM LIVE] ALL CLEAR - live-terminal alarm resolved`.

## Review/activation boundary

Builder is not approver. This change stays in router `REVIEW`; Claude must review
it before any approval or scheduled-task installation. Installer registration
was not executed in this build cycle.
