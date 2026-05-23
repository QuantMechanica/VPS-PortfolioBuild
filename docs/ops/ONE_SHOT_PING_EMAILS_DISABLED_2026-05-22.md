# One-Shot Ping Emails Disabled - 2026-05-22

## Router Task

- Task: `e16d7d81-6ba8-4734-bcf7-c04d8fdda908`
- Title: Kill the one-shot ping-email notifiers (WS-0 + task-watch)
- Decision: OWNER 2026-05-22 requested no one-shot ping/watch emails.

## Change

- `tools/strategy_farm/farmctl.py` no longer imports or invokes:
  - `tools/strategy_farm/ws0_notifier.py`
  - `tools/strategy_farm/task_watch_notifier.py`
- Pump output keeps inert result keys for operator visibility:
  - `ws0_clear_notifier.triggered=false`
  - `task_watch_notifier.triggered=false`
  - both report `disabled_by_owner_2026_05_22`
- `tools/strategy_farm/gmail_alarm.py` and `tools/strategy_farm/run_gmail_alarm_task.py` were not changed. The scheduled daily/hourly health-alarm channel remains the single sanctioned mail path.

## Pending Watch State

- Existing task-watch sentinel: `D:/QM/strategy_farm/state/task_watch_notifier.json`
- Status observed during implementation: all recorded groups were already disarmed and had prior `mail_result.sent=true`.
- Because the pump no longer calls `task_watch_notifier.check_and_notify`, any future or pending watch entry is dormant and cannot fire from the pump path.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/ws0_notifier.py tools/strategy_farm/task_watch_notifier.py tools/strategy_farm/gmail_alarm.py`: PASS
- `python -m unittest tools.strategy_farm.tests.test_one_shot_mail_disabled tools.strategy_farm.tests.test_ws0_notifier tools.strategy_farm.tests.test_task_watch_notifier`: PASS
- `rg "ws0_notifier|task_watch_notifier|check_and_notify" tools/strategy_farm/farmctl.py`: PASS, no one-shot notifier imports or invocations remain in the pump.

## Commit / Push

- Local commit: `Disable one-shot strategy farm mail notifiers` on `agents/board-advisor`
- Push status: BLOCKED in this headless run. `git push` and `git push origin HEAD:agents/board-advisor` both stalled in `credential-manager get` until timeout; stale push process trees were terminated.
- Branch status after push attempt: `agents/board-advisor` remains ahead of `origin/agents/board-advisor` by four commits.
