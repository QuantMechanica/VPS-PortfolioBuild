---
title: EA Enhancement and Repair Loop
owner: OWNER
last-updated: 2026-07-22
---

# 14 — EA Enhancement and Repair Loop

This loop distinguishes implementation repair from strategy-mechanics change and
prevents untracked `_vN` proliferation.

## Classification

- **Implementation defect:** code, serialization, timing, data plumbing, sizing,
  deployment, or diagnostics fail to implement the approved card. Repair is allowed
  in the current unqualified build, with new hashes and rerun evidence.
- **Strategy enhancement:** economic entry, exit, sizing, session, filter, or
  portfolio mechanics change. Create a new version and rerun every required phase.
- **Infrastructure defect:** repair the runner/data/environment; do not version the
  strategy or issue a strategy verdict.

## Steps

1. Cite the failing artifact-bound evidence and classify the change.
2. Record the exact card clauses and code paths affected.
3. Implement the smallest deterministic change; never loosen rules merely to
   improve a metric or force trades.
4. Compile, validate registries/setfiles/deployment hashes, and rerun from the
   earliest invalidated phase.
5. Compare old and new evidence, including trade-count, cost, drawdown, and
   behavior changes.
6. Retain failed versions and conclude with recovered, falsified, or blocked.

OWNER decides ambiguous card-mechanics changes and whether a non-converging line of
versions should continue. T6/live requires a new exact-artifact promotion decision.

## Compile is governed, never ad hoc

Step 4's "Compile" means the governed path only: the scoped `build_check.ps1`
wrapper, or `farmctl.py enqueue-compile` into the `COMPILE_EA` queue. If the
governed wrapper fails closed with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`
(factory terminals are live), **do not** reach for an idle MetaEditor, a
disposable profile, a worker-adjacent terminal, or any other side channel to
produce a fresh `.ex5` anyway. Wait for an idle window or enqueue the
governed `COMPILE_EA` work item and let the fleet compile it. A `.ex5` built
outside the governed path and committed anyway is a Hard-Rule (ROT)
violation regardless of how clean the accompanying source repair is — see
`docs/ops/evidence/2026-08-24_rot_remediation_39001_38001_exrevert.md` for
the incident and remediation, and
`tools/strategy_farm/validate_ex5_commit_guard.py` (installed as the shared
`pre-commit` hook in `.git/hooks/`, applies to every worktree) for the
fail-closed guard that now refuses any staged `framework/EAs/**/*.ex5`
change lacking a matching `COMPILE_EA` receipt (`status=done`,
`verdict=COMPILE_OK`, hash-bound to both the `.ex5` and its `.mq5`).
