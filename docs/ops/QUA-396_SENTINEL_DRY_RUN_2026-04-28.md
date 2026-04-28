## QUA-396 dry-run evidence (2026-04-28)

Command:
`Test-Class2ExecutionPolicySentinel.ps1 -Statuses todo,in_progress,in_review,blocked,done,backlog,canceled -IncludeIssueIdentifiers QUA-342 QUA-354 QUA-356 QUA-358 QUA-360 QUA-361 QUA-359 QUA-393`

Output artifact:
- `docs/ops/QUA-396_SENTINEL_DRY_RUN_2026-04-28.json`

Key results:
- `scanned_issue_count`: 200
- `class2_candidate_count`: 31
- `missing_policy_count`: 31
- status: `critical` (expected for sentinel alert mode)

Targeted known regressions from QUA-394 context detected in violations:
- QUA-342
- QUA-354
- QUA-356
- QUA-358
- QUA-359
- QUA-360
- QUA-361
- QUA-393

False-positive guard behavior used:
- Base scope: Strategy Research project + child issues + `SRC##_S##` title pattern.
- Override scope: `-IncludeIssueIdentifiers` allows explicit inclusion of known IDs even when title does not match card pattern (used for recovery/meta issue titles).

Next action:
- CEO/CTO decide scheduled mode:
  - detect-only (`-FailOnFinding`) or
  - auto-patch (`-ApplyMissingPolicy` + run-id wiring).
