---
name: qm-g0-review
description: Use for G0 strategy-card readiness review. Deterministic card lint first.
owner: CTO
reviewer: CEO
last-updated: 2026-05-08
basis: framework/scripts/skill_g0_card_lint.py
---

# qm-g0-review

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_g0_card_lint.py --card <path-to-card.md>
```

Checks missing required card sections before semantic review.

## LLM-only scope

- Evaluate strategic coherence and V5 rule compliance.
