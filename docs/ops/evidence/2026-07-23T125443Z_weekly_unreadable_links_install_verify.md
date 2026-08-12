# Weekly Unreadable-Links Mail — Install Verification

**Verified:** 2026-07-23 14:54 CEST

**OWNER directive:** one Friday-morning email with links automation could not
open, delivered to `fabian.grabner@gmail.com`.

## Implemented contract

- Core: `tools/strategy_farm/weekly_unreadable_links_mail.py`
- Scheduled-task wrapper:
  `tools/strategy_farm/run_weekly_unreadable_links_task.py`
- Installer:
  `tools/strategy_farm/install_weekly_unreadable_links_task.ps1`
- Tests:
  `tools/strategy_farm/tests/test_weekly_unreadable_links_mail.py`
- Canonical manifest category: `QM_ALWAYSON_TASKS`
- Source marker added to the Priority-A block in the Vault's
  `Strategie Links.md`
- One additional historical HTTP 403/Cloudflare source was migrated into that
  marked queue:
  `https://www.forexfactory.com/thread/972324-recommended-strategies-on-forex-factory-real-traders`

## Safe verification

```text
python -m pytest -q tools\strategy_farm\tests\test_weekly_unreadable_links_mail.py
18 passed in 0.92s

python -m pytest -q tools\strategy_farm\tests\test_weekly_unreadable_links_mail.py tools\strategy_farm\tests\test_reboot_diagnostic_mail.py tools\strategy_farm\tests\test_one_shot_mail_disabled.py
53 passed in 1.78s

python tools\strategy_farm\weekly_unreadable_links_mail.py --dry-run
action=dry_run
sent=false
week=2026-W30
count=5
fingerprint=c56a3b03ef95ade0e32ff860e0e4fe8106f9685f29a35392115c4388c6b4e674
```

The dry-run rendered text, HTML, and JSON evidence. It did not invoke SMTP and
did not write weekly send state.

An independent review found and the implementation closed the SMTP/state
double-send window: an atomic per-week claim is now written before SMTP,
Gmail acceptance is written to that claim before the secondary state update,
and ambiguous post-DATA failures are not retried. Tests cover SMTP acceptance
followed by a state-disk failure and prove that the second invocation does not
call SMTP again. `DEFERRED:TECHNICAL_RETRY` and specific permanent dead-link
reasons are also included; only downstream-only
`DEFERRED:HANDOFF_FAILED*` is excluded.

The bounded re-review reported no remaining Blocker, High, or Medium findings
in the changed mail/filter/scheduler scope.

## Registered task

```text
TaskName:           QM_StrategyFarm_UnreadableLinks_Friday
State:              Ready
Principal:          qm-admin
LogonType:          InteractiveToken
RunLevel:           Limited
ScheduleByWeek:     true
DaysOfWeek.Friday:  true
WeeksInterval:      1
StartBoundary:      2026-07-23T06:30:00+02:00
NextRunTime:        2026-07-24 06:30 local
StartWhenAvailable: true
MultipleInstances:  IgnoreNew
ExecutionTimeLimit: PT10M
RestartCount:       4
RestartInterval:    PT15M
Action:             pythonw.exe
Arguments:          run_weekly_unreadable_links_task.py
WorkingDirectory:   C:\QM\repo
```

No immediate live email was sent during installation. The first scheduled
delivery is Friday 2026-07-24 at approximately 06:30 local.

## Mail-policy boundary

`QM_StrategyFarm_GmailAlarm_Hourly` remains disabled and its in-code
`PIPELINE_ALERTS_ENABLED = False` guard remains unchanged. The new weekly
research-intake report is the explicit OWNER-authorized channel and is not a
PIPELINE FAIL/OK notification.

## Unrelated Vault validation finding

The report's marked source block parses successfully and produced the expected
five-link dry-run. The full Company Reference linter currently reports broken
wikilinks because the live G: mount no longer exposes `Strat - Sammelthread.md`
or `Strat 1.md` through `Strat 11.md`. Those files were not changed by this
implementation. Their absence does not block the weekly report, which reads the
marked queue directly, but the wider Vault link integrity remains open.
