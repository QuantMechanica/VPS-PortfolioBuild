# QUA-344 Interaction Draft — suggest_tasks (2026-04-28)

Prepared interaction payload:

- `docs/ops/QUA-344_INTERACTION_SUGGEST_TASKS_2026-04-28.json`

Intended API action (for controller/harness):

- `POST /api/issues/{issueId}/interactions`
- `kind: suggest_tasks`
- `continuationPolicy: wake_assignee`

Purpose:

Create the Dev+CTO child-task chain required to unblock executable binding and wake Pipeline-Operator after response.
