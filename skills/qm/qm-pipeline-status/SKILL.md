---
name: qm-pipeline-status
description: Use for a read-only snapshot of issue states, EA phase progress, terminal health, and Kanban dispatch. Deterministic collector first.
owner: CEO
reviewer: Board Advisor
last-updated: 2026-05-08
basis: framework/scripts/skill_pipeline_status_snapshot.py
---

# qm-pipeline-status

## Use when

- Start of pipeline heartbeat.
- OWNER requests current pipeline state.
- After restart to verify control-plane + factory visibility.

## Do not use when

- You need deep per-EA performance analysis.
- You intend to mutate issue/phase state.

## Deterministic execution

```bash
python C:/QM/repo/framework/scripts/skill_pipeline_status_snapshot.py
```

Optional persisted snapshot:

```bash
python C:/QM/repo/framework/scripts/skill_pipeline_status_snapshot.py --output C:/QM/repo/artifacts/pipeline_status_snapshot.json
```

Collector output includes:
- issue status counts from Paperclip loopback API
- EA phase directory summary from `D:/QM/reports/pipeline/`
- P2 PASS symbol counts from `report.csv`
- `terminal64.exe` process count
- Kanban `next_task.py --agent ceo --json` payload

## LLM-only judgment

- Interpret warnings (API unreachable, parse failures, stale report trees).
- Decide escalation owner and unblock action if blockers are visible.
