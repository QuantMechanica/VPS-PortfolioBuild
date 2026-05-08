---
name: qm-zero-trades-recovery
description: Use for zero-trade cohort triage and deterministic threshold classification.
owner: Research
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_zero_trades_triage.py
---

# qm-zero-trades-recovery

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_zero_trades_triage.py --report <phase-report.csv> --threshold 5
```

Outputs `zero_trade_count`, threshold result, and recommended next action.

## LLM-only scope

- Root-cause ranking and hypothesis narrative for versioned recovery steps.
