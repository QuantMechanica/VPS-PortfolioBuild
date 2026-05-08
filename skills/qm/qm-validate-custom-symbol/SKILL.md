---
name: qm-validate-custom-symbol
description: Use for custom-symbol/DST validation with deterministic evidence checks first.
owner: Setup
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_symbol_validation_lint.py
---

# qm-validate-custom-symbol

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_symbol_validation_lint.py --symbol <SYMBOL>.DWX --csv-path <tick-export.csv>
```

Checks tick CSV existence/schema and registry row presence.

## LLM-only scope

- Interpret DST/broker-time mismatch class and escalation path.
