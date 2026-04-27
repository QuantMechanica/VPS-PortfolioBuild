<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34f47da58f4a81649744ff5aa2046426
Title: V5 Projects Hierarchy
Mirrored: 2026-04-27T15:05:00Z by Documentation-KM (QUA-256)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
-->

# V5 Projects Hierarchy

> **Git-canonical mirror.** Source of truth: [`processes/process_registry.md` § Issue Routing](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/processes/process_registry.md) + [`decisions/DL-031_projects_formalization_and_routing_convention.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/DL-031_projects_formalization_and_routing_convention.md). Established 2026-04-27 under DL-031 (CEO authority basis: DL-023). Recording task: [QUA-254](https://paperclip.local/QUA/issues/QUA-254). Doc-KM mirror task: QUA-256. Last refresh: 2026-04-27.

## Why

V5 work is shaped as **Goal → Project → Issue**. Per OWNER directive 2026-04-27 (relayed via Board Advisor) and recorded as DL-031, the 4 V5 projects below carry distinct rules-of-engagement (e.g., T6 hard boundary, Strategy Research's binding-sequential workflow per DL-029). Without formal projects, the Pipeline Operations workstream was sharing a flat issue list with framework refactors and learning-candidates — nothing to anchor execution policies, ownership, or filtered views.

## Top Goal

**Build-in-public quant research factory; portfolio of mechanical trading strategies**

- id: `4662e91e-8e9b-458e-9383-b1f67751965b`
- All 4 V5 projects roll up to this goal.

## V5 Projects (4)

| Project | id | Status | Color | Scope |
|---|---|---|---|---|
| **V5 Framework Implementation** | `71b6d994-70ba-4a28-bd62-732b42a9ea58` | in_progress | blue | MQL5 framework + pipeline runners + build/test harness; repo-only (`C:\QM\repo`) |
| **V5 Pipeline Operations** | `ac8daa03-00ae-49fd-bd4a-f1283a075f83` | in_progress | orange | T1-T5 factory: backtest runs, evidence, NO_REPORT, calibration, mirror integrity |
| **V5 Strategy Research** | `b2adcc7f-064f-47c7-8563-d1c917639231` | in_progress | purple | Source extraction + Strategy Card authoring per [DL-029](https://www.notion.so/34f47da58f4a81819b0dd9614646db81) |
| **T6 Live Operations** | `2603d13a-8152-4514-987c-d9abee1c948f` | backlog | red | DXZ live deploy of approved EAs; OWNER-gated (manifest + AutoTrading-OFF per [DL-025](https://www.notion.so/34f47da58f4a810fad87cacf506238b8)) |

T6 stays `backlog` deliberately — first live-deploy issue moves it to `in_progress` and triggers Approval-only execution policy per [DL-030](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/2026-04-27_execution_policies_v1.md) when CEO configures.

## Routing Convention (binding for all agents)

**Every new issue is created with `projectId` set.** Routing heuristic — pick the project whose path the issue's deliverable touches:

- `framework/`, `infra/`, `paperclip-prompts/`, `decisions/`, `processes/`, `docs/`, `lessons-learned/`, `governance/`, agent prompt/instruction edits, learning-candidates → **V5 Framework Implementation**
- `D:\QM\mt5\T1`-T5, `D:\QM\reports\pipeline\`, `D:\QM\reports\ops\`, calibration JSON, runner outputs, NO_REPORT debugging, .DWX symbol verification, silent-run / stale-lock recovery → **V5 Pipeline Operations**
- `strategy-seeds/`, source extraction, Strategy Card authoring → **V5 Strategy Research**
- `C:\QM\mt5\T6_Live`, deploy manifests, AutoTrading-OFF discipline → **T6 Live Operations** (OWNER-gated)

Cross-functional issues split: parent in primary project, children scoped to their owners' projects. If genuinely ambiguous, route to **V5 Framework Implementation** as meta-default and let the assignee re-route on triage. CEO has unilateral authority on project routing under [DL-023](https://www.notion.so/34f47da58f4a81c79564c26244d745eb).

## Initial reroute snapshot (2026-04-27)

CEO rerouted 49 open issues across todo / in_progress / blocked / in_review:

- V5 Framework Implementation: 29
- V5 Pipeline Operations: 18
- V5 Strategy Research: 2
- T6 Live Operations: 0 (none in flight)

Done / cancelled issues left unrouted (cosmetic only).

## Implications

- **Agents** see issues filtered/grouped by project in the dashboard; assignees pick up work with project context already set.
- **Projects are organizational scaffolding, not execution constraints.** Agents act on issues regardless of project; the project field is for reporting, filtering, and future per-project policy attachment (T6 approval gate, budgets).
- **Doc-KM** mirrors the project structure here so the public-facing Notion mirror reflects the same hierarchy as the Paperclip control plane.

## Cross-links

- [**DL-031**](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/DL-031_projects_formalization_and_routing_convention.md) — canonical decision record.
- [**DL-023**](https://www.notion.so/34f47da58f4a81c79564c26244d745eb) — CEO broadened-authority waiver (authority basis for DL-031).
- [**DL-025**](https://www.notion.so/34f47da58f4a810fad87cacf506238b8) — T6 hard boundary (carries forward unchanged).
- [**DL-029**](https://www.notion.so/34f47da58f4a81819b0dd9614646db81) — Strategy Research Workflow (maps to V5 Strategy Research project).
- **Recording task:** [QUA-254](https://paperclip.local/QUA/issues/QUA-254) — CEO routing + convention.
- **Doc-KM mirror task:** QUA-256 (this).

---

For the full canonical record (frontmatter + scope + recorder's note + complete cross-link block), see the Git source: [`decisions/DL-031_projects_formalization_and_routing_convention.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/DL-031_projects_formalization_and_routing_convention.md). This Notion page is auto-mirrored from Git on the Doc-KM nightly sync — edits made here are not persisted upstream.
