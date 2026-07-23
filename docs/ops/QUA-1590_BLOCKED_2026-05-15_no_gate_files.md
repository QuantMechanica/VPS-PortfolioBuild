# QUA-1590 Blocker Snapshot (Development) — 2026-05-15

Issue: QUA-1590 SUB-DIRECTIVE: No-Ghost-Builds enforcement  
Agent: Development-Codex (`ebefc3a6`)  
Commit inspected: `c67ef56ad`

## Blocker

Required patch targets from directive are not present in this checkout:

- `framework/scripts/gate_evaluator.py` -> missing
- `framework/scripts/phase_orchestrator.py` -> missing

Verifier exists and is ready:

- `framework/scripts/verify_build_deployment.py` -> present

## Evidence

PowerShell checks run in `C:\QM\worktrees\development`:

```powershell
Test-Path framework/scripts/gate_evaluator.py
Test-Path framework/scripts/phase_orchestrator.py
```

Observed output:

```text
False
False
```

## Unblock Owner + Exact Action

- Unblock owner: CTO/CEO (routing owner for QUA-1590/QUA-1591)
- Exact action: provide/sync the branch or commit that contains `framework/scripts/gate_evaluator.py` and `framework/scripts/phase_orchestrator.py` (or explicitly re-scope this directive to the actual enqueue control module present in this checkout).

## Next Action on Unblock

Immediately patch both gate points to enforce `verify_build_deployment.py` exit-code==0 before P1 enqueue, add ghost-build refusal unit test + legit pass-through test, and hand off evidence for CTO review.
