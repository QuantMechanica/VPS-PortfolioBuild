# Interactive orchestrator heartbeat helper

Date: 2026-09-12  
Router task: `408d862e-2a66-4fdd-a702-f3f05c189e78`  
Disposition: REVIEW

## Result

`run_agent_orchestration_task.py` now supports two operator-only modes that do not require `--agent`:

- `--touch-interactive-flag` atomically writes the guard marker once and exits.
- `--interactive-heartbeat-loop --minutes N` writes immediately, refreshes every ten minutes, and exits when its PID-reuse-safe parent identity disappears or the bounded duration expires.

The JSON marker contains `pid`, `host`, and `heartbeat_at`, plus a schema, mode, and owner token. The existing headless admission guard reads the same heartbeat and treats it as stale after 30 minutes. Loop cleanup compares the owner token before deletion so an older helper cannot remove a newer interactive session's marker.

The loop polls parent liveness every five seconds while refreshing only at the ten-minute cadence. No loop was started during this scheduled orchestration cycle.

## Lease and safety scope

Router task leases, the outer headless-session lease, per-slot locks, quota selection, and scheduled-task cadence are unchanged. The helper never launches an agent, terminal, tester, or trading process and never touches T_Live or AutoTrading.

## Verification

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_agent_orchestration_lock.py \
  tools/strategy_farm/tests/test_run_agent_orchestration_heartbeat.py
20 passed

python -m py_compile tools/strategy_farm/run_agent_orchestration_task.py
PASS
```

Coverage includes the exact writer fields, fresh admission, staleness after 30 minutes, parent disappearance, missing parent before first write, owner-safe cleanup, the pre-existing headless skip path, and the existing scheduled-lane heartbeat behavior.
