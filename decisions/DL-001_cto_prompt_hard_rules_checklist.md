# DL-001 - CTO Prompt Hard Rules Checklist Adaptation

Date: 2026-04-27  
Issue: QUA-147  
Owner: CTO

## Decision

Adopt the V5 Hard Rules block in the active CTO runtime prompt as an explicit checkbox checklist (`HARD RULES CHECKLIST`) and create a separate git-tracked checklist document at [`docs/ops/V5_HARD_RULES_CHECKLIST.md`](/C:/QM/repo/docs/ops/V5_HARD_RULES_CHECKLIST.md).

## Why

- QUA-147 requires dual representation: inline in prompt + standalone git document.
- Checkbox form reduces omission risk during code review and pipeline decisions.
- `paperclip-prompts/cto.md` is owner-managed and remains unchanged by CTO runs.

## Scope

- Updated runtime prompt file:
  - `C:\QM\paperclip\data\instances\default\companies\03d4dcc8-4cea-4133-9f68-90c0d99628fb\agents\241ccf3c-ab68-40d6-b8eb-e03917795878\instructions\AGENTS.md`
- Added git canonical checklist:
  - [`docs/ops/V5_HARD_RULES_CHECKLIST.md`](/C:/QM/repo/docs/ops/V5_HARD_RULES_CHECKLIST.md)

## Non-Goals

- No edits to `paperclip-prompts/*.md` (owner-managed boundary).
- No strategy pass/fail decisions or framework behavior changes.
