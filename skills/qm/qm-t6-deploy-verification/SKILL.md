---
name: qm-t6-deploy-verification
description: Use for read-only T6 deployment verification with deterministic evidence-bundle checks first.
owner: LiveOps
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_t6_verify_bundle.py
---

# qm-t6-deploy-verification

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_t6_verify_bundle.py --manifest <manifest.json> --experts-log <experts.log> --journal-log <journal.log>
```

Checks required verification artifacts exist before review.

## LLM-only scope

- Contract-level verification interpretation and final signoff narrative.
