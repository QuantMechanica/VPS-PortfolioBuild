# WS-0 Clear Notifier

Date: 2026-05-22
Router task: `4fcc31a0`

## Change

- Added `tools/strategy_farm/ws0_notifier.py`.
- Folded the notifier into the pump tail in `tools/strategy_farm/farmctl.py`.
- The notifier watches for the first `P2`/`Q02` `work_items` row with:
  - `status='done'`
  - verdict in `PASS`, `FAIL`, or `ZERO_TRADES`
  - `updated_at > 2026-05-22T07:41:37+00:00`
- It sends subject `[QM Strategy Farm] WS-0 cleared - Q02 real verdict <VERDICT>` through the existing `gmail_alarm.py` SMTP helper and names the EA, symbol, verdict, work item, timestamp, and evidence path.

## Anti-Spam Guard

- The notifier writes `D:/QM/strategy_farm/state/ws0_notified.json` before attempting SMTP.
- Subsequent pump cycles return `already_disarmed` and do not send again.
- This is separate from the daily health-alarm debounce and shares the sentinel with the Gmail-alarm notifier path.

## Verification

- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/ws0_notifier.py tools/strategy_farm/agent_router.py tools/strategy_farm/repair.py`
- `python -m unittest tools.strategy_farm.tests.test_ws0_notifier tools.strategy_farm.tests.test_agent_router`
- `rg` mail-sender check leaves only:
  - daily health alarm files: `gmail_alarm.py`, `run_gmail_alarm_task.py`, `install_gmail_alarm_scheduled_task.ps1`
  - the one-shot WS-0 notifier: `ws0_notifier.py`
