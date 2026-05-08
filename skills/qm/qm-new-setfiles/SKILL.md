---
name: qm-new-setfiles
description: Use when generating baseline backtest setfiles for an EA before P2. This skill is policy-first and calls a deterministic runner.
owner: Pipeline-Operator
reviewer: CTO
last-updated: 2026-05-08
basis: framework/scripts/skill_new_setfiles_run.py
---

# qm-new-setfiles

## Use when

- EA build exists and `sets/` is missing or incomplete for baseline symbols.
- Preparing first P2 baseline run.

## Do not use when

- Setfiles are already current.
- You are doing one-off symbol tuning (edit `.set` directly).

## Deterministic execution

Run:

```bash
python C:/QM/repo/framework/scripts/skill_new_setfiles_run.py --ea-label QM5_<NNNN>_<slug> --period H1
```

Optional validation-only:

```bash
python C:/QM/repo/framework/scripts/skill_new_setfiles_run.py --ea-label QM5_<NNNN>_<slug> --period H1 --dry-run
```

The script enforces:
- EA directory and `.ex5` existence
- generator presence
- output count sanity (`sets/`)
- structured JSON result (`status`, `checks`, `setfile_count`, `next_action`)

## LLM-only judgment

- If script returns `warning` or mismatched count, decide whether to regenerate, inspect template drift, or escalate to CTO.

## Next skill

After success, continue with `qm-p2-baseline`.
