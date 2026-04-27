# QUA-151 — Nightly Notion → Git Export: Verification Report

> **Issue:** QUA-151 [Docs-KM #2] Verify nightly export script (Notion → Git docs/)
> **Author:** Documentation-KM agent (`8c85f83f`)
> **Date:** 2026-04-27
> **Status:** Verification complete; execution **blocked on CEO/OWNER policy decision** (see § Open Questions).

## TL;DR

- **No nightly export script exists** in the repo. `infra/backup.ps1` references `C:\QM\notion-exports\` as a backup source, but that directory does not exist and nothing populates it.
- **Prerequisite issue QUA-150** ("Configure Notion API access + Git write creds") is still `in_progress` with no comments.
- **Documentation-KM does have working Notion read access** via the `mcp__claude_ai_Notion__*` MCP tools (confirmed by fetching the V5 hub page id `34947da58f4a81acac28fb82f3d7e7aa`). That covers the Notion side of QUA-150 implicitly. Git write access is the agent's `claude_local` cwd `C:\QM\repo` and is also confirmed working (this very commit).
- **Cannot run a one-shot manual export this heartbeat** — not because of access, but because the BASIS instruction `Notion → docs/` collides with the `CLAUDE.md` source-of-truth order ("filesystem wins; Notion only when local docs are missing"). Running it naively would overwrite Git-canonical files. Need policy decision before any sync executes.

## Step 1 — Locate existing script

Searched:

- `C:\QM\repo\scripts\` → `aggregator/`, `export_public_snapshot.ps1`, `README.md`. No Notion sync.
- `C:\QM\repo\infra\scripts\` → 50+ scripts, all QUA-9x / DWX / verifier-related. No Notion sync.
- `C:\QM\paperclip\routines\routines.md` → only `QM_DWX_HourlyCheck` and `Import_DWX_Queue_Service` are active. No Notion sync routine.
- `grep -ri notion **/*.{ps1,py,sh}` → only matches are `infra/backup.ps1` (treats `C:\QM\notion-exports\` as a backup source) and `infra/monitoring/Test-BackupSmoke.ps1` (asserts the same path). Neither generates the export.

**Conclusion:** No script exists. The backup integration anticipated one but it was never authored.

## Step 2 — Run a one-shot manual export

**Cannot run this step yet.** Two blockers:

### Blocker A — Direction-of-truth tension

`paperclip-prompts/documentation-km.md` § SYNC TO GIT says:

> Nightly at 23:00 UTC: Export Project Charter, Pipeline Design, Research Methodology, Learnings Archive, Episode Guide, Process Roadmap, and Agent Skill Matrix from Notion. Commit to v5-portfolio-build/docs/ with message "docs: nightly Notion sync YYYY-MM-DD".

`CLAUDE.md` § Source Of Truth Order says:

> 1. Actual filesystem state on this VPS
> ...
> 5. Notion references only when local docs are missing
> If filesystem state conflicts with notes, trust the filesystem and report the inconsistency.

All seven BASIS-named pages **already exist locally** (or as a topic under `processes/`):

| BASIS page name           | Notion id                              | Local path                                              | Local edits since migration?                          |
|---------------------------|----------------------------------------|---------------------------------------------------------|-------------------------------------------------------|
| Project Charter           | `34947da58f4a81a29de5c04561b50eba`     | `docs/ops/PROJECT_CHARTER.md`                           | possibly (file dated 2026-04-26)                      |
| Pipeline Design           | `34947da58f4a8192bbebc65eaacb0949`     | `docs/ops/PIPELINE_PHASE_SPEC.md` (V2.1 rewrite)        | **YES — Git-canonical per memory + DL-2026-04-25**    |
| Research Methodology      | `34947da58f4a81d3acf3e1e0d6074d4a`     | `docs/ops/RESEARCH_METHODOLOGY_V2.md`                   | possibly                                              |
| Learnings Archive         | `34947da58f4a8136a6a8ee48fe47fc7d`     | `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` (+ post-2026-04-26 entries) | **YES — actively appended** |
| Episode Guide             | `34947da58f4a81688ca7ff3e1097b8d4`     | `docs/ops/EPISODE_GUIDE.md`                             | possibly                                              |
| Process Roadmap           | `34947da58f4a81c28045ebec3ad6d78a`     | `docs/ops/PAPERCLIP_OPERATING_SYSTEM.md` + `processes/` | **YES — `processes/` is Git-authored**                |
| Agent Skill Matrix        | (not directly in hub list)             | `docs/ops/AGENT_SKILL_MATRIX.md`                        | possibly                                              |

A blind `Notion → docs/` overwrite would clobber locally-authored content (most concretely: the V2.1 pipeline rewrite from 2026-04-25, the post-migration learnings entries, and the `processes/` registry).

### Blocker B — Scheduler ownership unclear

BASIS says "Nightly at 23:00 UTC" but does not say *which* scheduler. Two options:

1. **Windows Task Scheduler** (DevOps territory per `paperclip/routines/routines.md` § "Cron-side jobs"). Requires a stand-alone script callable by `Task Scheduler` with stored Notion API token + Git credentials.
2. **Paperclip routine** that fires Documentation-KM with a "do nightly export" prompt at 23:00 UTC. The agent does the work via its own MCP access — no separately-stored Notion token, no separate Git credential. This matches the heartbeat-driven pattern of the rest of the company.

The Paperclip routine option is *significantly* simpler operationally: no extra credential storage, no separate failure mode, and re-uses the agent's existing MCP/Git access. The Windows Task option is the more conventional "cron job" approach and is what the BASIS phrasing implies.

## Step 3 — Recommendation if script doesn't exist

### Proposed design (pending CEO/OWNER policy decision)

1. **Export to `docs/notion-mirror/<page-slug>.md`, NOT `docs/ops/`.** Treat the mirror directory as a read-only public-facing snapshot. Files in `docs/ops/`, `lessons-learned/`, `processes/`, and `paperclip-prompts/` remain Git-canonical and are never overwritten by the sync.
2. **Manifest-driven page list** at `infra/notion-sync/manifest.yaml` listing the 7 (or N) page IDs + their target slug + a `direction` field. Initial values: all 7 pages are `notion-to-mirror` (one-way snapshot). The script never reads `direction: git-to-notion` until that policy is explicitly decided.
3. **Implementation via Paperclip routine** (recommended): a daily routine fires Documentation-KM at 23:00 UTC with prompt "Run nightly Notion-to-Git mirror sync per `docs/ops/QUA-151_NIGHTLY_EXPORT_VERIFICATION.md`". The agent fetches each manifest page via `mcp__claude_ai_Notion__notion-fetch`, writes Markdown into `docs/notion-mirror/`, and commits with the BASIS-mandated message format. Skip-if-noop: if no manifest page changed, no commit.
4. **Alert-on-stall** at 24h: Observability-SRE (when active) or `infra/backup.ps1`-equivalent monitor verifies the nightly commit landed.

### Child-issue handoff (only after policy is set)

- **DevOps child issue:** if option (1) Windows Task Scheduler is chosen, DevOps owns: (a) Task Scheduler entry creation, (b) Notion integration token storage in a non-committed credential file, (c) PowerShell script that the task invokes. Skip if option (2) Paperclip routine is chosen — that's CEO/Docs-KM territory.
- **Docs-KM follow-up:** author the manifest + the actual mirror logic, regardless of scheduler choice.

## Open Questions for CEO + OWNER

1. **Direction-of-truth per page**: Do you confirm the proposed `notion-to-mirror` model (separate `docs/notion-mirror/` directory, never overwriting Git-canonical files), or do you want a different reconciliation between BASIS and `CLAUDE.md`?
2. **Scheduler choice**: Paperclip routine (recommended, simpler) or Windows Task Scheduler (BASIS-literal phrasing)?
3. **Process Roadmap mapping**: The BASIS lists "Process Roadmap" but no single Notion page carries that name in the V5 hub. Closest matches are `Paperclip Company Operating System & Process Roadmap` (Notion `34947da58f4a81c28045ebec3ad6d78a`) and the local `processes/` registry. Confirm which Notion page maps.
4. **Agent Skill Matrix mapping**: Local file exists (`docs/ops/AGENT_SKILL_MATRIX.md`) but no matching Notion page surfaced in the V5 hub. Was it migrated to Git only? If so, mark it `git-canonical` and skip from the sync.

Once these four are answered, Documentation-KM can author the manifest, draft the script (or routine), run a one-shot export, and complete QUA-151.

## Evidence

- Search results: see § Step 1 above.
- Notion read confirmed: V5 hub page `34947da58f4a81acac28fb82f3d7e7aa` retrieved 2026-04-27 by this agent via MCP.
- `C:\QM\notion-exports\` directory absence: `ls` returned `no notion-exports dir`.
- QUA-150 status: `in_progress`, 0 comments (queried via `/api/issues/f88079aa-af50-488e-b2af-d1ed9bf4a04d/comments`).

## Boundary reaffirmations

- Will NEVER sync agent prompts (`paperclip-prompts/*.md`) back to Notion — Git-canonical.
- Will NEVER auto-publish.
- Will NEVER delete Notion pages — archive with date prefix.
- Will respect Drive-sync vs `.git/` separation (PC1-00).
