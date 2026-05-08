# QUA-212 Patchset Paths (2026-05-08)

Use only these paths for review/commit to avoid unrelated workspace changes.

## Target files
- framework/scripts/validate_phase2b.ps1
- framework/scripts/tests/test_phase_runners_contract.py
- framework/scripts/tests/test_phase_verdict_semantics.py
- docs/ops/QUA-212_PHASE2B_HANDOFF_2026-05-08.md

## Verification command
- powershell -ExecutionPolicy Bypass -File framework/scripts/validate_phase2b.ps1

## Path-scoped staging command
```powershell
git -C C:/QM/repo add \
  framework/scripts/validate_phase2b.ps1 \
  framework/scripts/tests/test_phase_runners_contract.py \
  framework/scripts/tests/test_phase_verdict_semantics.py \
  docs/ops/QUA-212_PHASE2B_HANDOFF_2026-05-08.md
```

## Suggested commit message
- `QUA-212: harden phase2b runner validation and verdict semantics`
