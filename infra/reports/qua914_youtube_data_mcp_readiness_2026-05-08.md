# QUA-914 YouTube Data MCP Readiness (2026-05-08)

## Decision

- Lane evaluated: **(b) YouTube Data API MCP**
- Package probe: `youtube-data-mcp-server` (`npx -y youtube-data-mcp-server --help`)
- Status: **blocked**

## Blocking Prerequisite

- Missing secret: `YOUTUBE_API_KEY`

## Evidence

Readiness check command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-YouTubeDataMcpReadiness.ps1
```

Returned JSON summary:

- `status=blocked`
- `missing=["YOUTUBE_API_KEY"]`
- `unblock_owner=OWNER/CTO`

Direct package probe:

```powershell
npx -y youtube-data-mcp-server --help
```

Observed failure: `Error: YOUTUBE_API_KEY environment variable is not set.`

## Unblock Owner + Action

- **Unblock owner:** OWNER/CTO
- **Action:** provide approved `YOUTUBE_API_KEY` to this runtime and re-run readiness check + probe.

## Next Action After Unblock

1. Re-run `Test-YouTubeDataMcpReadiness.ps1` (expect `status=ready` and exit `0`).
2. Run resolver for target video via MCP lane and hand output to YouTube Analyst.
