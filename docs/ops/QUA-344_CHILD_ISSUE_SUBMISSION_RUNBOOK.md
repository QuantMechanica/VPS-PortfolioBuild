# QUA-344 Child Issue Submission Runbook

## 1) Set env vars (PowerShell)
$env:PAPERCLIP_API_BASE="<api-base>"
$env:PAPERCLIP_PROJECT_ID="<project-id>"
$env:PAPERCLIP_PARENT_ISSUE_ID="QUA-344"
$env:PAPERCLIP_TOKEN="<bearer-token>"

## 2) Submit child issues
powershell -ExecutionPolicy Bypass -File "C:\QM\worktrees\research\docs\ops\Submit-QUA344ChildIssues.ps1" \
  -ApiBase $env:PAPERCLIP_API_BASE \
  -ProjectId $env:PAPERCLIP_PROJECT_ID \
  -ParentIssueId $env:PAPERCLIP_PARENT_ISSUE_ID \
  -BearerToken $env:PAPERCLIP_TOKEN

## 3) Verify
Check output log: `docs/ops/QUA-344_CHILD_ISSUE_SUBMISSION_RESULT.md`
