---
name: qm-strategy-card-extraction
description: Use when Research extracts strategies from an OWNER-approved source into V5 Strategy Cards. Do not use without a durable source-approval record, and do not use to evaluate or score a card.
---

# qm-strategy-card-extraction

## Deterministic preflight

Confirm OWNER approval from a durable repository decision or evidence record;
do not depend on an external issue service. Read the bounded source completely,
extract depth-first, preserve citations, and leave `ea_id` allocation to the
deterministic registries after approval.

```bash
python C:/QM/repo/framework/scripts/skill_card_schema_lint.py --card <path-to-card.md>
```

Checks required sections and ML-ban token hits.

## LLM-only scope

- Deep extraction reasoning from source material.
- Traceability and hypothesis framing.
