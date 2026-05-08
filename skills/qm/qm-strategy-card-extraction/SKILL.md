---
name: qm-strategy-card-extraction
description: Use for extracting strategy cards from research sources under V5 constraints. Deterministic schema/ML-ban lint first.
owner: Research
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_card_schema_lint.py
---

# qm-strategy-card-extraction

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_card_schema_lint.py --card <path-to-card.md>
```

Checks required sections and ML-ban token hits.

## LLM-only scope

- Deep extraction reasoning from source material.
- Traceability and hypothesis framing.
