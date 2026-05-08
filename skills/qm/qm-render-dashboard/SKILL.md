---
name: qm-render-dashboard
description: Use when DevOps must refresh Paperclip dashboard artifacts after state changes. Deterministic runner first.
owner: DevOps
reviewer: CEO
last-updated: 2026-05-08
basis: framework/scripts/skill_render_dashboard_run.py
---

# qm-render-dashboard

## Use when

- Kanban/pipeline state changed and dashboard is stale.
- OWNER/CEO requests refresh.

## Do not use when

- Active backtests are still producing state you depend on.
- You are changing dashboard code (separate engineering task).

## Deterministic execution

Main dashboard only:

```bash
python C:/QM/repo/framework/scripts/skill_render_dashboard_run.py
```

Main + strategies:

```bash
python C:/QM/repo/framework/scripts/skill_render_dashboard_run.py --include-strategies
```

The script runs renderers and emits JSON with:
- command return codes
- artifact existence
- artifact size sanity check
- `next_action`

## LLM-only judgment

- If output is `warning`, decide whether stale upstream source data or render failure needs escalation.
