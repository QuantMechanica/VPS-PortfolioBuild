# QUA-344 Child-Issue Proposal — Build + Compile Handoff (2026-04-28)

Parent issue: `QUA-344`  
Mode: implementation continuation (Pipeline-Operator)

## Why child issue now

Pipeline execution is blocked on upstream build outputs (`ea_id`, compiled `.ex5`, runnable payload binding). This is parallelizable owner work and should be tracked as a child issue instead of repeated heartbeat polling.

## Proposed child issue

- Title: `QUA-344 follow-up — DEV build/compile binding for SRC04_S05 (lien-inside-day-breakout)`
- Assignee role: `Dev`
- Reviewer role: `CTO`
- Priority: `medium`
- Parent: `QUA-344`

## Child issue objective

Produce executable artifact and metadata required for first factory P1 baseline dispatch.

## Child issue acceptance criteria

1. Assign `ea_id` for `SRC04_S05` and update card header.
2. Build EA and publish compiled binary path (`.ex5`) in repo/runtime handoff note.
3. Provide first-run setfile/inputs binding aligned to card defaults.
4. Provide dispatch payload fields:
   - `ea_id`
   - `ea_binary_path`
   - `target_terminal` (or `any`)
   - baseline date window approved by CTO
5. Attach evidence note under `docs/ops/` with build timestamp + compile PASS.

## Pipeline-Operator next action upon child completion

Run first one-symbol P1 baseline using `docs/ops/QUA-344_P1_BASELINE_TEMPLATE_2026-04-28.json` with filled build fields, then publish filesystem-truth completion evidence.
