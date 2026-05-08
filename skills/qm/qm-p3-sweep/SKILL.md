---
name: qm-p3-sweep
description: Use for P3 parameter sweep only after confirmed P2 PASS symbols. Deterministic guard first.
owner: Research
reviewer: CEO
last-updated: 2026-05-08
basis: framework/scripts/skill_p3_sweep_guard.py
---

# qm-p3-sweep

## Use when

- P2 has PASS symbols.
- CEO approved promotion to P3.

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_p3_sweep_guard.py --ea-id QM5_<NNNN>
```

Guard output includes:
- `p2_report_exists`
- `p2_pass_symbol_count`
- `pass_symbols`
- `next_action`

## Execute sweep

Run canonical sweep workflow only on returned PASS symbols.

## LLM-only judgment

- Parameter-selection rationale and overfit-risk interpretation.
