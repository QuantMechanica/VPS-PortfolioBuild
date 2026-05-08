---
name: qm-run-pipeline-phase
description: Use for autonomous phases P3.5/P5/P5b/P5c/P6/P7/P8 on built, registered EAs. Deterministic guard first.
owner: Pipeline-Operator
reviewer: Quality-Tech
last-updated: 2026-05-08
basis: framework/scripts/skill_phase_runner_guard.py + framework/scripts/run_phase.ps1
---

# qm-run-pipeline-phase

## Use when

- Phase is one of `P3.5,P5,P5b,P5c,P6,P7,P8`.
- EA is compiled and has active registry symbols.

## Deterministic preflight

```bash
python C:/QM/repo/framework/scripts/skill_phase_runner_guard.py --ea-id QM5_<NNNN> --phase P5
```

Guard checks:
- phase validity
- active symbol rows in `magic_numbers.csv`
- `.ex5` discovery
- JSON `status` + `next_action`

## Execute phase (after `status=ok`)

```powershell
pwsh C:/QM/repo/framework/scripts/run_phase.ps1 -EAId QM5_<NNNN> -Phase <P3.5|P5|P5b|P5c|P6|P7|P8>
```

## LLM-only judgment

- Interpret `YELLOW`, `NO_REPORT`, `SETUP_DATA_*` outcomes and escalation route.
