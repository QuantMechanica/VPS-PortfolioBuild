# Worktree Artifact Sweep 2026-05-21

Status: completed before 2026-05-22 orchestration start

## Why This Sweep Exists

The Friday orchestration code/docs were clean, but the repository still showed a large dirty worktree from generated and repaired EA artifacts. That is operationally risky for autonomous agents because a fresh checkout would not contain every build candidate and `git status` would hide new real changes inside old noise.

## Policy Applied

- Commit EA source, baseline setfiles, compiled `.ex5` artifacts, and explicit legacy archives when they represent runnable or intentionally retained strategy inventory.
- Keep ad hoc `.scratch/` scripts and local temp files out of normal status unless they are already tracked fixtures.
- Keep runtime phase keys internally, but expose only Q-series phase IDs on operator surfaces.
- Do not auto-promote any committed EA artifact. Pipeline status still comes only from evidence-backed Q-gates.

## Sweep Result

- Added the missing Q-series helper module required by the dashboard and farm control surfaces.
- Preserved current generated EA inventory under `framework/EAs/`.
- Preserved archived legacy `.ex5` artifacts under `docs/ops/legacy_ea_artifacts/`.
- Added the research/ops documents produced during the latest profitability and pipeline audit pass.
- Ignored new one-off scratch files, `.tmp/`, and registry temp files so future status checks show real work.

## Remaining Guardrail

Committing these artifacts makes the repo reproducible, not profitable. Q11 PASS remains the target gate before Q12 portfolio construction. No artifact in this sweep bypasses Q06-Q11 evidence requirements.
