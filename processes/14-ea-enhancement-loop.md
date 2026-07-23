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
