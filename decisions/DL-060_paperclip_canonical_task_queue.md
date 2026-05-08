---
name: DL-060 — Paperclip API is the canonical task queue; CSV deprecated as task source
description: Resolves QUA-853 dual-inbox problem. Paperclip issues become the single source of truth for agent task assignment. CSV `company_kanban.csv` is frozen as a historical artifact, with done/killed rows archived monthly. `next_task.py` migrates from CSV pull to API pull. `sync_to_paperclip.py` is retired; `sync_from_paperclip.py` becomes the read-only dashboard feeder.
type: decision-log
authority: CEO unilateral under DL-017 + DL-023 broadened-autonomy class 4 ("internal process choices — heartbeat cadence, issue-tree shape, agent-vs-agent escalation rules"). Not a strategic-direction change; not a budget step-change; not a V5 hard-rule boundary touch.
date: 2026-05-08
supersedes: portion of QUA-726 (the kanban-CSV-as-canonical scaffold). QUA-726's *queue-hygiene-sweep* discipline survives — only the storage substrate changes.
related: DL-031 (issue routing + projectId), DL-053 (CEO operating contract — phase-state-first heartbeat), DL-058 (no-recovery for state drift), QUA-726, QUA-853.
---

## The decision (binding for all agents)

**Effective 2026-05-08, the Paperclip Issues API is the canonical task queue for all agents.**

1. **Agents pull next task from Paperclip, not CSV.** `next_task.py` is rewritten to query `GET /api/issues?assigneeAgentId=…&status=todo,in_progress&projectId=…`, sort by priority + age, and return the top item. The CSV-pull code path is removed in the same PR.
2. **The CSV file is frozen as a historical artifact.** No new task rows are written to `company_kanban.csv`. Existing rows remain (read-only audit) but are not the source of truth.
3. **Done/killed rows are archived.** A new `archive_kanban.py` moves rows with status in {`done`, `killed`} to `kanban/archives/company_kanban_archive_YYYY-MM.csv` (append-only) and removes them from the active file. Run once at adoption (clears 43 of 89 rows = 48% noise) and then monthly via routine.
4. **`sync_to_paperclip.py` is retired** — no more CSV → API issue creation. Agents and the board author Paperclip issues directly (already the dominant pattern; 10 CEO Paperclip issues in_progress with no CSV counterpart as of 2026-05-08).
5. **`sync_from_paperclip.py` is repurposed** — it now rebuilds a read-only `kanban/dashboard_view.csv` from the API solely to feed `render_dashboard.py`. The active `company_kanban.csv` is no longer mutated by sync.
6. **`mark_done.py` / `block_task.py` / `unblock_task.py` migrate to API-direct.** They become thin wrappers around `PATCH /api/issues/{id}` rather than CSV editors.
7. **The `paperclip_issue_id` join column is the migration spine.** During the cutover, any kanban row with a non-empty `paperclip_issue_id` is treated as already-tracked-in-Paperclip; rows without one are migrated by `migrate_csv_to_paperclip.py` (one-shot script) or, if status is queued and stale (>14d), bulk-killed.

## Why this and not the alternative

The board's QUA-853 framing offered two options: (a) Paperclip canonical, (b) CSV canonical with auto-sync. We chose (a) for these reasons:

- **Reality on the ground.** The board, OWNER, and most agents already author Paperclip issues directly. The CSV → API sync handles only a fraction of created work. Fighting this with a more-aggressive CSV-first sync just adds dual-write bug surface.
- **Paperclip is richer.** Comments, interactions (`request_confirmation`, `suggest_tasks`), `blockedByIssueIds`, executionPolicy (DL-030), checkout/wake handshake — none of these have CSV equivalents and all are load-bearing in current workflows.
- **Single source of truth eliminates a class of bugs.** The 10-CEO-issues-with-no-CSV-counterpart drift is a symptom of dual-write divergence. The DL-058 state-drift problem and the DL-046 churn-issue problem both get worse when there are two queues to keep in sync.
- **The reason the kanban existed (QUA-726) is solved differently.** QUA-726 cited "700+ flat QUA-issues with recovery cascades made the queue unreadable." Readability is restored not by a parallel CSV but by (i) DL-031 project routing, (ii) DL-058 no-recovery-for-drift, (iii) the QUA-726 three-loop hygiene sweep itself (which survives — it just runs against the API now), and (iv) per-assignee priority-ordered API queries with status filters.
- **Determinism-first.** Task state in one place, with one mutation primitive (`PATCH /api/issues/{id}`), is more deterministic than two stores plus a sync. The CSV's ordering/dedup discipline can be reproduced as API query semantics.

## What survives unchanged

- **DL-031 issue routing** (projectId required at creation time).
- **DL-030 execution policies** (Class-1/2/3/4 attached at creation).
- **QUA-726 queue hygiene sweep** — the three-loop discipline (in_review triage, backlog dispatch, stale in_progress detection) runs every CEO heartbeat, just against API results instead of CSV rows.
- **R-046-6 / DL-058 drift-correction rule.**
- **The phase semantics from `governance/PHASE_STATE.md`.** Phase mapping is read from PHASE_STATE.md + project filters, not from the CSV `phase` column.
- **Audit trail.** `kanban/audit_log.jsonl` continues to capture state-transition events; it switches from CSV-mutation source to API-event source.

## Implementation deliverables (delegated to CTO via QUA-853 child)

D1 (fastest, highest value — land first):
- `tools/ops/archive_kanban.py` — moves done/killed rows to `kanban/archives/company_kanban_archive_2026-05.csv` (append-only). Initial run today clears the 48% noise.
- `render_dashboard.py` reads only the active file (no behavior change once D1 lands; verify).

D2 — `next_task.py` migration:
- New API-driven mode is default. `--source csv` flag preserved for one week as a safety net, then removed.
- Sorting: priority (P0 > P1 > P2 > P3 → critical > high > medium > low) → priority bucket → age (oldest first). Filter: `assigneeAgentId == agent` AND `status in {todo, in_progress, backlog}`.
- HEARTBEAT.md / AGENTS.md task-source contract block updated to reflect API canonical.

D3 — Sync tooling repurposing:
- `sync_to_paperclip.py` deleted (or moved to `tools/ops/_deprecated/`).
- `sync_from_paperclip.py` rewritten: reads API → writes `kanban/dashboard_view.csv` (read-only mirror, regenerated each run). No mutation of `company_kanban.csv`.
- `mark_done.py` / `block_task.py` / `unblock_task.py` switched to API-direct PATCH.

D4 — Migration sweep (one-shot):
- `migrate_csv_to_paperclip.py` — for each active CSV row without a `paperclip_issue_id`, either create the issue or mark the row killed (if older than 14d and no progress). Audit each decision to `kanban/audit_log.jsonl`.

D5 — Comms:
- Update `routines/routines.md`, `paperclip-prompts/*.md` task-source language, and any AGENTS.md references that point at `next_task.py --source csv`.
- Cancel routine that runs `sync_to_paperclip.py` (if any registered).

## Acceptance criteria

Measured 2026-05-15 (one week after adoption):

- `company_kanban.csv` has zero rows with status in {`done`, `killed`} (all archived).
- `next_task.py` defaults to API mode and is in active use by ≥3 agents (CEO, CTO, Pipeline-Op heartbeat traces show API hits).
- No `sync_to_paperclip.py` invocations in the prior 48h (cron + audit log).
- Dashboard (`render_dashboard.py`) renders from API-derived `dashboard_view.csv` and matches API ground truth on a spot check.
- Zero new tasks authored to CSV in the prior 48h.

If those five hold, DL-060 is working. If not, escalate to OWNER for revision.

## What this DL does NOT do

- Does NOT change the work itself — V5 phase progress, T1-T5 process+phase semantics, DL-054 anti-theater gates, DL-057 research resume gate all unchanged.
- Does NOT touch T6 / live-trade discipline.
- Does NOT remove the audit log. `kanban/audit_log.jsonl` continues to be append-only.
- Does NOT delete the historical CSV — frozen, not deleted. Agents and OWNER can still read it for archaeology.

## Authority basis

DL-017 (CEO broadened autonomy on operational + internal process choices) + DL-023 class 4 ("internal process choices — heartbeat cadence, issue-tree shape, sub-issue spawning patterns, agent-vs-agent escalation rules"). The CSV-vs-API choice is a substrate question for how agents discover their next task; that is internal process, not strategic direction. Per the agent prompt: "If uncertain whether something falls under broadened authority or surface to OWNER, **act**, then retroactively raise via DL-NNN if the call needs ratification" — this DL is the retroactive raise.

## Receipts

- 2026-05-08T13:18:31.944Z: Board (`local-board`) authored QUA-853 with the framing of two options + archival mandate.
- 2026-05-08T~14:30Z: CEO chose option (a) and authored this DL.
- 2026-05-08T~14:35Z: CEO commented on QUA-853 with decision + link to this DL.
- 2026-05-08T~14:40Z: CEO created child issue assigned to CTO with deliverables D1–D5.
- TODO: CTO ships D1 (archival) by 2026-05-09 EOD.
- TODO: CTO ships D2–D5 by 2026-05-12 EOD.
- TODO: Doc-KM mirrors this DL into the paperclip log + REGISTRY.md.
