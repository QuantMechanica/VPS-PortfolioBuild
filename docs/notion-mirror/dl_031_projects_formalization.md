<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34f47da58f4a814b9df7f6e4f8e661d1
Title: DL-031 — Projects Formalization + Issue Routing Convention (Decision Log)
Mirrored: 2026-04-27T15:05:00Z by Documentation-KM (QUA-256)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
-->

# DL-031 — Projects Formalization + Issue Routing Convention (Decision Log)

> **Git-canonical mirror.** Source of truth: [`decisions/DL-031_projects_formalization_and_routing_convention.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/DL-031_projects_formalization_and_routing_convention.md). Authored by CEO under DL-023 broadened-authority waiver from OWNER directive 2026-04-27 ~15:00 local (relayed via Board Advisor). Recording issue: [QUA-254](https://paperclip.local/QUA/issues/QUA-254). Doc-KM mirror task: QUA-256. Last refresh: 2026-04-27.

## Status

**Active.**

## Decision

Adopt a 3-tier hierarchy for all V5 work: **Goal → Project → Issue**.

One top goal (`4662e91e-8e9b-458e-9383-b1f67751965b`, "Build-in-public quant research factory; portfolio of mechanical trading strategies") owns four projects. Every issue belongs to exactly one project.

| Project | id | Status | Color | Scope |
|---|---|---|---|---|
| **V5 Framework Implementation** | `71b6d994-70ba-4a28-bd62-732b42a9ea58` | in_progress | blue | MQL5 framework + pipeline runners + build/test harness; repo-only (`C:\QM\repo`) |
| **V5 Pipeline Operations** | `ac8daa03-00ae-49fd-bd4a-f1283a075f83` | in_progress | orange | T1-T5 factory: backtest runs, evidence, NO_REPORT, calibration, mirror integrity |
| **V5 Strategy Research** | `b2adcc7f-064f-47c7-8563-d1c917639231` | in_progress | purple | Source extraction + Strategy Card authoring per QUA-236 / DL-029 workflow |
| **T6 Live Operations** | `2603d13a-8152-4514-987c-d9abee1c948f` | backlog | red | DXZ live deploy of approved EAs; OWNER-gated (manifest + AutoTrading-OFF) |

T6 stays `backlog` deliberately — first live-deploy issue moves it to `in_progress` and triggers Approval-only execution policy per QUA-216 (when CEO configures).

## Routing convention (binding for all agents)

**Every new issue is created with `projectId` set.** Heuristic:

- Touches `framework/`, `infra/`, `paperclip-prompts/`, `decisions/`, `processes/`, `docs/`, `lessons-learned/`, `governance/`, agent prompt/instruction edits, learning-candidates → **V5 Framework Implementation**
- Touches `D:\QM\mt5\T1`-T5, `D:\QM\reports\pipeline\`, `D:\QM\reports\ops\`, calibration JSON, runner outputs, NO_REPORT debugging, .DWX symbol verification, silent-run / stale-lock recovery → **V5 Pipeline Operations**
- Touches `strategy-seeds/`, source extraction, Strategy Card authoring → **V5 Strategy Research**
- Touches `C:\QM\mt5\T6_Live`, deploy manifests, AutoTrading-OFF discipline → **T6 Live Operations** (OWNER-gated)

Cross-functional issues split: parent in primary project, children scoped to their owners' projects. If ambiguous, route to **V5 Framework Implementation** (the meta-default) and let the assignee re-route on triage.

## Why

OWNER wanted Goals/Projects/Issues formalized so the dashboard mirrors the operational reality: framework code, pipeline ops, research, and live deploy are distinct workstreams with distinct rules-of-engagement (e.g., T6 hard boundary, research's binding-sequential workflow per DL-029). Without formal projects, the Pipeline Operations workstream was sharing a flat issue list with framework refactors and learning-candidates — nothing to anchor execution policies, ownership, or filtered views.

## Authority basis

[DL-023](https://www.notion.so/34f47da58f4a81c79564c26244d745eb) § Broadened CEO authority class 4 (internal process choices → issue-tree shape) plus OWNER directive making the formalization itself.

## What changed

1. **Existing open issues rerouted** (49 issues across todo / in_progress / blocked / in_review):
   - V5 Framework Implementation: 29
   - V5 Pipeline Operations: 18
   - V5 Strategy Research: 2
   - T6 Live Operations: 0 (none in flight)
   - Done / cancelled issues left unrouted (cosmetic only, per task spec).
2. **Convention recorded** in [`processes/process_registry.md` § Issue Routing](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/processes/process_registry.md).
3. **CEO instructions** updated to require `projectId` on every issue creation going forward (`AGENTS.md` § Delegation, this DL).
4. **Per-project budget caps**: skipped per OWNER (QUA-210 batch-resolve). Field exists; can be set later.
5. **Per-project workspaces (`executionWorkspacePolicy`)**: skipped until a real concurrent-write conflict shows up that the per-agent worktree pattern (PC1-00 mitigation) does not solve.

## Implications

- **Agents** now see issues filtered/grouped by project in the UI; assignees pick up work with project context already set.
- **CEO** has unilateral authority on project routing under DL-023 (operational decision class).
- **Doc-KM** mirrors the project structure to Notion via `infra/notion-sync/` so the public-facing Doc-KM mirror reflects the same hierarchy. See [V5 Projects Hierarchy](https://www.notion.so/34f47da58f4a81649744ff5aa2046426).
- **Projects are organizational scaffolding, not execution constraints.** Agents act on issues regardless of project; the project field is for reporting, filtering, and future per-project policy attachment (T6 approval gate, budgets).

## Boundary

- T6 routing changes nothing about the T6 hard rule ([DL-025](https://www.notion.so/34f47da58f4a810fad87cacf506238b8)). All T6 issues still require OWNER manifest + AutoTrading-OFF discipline; the project just gives them a home.
- No retro-routing of done/cancelled issues. Cosmetic only.

## Cross-links

- **Recording task:** [QUA-254](https://paperclip.local/QUA/issues/QUA-254) — CEO reroute + convention task.
- **Doc-KM mirror task:** QUA-256 (this Notion mirror).
- **Source directive:** OWNER 2026-04-27 ~15:00 local (relayed via Board Advisor).
- **Authority basis:** [DL-023](https://www.notion.so/34f47da58f4a81c79564c26244d745eb) (CEO broadened-authority waiver).
- [**DL-025**](https://www.notion.so/34f47da58f4a810fad87cacf506238b8) (T6 boundary) carries forward unchanged.
- [**DL-029**](https://www.notion.so/34f47da58f4a81819b0dd9614646db81) (Strategy Research workflow) maps cleanly onto the new V5 Strategy Research project.
- QUA-216 (Approval-only execution policy) attaches to T6 project when CEO configures.
- **Project structure mirror:** [V5 Projects Hierarchy](https://www.notion.so/34f47da58f4a81649744ff5aa2046426).
- **Registry:** [`decisions/REGISTRY.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/REGISTRY.md) — DL-031 row.
- **Process doc:** [`processes/process_registry.md` § "Issue Routing"](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/processes/process_registry.md).

---

For the full canonical record (frontmatter + scope + recorder's note + complete cross-link block), see the Git source: [`decisions/DL-031_projects_formalization_and_routing_convention.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/DL-031_projects_formalization_and_routing_convention.md). This Notion page is auto-mirrored from Git on the Doc-KM nightly sync — edits made here are not persisted upstream.

— OWNER directive via Board Advisor, 2026-04-27 ~15:00 local. Recorded by CEO 2026-04-27.
