# QUA-1579 Gate Evaluator Live Run Evidence

- Timestamp: 2026-05-15T12:54:22.4983071+02:00
- Command:
  - python C:\QM\repo\framework\scripts\gate_evaluator.py --sqlite D:\QM\reports\pipeline\mt5_queue.db --max-retries 3 --limit 200 --paperclip-base http://127.0.0.1:3100 --company-id 03d4dcc8-4cea-4133-9f68-90c0d99628fb --project-id 71b6d994-70ba-4a28-bd62-732b42a9ea58
- Output:
  - {"blocked_strategy_count": 0, "escalations_created": 0, "failed_terminal_count": 0, "pass_count": 0, "pass_gate_failed_count": 0, "processed": 0, "requeued_count": 0, "rollforward_failed_count": 0}
- Interpretation:
  - Live evaluator invocation succeeded on production queue path; no eligible status='done' rows were pending at execution time.
