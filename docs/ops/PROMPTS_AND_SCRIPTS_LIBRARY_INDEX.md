# Prompts & Scripts Library Index

> **V5 Source:** Notion `Prompts & Scripts Library` (id `34947da5-8f4a-81ae-9ee6-d97c1af42ed4`)
> **Migrated to repo:** 2026-04-26

**Purpose:** One consolidated home for every prompt, script, and config that runs on the VPS. The operational toolkit.

**Ownership model:**

- OWNER + Claude-Assistant (Board Member) author and version these
- Git repo is canonical once published (Notion is draft/active layer)
- Paperclip reads agent-prompt files from Git at spawn time

## Repo Locations (canonical for runtime)

| Item | Repo path | Notion source |
|---|---|---|
| Board Member CLAUDE.md | `CLAUDE.md` (repo root) | `Board Member CLAUDE.md` (id `34947da5-8f4a-8190-ad00-c22a77006fa4`) |
| 13 Agent System Prompts | `paperclip-prompts/<role>.md` | sub-pages under `Paperclip V2 Company Design` |
| VPS Folder Layout | `docs/ops/CLAUDE_VPS_ONBOARDING.md` (operational), `docs/ops/CANONICAL_LAPTOP_STATE_2026-04-25.md` (laptop reference) | `VPS Folder Layout & Deployment Map` (id `34947da5-8f4a-816d-8646-d76ed37d25ca`) |
| VPS Bootstrap PowerShell | `scripts/` (Wave 0 / DevOps-authored, not yet present) | `VPS Bootstrap PowerShell` (id `34947da5-8f4a-8189-b754-cc444ae1caf5`) |
| Seed Data Assets & News Calendar Manifest | `seed_assets/news_calendar/MANIFEST.md` | `Seed Data Assets & News Calendar Manifest` (id `34947da5-8f4a-8187-abcf-d602f0c13607`) |
| Paperclip V2 Install & Company Creation | TBD `docs/ops/PAPERCLIP_V2_INSTALL.md` (Sweep 3 candidate) | `Paperclip V2 Install & Company Creation` (id `34947da5-8f4a-8100-911d-cca4bb5d6ea5`) |
| Episode Production Prompts | TBD `prompts/episodes/` (Wave 0 — Documentation-KM) | `Episode Production Prompts` (id `34947da5-8f4a-8187-a715-db60d9023f2e`) |
| Common Dispatch Templates | TBD `prompts/dispatch/` (Wave 0 — CEO) | `Common Dispatch Templates` (id `34947da5-8f4a-81fc-a195-d7e7b7584cba`) |

## Existing in `prompts/` (legacy bootstrap from 2026-04-24)

- `prompts/claude_paperclip_bootstrap_prompt.txt`
- `prompts/claude_symbol_dst_validation_prompt.txt`
- `prompts/claude_vps_bootstrap_prompt.txt`
- `prompts/claude_vps_deep_onboarding_prompt.txt`

These were the original Claude Code Board-Advisor onboarding prompts. Wave 0 may keep, revise, or supersede.

## Rules

- **All prompts in English** (build-in-public, public Git)
- **Every prompt has a version** (semver-like: v1.0, v1.1, v2.0 for breaking changes)
- **Changes logged** in commit history + decision log when material
- **Secret values never in prompts** — use placeholders like `{{DXZ_ACCOUNT_ID}}` that resolve from Paperclip secrets store or Windows env vars
- **Board Member reviews every prompt edit** before Git commit (until Wave 0 takes over Documentation-KM responsibility)

## Sub-page Stubs Pending Migration (Sweep 3 candidates)

These Notion pages exist as sub-pages and will need their own repo files when Wave 0 needs them:

- `VPS Bootstrap PowerShell` — Day-1 setup script for Windows Server 2022 post-install
- `Paperclip V2 Install & Company Creation` — Node install, daemon config, "QuantMechanica V5" creation, first 4 agents hired
- `Episode Production Prompts` — thumbnail briefs, show-notes templates, script prompts
- `Common Dispatch Templates` — reusable Paperclip issue templates for recurring work

Migration deferred to Sweep 3 because they are Wave-0 / Wave-1 first-issues, not Wave-0-blocking.
