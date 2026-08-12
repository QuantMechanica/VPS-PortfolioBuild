# CODEX CROSS-REVIEW BRIEF — 2026-07-24 (single round)

You are Codex. You already produced an independent compliance audit
(`D:\QM\reports\audit\codex_compliance_2026-07-24\`). Claude has now published the
merged audit deliverables. This is the single agreed cross-review round: **you review
Claude's result**. There will be no further discussion round — unresolved disputes go
to the escalation file, decided by OWNER.

## Review targets (canonical checkout, read-only)

- `C:\QM\repo\docs\ops\source_harvest\audit\COMPLIANCE_MATRIX.md` (primary)
- `C:\QM\repo\docs\ops\source_harvest\audit\AUDIT_REPORT.md` §3 (Compliance) only
- Supporting evidence: `C:\QM\repo\docs\ops\source_harvest\audit\evidence\compliancefinal__qm_event_scan.json`, `compliancefinal__set_risk_scan.txt`

## Your job

1. Verify the merged matrix against YOUR audit and fresh spot-checks (≥5 cells of your
   choosing, re-derived from primary evidence, not from either audit's notes).
2. Check the "Divergence resolution" section: were all 5 contested cells resolved to
   the genuinely stricter verdict? Any divergence between the two audits that Claude
   MISSED (cells where your matrix was stricter but the merged matrix kept the looser
   verdict)?
3. Check the live totals arithmetic (150/40/2 over 192 cells) and the 11-instance
   killswitch FAIL set and 24× max-DD FAIL against your own numbers.
4. Flag any claim in §3 that your evidence contradicts.

## Output

Write `D:\QM\reports\audit\codex_compliance_2026-07-24\CROSS_REVIEW_CODEX.md`:
numbered points, each = CONFIRM / DISPUTE (with evidence path) / ADDITION (new material
fact with evidence). End with a one-line overall verdict:
`CROSS_REVIEW: CONFIRMED` or `CROSS_REVIEW: DISPUTED (<n> points)`.

Then close your router task:
`python C:\QM\repo\tools\strategy_farm\agent_router.py update-task <task_id> --state REVIEW --artifact-path "D:\QM\reports\audit\codex_compliance_2026-07-24\CROSS_REVIEW_CODEX.md" --verdict "<your one-line verdict>"`

## Hard constraints

Identical to the audit brief: strictly read-only outside your output dir, no T_Live
writes, no Factory_OFF/ON, no config/task/git changes, no builds, no MT5 interaction.
Do not modify Claude's files — disputes go in YOUR review file only.
