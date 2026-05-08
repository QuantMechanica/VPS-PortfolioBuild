---
name: qm-build-ea-from-card
description: Use when building an approved strategy card into EA code. Deterministic registry/build guard first.
owner: Development
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_build_ea_guard.py
---

# qm-build-ea-from-card

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_build_ea_guard.py --ea-id QM5_<NNNN> --ea-label QM5_<NNNN>_<slug>
```

Checks: `ea_id_registry.csv`, `magic_numbers.csv`, EA folder presence.

## LLM-only scope

- Translate approved card logic into the 4-module EA architecture.
- Validate entry/exit/filter fidelity against the card.
