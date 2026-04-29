# QUA-260 CTO Skills Review (2026-04-27)

Issue: `QUA-260`  
Reviewer: CTO (`241ccf3c-ab68-40d6-b8eb-e03917795878`)  
Run ID: `604286bd-f5d8-4e08-b1d2-65dfc1a0950e`

## A) Custom skill body review (6/6)

1. `skills/qm/qm-validate-custom-symbol/SKILL.md`  
Verdict: PASS  
Notes: Procedure aligns with `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md` and preserves setup-vs-strategy boundary.

2. `skills/qm/qm-strategy-card-extraction/SKILL.md`  
Verdict: PASS  
Notes: Routing and depth-first extraction discipline align with `paperclip-prompts/research.md` and card template governance.

3. `skills/qm/qm-build-ea-from-card/SKILL.md`  
Verdict: PASS after correction  
Fixes applied:
- Corrected compile command to actual script interface: `compile_one.ps1 -EAPath ... -Strict`.
- Removed references to non-present helper scripts as mandatory execution paths.
- Clarified `.DWX` strip boundary as deploy-packaging only.

4. `skills/qm/qm-run-pipeline-phase/SKILL.md`  
Verdict: PASS  
Notes: Kept current runtime contract (`P3.5/P5/P5b/P5c/P6/P7/P8`) matching `framework/scripts/run_phase.ps1` `ValidateSet`; did **not** widen to P1-P4.

5. `skills/qm/qm-t6-deploy-verification/SKILL.md`  
Verdict: PASS  
Notes: Matches `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md` and preserves AutoTrading-OFF / read-only verification contract.

6. `skills/qm/qm-zero-trades-recovery/SKILL.md`  
Verdict: PASS  
Notes: Consistent with `processes/02-zt-recovery.md`; references forthcoming `processes/14-ea-enhancement-loop.md` as future wrapper.

## B) Required marketplace skills review + pin lock (7/7)

Repositories cloned at HEAD for review:
- `anthropics/skills` at `5128e1865d670f5d6c9cef000e6dfc4e951fb5b9`
- `obra/superpowers` at `6efe32c9e2dd002d0c394e861e0529675d1ab32e`

Reviewed skill bodies:
- `anthropics/skills/skill-creator`
- `anthropics/skills/pdf`
- `anthropics/skills/xlsx`
- `obra/superpowers/verification-before-completion`
- `obra/superpowers/using-git-worktrees`
- `obra/superpowers/test-driven-development`
- `obra/superpowers/systematic-debugging`

Verdict: PASS for technical suitability to assigned QM roles.  
Pin updates applied in `skills/marketplace/INDEX.md` with `commit_pin`, `reviewed_at`, `reviewed_by`.

## C) Skill import execution (blocked)

Attempted imports for:
- All 6 custom local skills (`skills/qm/*`)
- All 7 required marketplace skills

Endpoint used:  
`POST /api/companies/{companyId}/skills/import`

Result: all requests failed with HTTP 403:
- `{"error":"Missing permission: can create agents"}`

Evidence file:
- `artifacts/qua-260/QUA-260_skill_import_attempts_2026-04-27.json`

Unblock owner/action:
- OWNER/CEO: grant this CTO runtime token (`PAPERCLIP_AGENT_ID=241ccf3c-ab68-40d6-b8eb-e03917795878`) permission `can create agents`, then rerun the 13 import calls.
