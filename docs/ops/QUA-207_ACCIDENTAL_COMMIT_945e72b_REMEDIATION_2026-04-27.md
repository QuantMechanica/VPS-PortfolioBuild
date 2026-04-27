# QUA-207 Accidental Commit Remediation Note (2026-04-27)

Commit in question: `945e72b`  
Context: intended to commit QUA-207 issue-comment automation, but included unrelated pre-staged files.

## Unintended files in `945e72b`

- `docs/ops/AGENT_SKILL_MATRIX.md`
- `docs/ops/ORG_SELF_DESIGN_MODEL.md`
- `docs/ops/QUA-213_PROCESS_AUDIT_2026-04-27.md`
- `processes/01-ea-lifecycle.md`
- `processes/README.md`

## Intended files in `945e72b`

- `infra/scripts/New-QUA207IssueComment.ps1`
- `docs/ops/QUA-207_ISSUE_COMMENT_2026-04-27.md`
- `infra/README.md`

## Safe follow-up options (no history rewrite)

1. Keep `945e72b` as-is.
2. Create a corrective commit restoring only unintended files to pre-`945e72b` content.
3. Create a corrective commit that restores unintended files and re-applies intended QUA-207 files only.

## Command template for option 2 (do not run until approved)

```powershell
git restore --source 945e72b^ -- docs/ops/AGENT_SKILL_MATRIX.md docs/ops/ORG_SELF_DESIGN_MODEL.md docs/ops/QUA-213_PROCESS_AUDIT_2026-04-27.md processes/01-ea-lifecycle.md processes/README.md
git commit -m "docs(process): restore files unintentionally included in 945e72b"
```

## Guardrail now in place

- `infra/scripts/Assert-CommitAllowlist.ps1` added in `dcbec93` to prevent future mixed staged-file commits.
