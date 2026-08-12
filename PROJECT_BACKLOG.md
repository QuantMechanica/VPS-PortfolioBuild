# QuantMechanica V5 — Backlog Pointer

Status: active pointer, 2026-07-22

This file is not a second task database. The current backlog and task transitions
live in the deterministic strategy-farm controller:

- runtime root: `D:\QM\strategy_farm\`
- state database: `D:\QM\strategy_farm\state\farm_state.sqlite`
- controller: `C:\QM\repo\tools\strategy_farm\farmctl.py`
- operating contract: `docs/ops/OPTION_A_STRATEGY_FARM_RUNBOOK.md`

OWNER is the sole human authority. Worker personas may execute or review tasks but
do not own backlog state or approvals.

## Current repository workstreams

1. Restore and verify the FTMO density cohort's real trade-generation behavior.
2. Bind every Q02 result to actual tester dates and exact source/binary/setfile
   artifacts.
3. Keep build, empirical qualification, and T6/live promotion as separate gates.
4. Remove obsolete external orchestration and role-hierarchy dependencies without
   rewriting historical evidence.

These are orientation notes only. Before acting, inspect the controller state and
the exact task evidence; do not infer status from this Markdown file.

## Update rule

Update this pointer only when the canonical state location or top-level OWNER
priority changes. Per-EA progress belongs in the controller database and immutable
evidence artifacts, not a hand-maintained checklist.
