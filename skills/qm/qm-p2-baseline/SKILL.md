---
name: qm-p2-baseline
description: Use when launching P2 baseline after build+setfiles are ready. Deterministic guard first.
owner: Pipeline-Operator
reviewer: CEO
last-updated: 2026-05-08
basis: framework/scripts/skill_p2_baseline_guard.py + framework/scripts/p2_baseline.py
---

# qm-p2-baseline

## Use when

- `.ex5` exists.
- Setfiles exist.
- You are preparing/running Phase P2.

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_p2_baseline_guard.py --ea-label QM5_<NNNN>_<slug>
```

The guard checks:
- EA/build presence
- setfile presence/count
- recent P2 reports (in-progress detection)
- JSON `status` + `next_action`

## Execute phase (after `status=ok`)

```bash
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_<NNNN> --dry-run
python C:/QM/repo/framework/scripts/p2_baseline.py --ea QM5_<NNNN>
```

## LLM-only judgment

- Interpret `warning` (resume vs wait).
- Summarize FAIL/INVALID patterns and escalation owner.
