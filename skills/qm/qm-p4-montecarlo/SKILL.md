---
name: qm-p4-montecarlo
description: Use for P4 robustness only after confirmed P3.5 PASS. Deterministic guard first.
owner: Research
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_p4_montecarlo_guard.py
---

# qm-p4-montecarlo

## Use when

- P3.5 report has PASS for at least one symbol.
- CEO authorized P4.

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_p4_montecarlo_guard.py --ea-id QM5_<NNNN>
```

Guard output includes:
- `p35_report_exists`
- `p35_pass_count`
- `eligible_symbols`
- `next_action`

## Execute Monte Carlo

Run 1000-pass Monte Carlo on eligible symbols and write JSON evidence to P4 report folder.

## LLM-only judgment

- Robustness interpretation and final PASS/FAIL narrative.
