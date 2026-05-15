# QUA-1579 Gate Evaluator Scheduled Task Definition Snapshot

- task_name: QM_GateEvaluator_5min
- state: Ready
- execute: C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe
- working_directory: C:\QM\repo
- arguments:
  - "C:\QM\repo\framework\scripts\gate_evaluator.py" --sqlite "D:\QM\reports\pipeline\mt5_queue.db" --max-retries 3 --limit 200 --paperclip-base "http://127.0.0.1:3100" --company-id "03d4dcc8-4cea-4133-9f68-90c0d99628fb" --project-id "71b6d994-70ba-4a28-bd62-732b42a9ea58"
- principal.logon_type: S4U
- principal.run_level: Highest
- trigger.repetition.interval: PT5M
- trigger.repetition.duration: P3650D
- last_run_time: 2026-05-15T12:51:51+02:00
- last_task_result: 0
- next_run_time: 2026-05-15T12:55:55+02:00

## Interpretation
- Registration matches directive contract: S4U principal, 5-minute cadence, expected gate evaluator command line.
