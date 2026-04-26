# Interim Paperclip -> GitHub Issues Sync (QUAA-191)

This runbook covers the interim one-way sync from Paperclip issues to GitHub issues.

## Scope

- Direction: Paperclip -> GitHub only
- Target repo default: `QuantMechanica/quantmechanica-ops`
- Behavior:
  - Create a GitHub issue when a Paperclip issue has no mapped GitHub issue
  - Post a GitHub comment when Paperclip status changes
- Idempotency:
  - Created issues include marker `paperclip-issue-id:<paperclipIssueId>` in the body
  - Status comments include marker `paperclip-sync-status:<paperclipIssueId>:<status>:<updatedAt>`
  - Local state persists mapping and last synced status

## Script

- Path: `Company/scripts/infra/paperclip_github_issues_sync.sh`

## Dependencies

- `bash`
- `curl`
- `jq`
- `gh` (GitHub CLI, authenticated)

## Required environment variables

- `PAPERCLIP_API_URL`
- `PAPERCLIP_API_KEY`
- `PAPERCLIP_COMPANY_ID`

## Optional environment variables

- `GITHUB_REPO` (default: `QuantMechanica/quantmechanica-ops`)
- `PAPERCLIP_ISSUE_STATUSES` (default: `todo,in_progress,in_review,blocked,done,cancelled,backlog`)
- `PAPERCLIP_UI_BASE_URL` (default: `PAPERCLIP_API_URL`)
- `SYNC_STATE_PATH` (default: `${XDG_STATE_HOME:-$HOME/.local/state}/quantmechanica/paperclip_github_issues_sync_state.json`)
- `DRY_RUN` (`1` = no writes to GitHub or state file)
- `PAPERCLIP_IDENTIFIER_FILTER` (optional exact identifier filter, for example `QUAA-191`)

## Quick start

1. Authenticate GitHub CLI:
   - `gh auth login`
2. Export Paperclip env:
   - `export PAPERCLIP_API_URL="http://127.0.0.1:3100"`
   - `export PAPERCLIP_API_KEY="<paperclip-token>"`
   - `export PAPERCLIP_COMPANY_ID="<company-id>"`
3. Run dry-run:
   - `DRY_RUN=1 bash Company/scripts/infra/paperclip_github_issues_sync.sh`
4. Run live:
   - `bash Company/scripts/infra/paperclip_github_issues_sync.sh`

Smoke-test one ticket only:

- `PAPERCLIP_IDENTIFIER_FILTER=QUAA-191 bash Company/scripts/infra/paperclip_github_issues_sync.sh`

## Cron examples

Hourly default:

```cron
5 * * * * /usr/bin/env bash /opt/quantmechanica/Company/scripts/infra/paperclip_github_issues_sync.sh >> /var/log/paperclip_github_issues_sync.log 2>&1
```

Daily option:

```cron
15 2 * * * /usr/bin/env bash /opt/quantmechanica/Company/scripts/infra/paperclip_github_issues_sync.sh >> /var/log/paperclip_github_issues_sync.log 2>&1
```

## State file

State is persisted to `SYNC_STATE_PATH` and stores:

- `paperclip_issue_id -> github_issue_number`
- `last_synced_status`
- `last_synced_updated_at`

Reference state schema sample:

- `Company/infra/vps/paperclip_github_issues_sync_state.example.json`
