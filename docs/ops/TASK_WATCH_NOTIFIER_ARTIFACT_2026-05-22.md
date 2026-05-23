# Task Watch Notifier Artifact - 2026-05-22

Task: `e5496ffe-d69a-404f-a597-ae13408fd911`

## Implementation

- Added `tools/strategy_farm/task_watch_notifier.py`.
- Folded it into the pump after the WS-0 notifier.
- Seeded watch group `ws2_ws4_review_2026_05_22`:
  - `6d365393-9a2a-4784-aa60-ba519365e5b3` -> `REVIEW`
  - `d6e2f4d9-8351-4503-9f83-b33770095841` -> `REVIEW`
- Later states such as `APPROVED`, `FAILED`, or `BLOCKED` satisfy a `REVIEW` target so the watch cannot miss a fast review-close.
- Sentinel: `D:/QM/strategy_farm/state/task_watch_notifier.json`.
- Mail sender: reuses `gmail_alarm._send_mail`.
- Spam guard: sentinel is written before SMTP send, then updated with `mail_result`, so a pump retry cannot re-fire the same watch group.

## Verification

- `python -m py_compile tools/strategy_farm/task_watch_notifier.py tools/strategy_farm/farmctl.py`: PASS
- `python -m unittest tools.strategy_farm.tests.test_task_watch_notifier`: PASS
- Combined focused suite including WS-0 and basket-work-item regression: PASS, 5 tests

## Verdict

`TASK_WATCH_NOTIFIER_READY`

The current seed group will send one combined OWNER email on the next pump cycle if not already disarmed, because both watched tasks have reached at least `REVIEW`.
