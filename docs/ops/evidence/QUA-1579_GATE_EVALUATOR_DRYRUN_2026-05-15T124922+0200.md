# QUA-1579 Gate Evaluator Dry-Run Evidence

- Timestamp: 2026-05-15T12:49:22.3864436+02:00
- Command:
  - python C:\QM\repo\framework\scripts\gate_evaluator.py --sqlite D:\QM\reports\pipeline\mt5_queue.db --dry-run
- Output:
  - {"blocked_strategy_count": 0, "escalations_created": 0, "failed_terminal_count": 0, "pass_count": 0, "pass_gate_failed_count": 0, "processed": 0, "requeued_count": 0, "rollforward_failed_count": 0}
- Interpretation:
  - Evaluator executed successfully and found no currently pending status='done' rows needing processing.
