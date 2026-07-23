# QUA-1517 Investigation - kanban_archive_daily auto-blocked execution issues (2026-05-14)

## Scope
Investigate why routine `r-kanban-archive-daily` creates/accumulates blocked execution issues.

## Evidence
- Routine run history for `1e1296be-3903-46b9-ae22-a4005beae152` shows mixed outcomes in last 5 runs:
  - `completed`: 2
  - `failed`: 2
  - `issue_created`: 1
- Failed runs:
  - Run `890a2471-692f-4e66-aff1-06c1211b2f84` (2026-05-08T21:00:01Z) -> `failureReason: Execution issue moved to blocked`, linked issue `QUA-975`.
  - Run `f255b41e-61e5-4e74-b83c-92127261c2de` (2026-05-09T21:00:07Z) -> `failureReason: Execution issue moved to blocked`, linked issue `QUA-1406`.
- New continuation issue on 2026-05-13:
  - Run `47fa9fc8-54b6-4ea0-9269-19ed267e1c79` -> `issue_created`, linked issue `QUA-1482` (blocked).
  - Latest comment on QUA-1482 records retry failure: `adapter_failed - You've hit your usage limit ...` and notes no live execution path.
- Archive engine is currently healthy:
  - `kanban/audit_log.jsonl` has successful `kanban_archive_daily` entries through 2026-05-14T21:01:50Z.
  - Most recent routine run (`52af8505-154e-4200-aa59-77efbfe81f57`) status is `completed`.

## Conclusion
The blocking pattern is not caused by `archive_done_killed.py` functional failure. It is an execution-path reliability issue (routine-created execution issue retries hitting adapter/runtime limits and being auto-blocked).

## Unblock Owner + Action
- Owner: OWNER/Platform
- Action: stabilize routine execution path for `kanban_archive_daily` (process adapter or equivalent non-LLM deterministic runner) so retries do not depend on constrained LLM runtime.
- CTO follow-up after platform action: validate 3 consecutive scheduled runs with `completed` status and zero new blocked execution issues.
