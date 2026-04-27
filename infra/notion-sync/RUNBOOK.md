# Notion -> Git Mirror — Documentation-KM Runbook

> **Issue trail:** QUA-151 (verification + first one-shot), CEO policy decision 2026-04-27 (QUA-151 comment `2e2f2b1f`).
> **Owner:** Documentation-KM agent.
> **Cadence:** daily 23:00 UTC, fired by a Paperclip routine that creates an issue assigned to Documentation-KM.

This is the runbook the Documentation-KM agent follows when the daily routine fires. It deliberately does not invoke a stand-alone PowerShell/Python script — the agent uses its existing Notion MCP read access and Git write access (cwd `C:\QM\repo`) to perform the export, which avoids storing a separate Notion API token and matches the rest of the Paperclip company's heartbeat-driven model.

## Routine wiring (registered + self-running)

The routine is **already registered and active** in the Paperclip control plane on this VPS. No external scheduler is involved — Paperclip itself fires the routine.

| Field | Value |
|---|---|
| Routine id | `32a1721d-e194-4f8f-ab9b-956096368879` |
| Title | `Notion -> Git nightly mirror sync` |
| Assignee | Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`) |
| Status | `active` |
| Priority | `medium` |
| Concurrency policy | `coalesce_if_active` |
| Catch-up policy | `skip_missed` |
| Trigger id | `6a0d42aa-3b4c-4f51-9f26-93acde130765` |
| Trigger kind | `schedule` |
| Cron expression | `0 23 * * *` |
| Timezone | `UTC` |
| First fire | `2026-04-27T23:00:00Z` |

Inspection commands (Documentation-KM or DevOps as cron-health reviewer):

```sh
# Routine + triggers
curl -s -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  http://127.0.0.1:3100/api/routines/32a1721d-e194-4f8f-ab9b-956096368879

# Recent fires + active issue
curl -s -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  "http://127.0.0.1:3100/api/companies/03d4dcc8-4cea-4133-9f68-90c0d99628fb/routines" | \
  python -c "import json,sys; [print(r['title'], r['status'], r.get('lastTriggeredAt')) for r in json.load(sys.stdin)]"
```

To pause (DevOps, on incident): `PATCH /api/routines/<id>` with `{"status":"paused"}`. Re-enable with `{"status":"active"}`. Do not delete the routine — Documentation-KM must retain history of fires.

To change cadence: `PATCH /api/routines/<id>/triggers/<trigger-id>` with a new `cronExpression`. Document any cadence change in this file + `paperclip/routines/routines.md`.

## When the routine fires

1. The Paperclip routine creates a new issue assigned to Documentation-KM with title `Nightly Notion -> Git mirror sync — YYYY-MM-DD` and description pointing here.
2. The agent picks up the issue on the next heartbeat (or immediately, since the routine wakes the agent).
3. The agent runs the steps below.
4. The agent comments on the routine-issue with the result (commit hash OR `no-diff: nothing to commit`) and closes the issue.

## Steps

### 1. Read the manifest

Open `infra/notion-sync/manifest.yaml`. Iterate `pages` where `direction == "notion-to-mirror"`. Skip entries with `direction: skip`.

For each page entry, capture: `notion_id`, `notion_title`, `slug`.

### 2. Fetch each page

For each manifest entry, call `mcp__claude_ai_Notion__notion-fetch` with `id: <notion_id>`. The response includes a `text` field containing Notion-flavored Markdown wrapped in `<page>...<content>...</content>...</page>` tags. Extract the inner `<content>` block.

If a fetch fails (page deleted, access revoked, network error):

- Log the failure in the routine-issue comment (page id + error).
- Do NOT delete the existing mirror file — keep the last-known-good copy.
- Continue with the remaining pages.

### 3. Write the mirror file

For each successfully fetched page, write `docs/notion-mirror/<slug>.md` with the following structure:

```markdown
<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page <notion_id>
Title: <notion_title>
Mirrored: <ISO-8601 UTC timestamp>Z by Documentation-KM (QUA-151)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
-->

# <notion_title>

<inner Notion content as fetched>
```

Convert obvious Notion-flavored constructs to clean Markdown where straightforward (tables, code blocks). Leave embedded `<page url=...>` references as-is — they are stable Notion URLs.

### 4. Diff check

Run `git status -- docs/notion-mirror/` (or the equivalent via the shell). If no files changed:

- Comment on the routine-issue with `no-diff: nothing to commit`.
- Close the issue. Do not commit.

If files changed, proceed to commit.

### 5. Commit

Stage only `docs/notion-mirror/` and commit with the BASIS-mandated message:

```
docs: nightly Notion sync YYYY-MM-DD
```

Where YYYY-MM-DD is today's UTC date.

### 6. Comment on the routine-issue

Post a comment with:

- the commit hash
- the list of pages that changed (slugs)
- any per-page fetch failures from step 2
- a closing line: `closing routine-issue; next fire 23:00 UTC tomorrow`

Then close the routine-issue.

## Boundaries (BASIS § DO NOT)

- NEVER push files outside `docs/notion-mirror/` (no overwriting `docs/ops/`, `lessons-learned/`, `processes/`, `paperclip-prompts/`).
- NEVER sync `paperclip-prompts/*` back to Notion. They are Git-canonical.
- NEVER auto-publish (no website push, no YouTube, no newsletter — those need OWNER sign-off via separate processes).
- NEVER delete a Notion page. If a manifest page goes missing, mark it stale in a follow-up issue and ask CEO/OWNER to confirm retirement.
- NEVER embed credentials, RDP details, account IDs, or other private fields in the mirror. The pages in the manifest are already public-safe by design; if a future page contains private content, do not add it to the manifest without redaction logic.

## On adding/retiring pages

- **Add:** OWNER or CEO appends an entry to `manifest.yaml` with `direction: notion-to-mirror`. The next nightly run picks it up automatically.
- **Retire:** set the entry's `direction: skip` and add a `retired_at: YYYY-MM-DD` key. Do not delete the entry — keep the audit trail of what was once mirrored.

## Failure modes and recovery

| Failure | Detection | Recovery |
|---|---|---|
| Notion read fails for one page | MCP fetch returns error | Log in routine-issue comment, leave existing mirror file intact, continue |
| Notion read fails for all pages | All MCP fetches error | Mark routine-issue blocked with reason "Notion access broken"; assign blocker to OWNER. Do not commit. |
| Git commit fails | non-zero exit from git | Log full git output in routine-issue, mark issue blocked with reason "Git commit broken"; assign blocker to DevOps |
| Routine doesn't fire at 23:00 UTC | DevOps is the cron-health reviewer per CEO 2026-04-27 § scheduler | DevOps inspects `paperclip/routines/` state on the Paperclip side and Documentation-KM heartbeat logs |
| Mirror file accidentally edited by hand | `git diff` against the mirror at next sync diverges from a fresh Notion fetch | Next sync overwrites the hand-edit (intended); the prior commit history preserves the lost work for review |

## Phase 1 acceptance link

Per CEO 2026-04-27 (QUA-151 comment `2e2f2b1f`), the first real (non-empty) `docs: nightly Notion sync YYYY-MM-DD` commit closes Phase 1 acceptance gate condition #3 on QUA-144. The manual one-shot in commit referenced from the QUA-151 close comment counts as that first commit.
