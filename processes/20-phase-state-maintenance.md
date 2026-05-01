---
title: PHASE_STATE.md Maintenance Contract
owner: Documentation-KM
last-updated: 2026-05-01
---

# 20 — PHASE_STATE.md Maintenance Contract

Doc-KM owns the file `paperclip/governance/PHASE_STATE.md`; CEO owns the live entry inside it. This process names the schema, the update protocol, the staleness gate, and the Notion mirror policy so neither role has to re-derive them.

> Authority: [DL-053](../decisions/DL-053_ceo_operating_contract.md) (CEO operating contract — R-053-1 names PHASE_STATE.md and the > 6 h staleness rule). Issue trail: [QUA-677](../docs/ops/) D1 (CEO authored the live file) → QUA-681 D1a (Doc-KM owns schema + stale detector + Notion mirror).

## File location and source-of-truth

| Surface | Path | Versioning | Edit authority |
|---|---|---|---|
| Live file | `C:/QM/paperclip/governance/PHASE_STATE.md` | unversioned (paperclip operational state, alongside `decision_log.md`, `org_chart.md`, `risk_register.md`, `skill_matrix.md`) | CEO heartbeat updates the Live Entry; Doc-KM owns surrounding sections + schema conformance |
| Schema (this file) | `processes/20-phase-state-maintenance.md` | Git-canonical | Documentation-KM |
| Stale detector | `scripts/check_phase_state_staleness.sh` | Git-canonical | Documentation-KM (with DevOps reviewing scheduler wiring) |
| Notion mirror plan | `infra/notion-sync/PHASE_STATE_MIRROR_PLAN.md` | Git-canonical | Documentation-KM (proposed; CEO/OWNER ratification gate per `PHASE_STATE_MIRROR_PLAN.md`) |

The live file is unversioned by design — it is operational state, not a published artefact. History is reconstructable from CEO heartbeat commit messages and the Notion mirror snapshot trail (once the mirror is live).

## Schema

The live file MUST contain three top-level sections in the order below. Stale-detector and Notion-mirror tooling parses those headings; renaming a heading without updating this contract is a schema break.

### Required section: Live Entry

Format: a single Markdown table with two columns (`Field` / `Value`) and the rows below in this order. Field names are exact-match identifiers; the values column is human-prose unless flagged otherwise.

| Field | Type | Required | Validation rule |
|---|---|---|---|
| `Updated (UTC)` | ISO-8601 instant `YYYY-MM-DDTHH:MMZ` (or `YYYY-MM-DDTHH:MM:SSZ`) | yes | `now() − Updated (UTC) ≤ 6 h` (R-053-1). Stale detector parses this row. |
| `Updated by` | role + agent ID short-form (e.g. `CEO 7795b4b0`) | yes | Identifies who claimed the heartbeat. |
| `Current phase` | string of form `Phase <N> — <Name>` matching the canonical phase map below (or `Phase Final — Founder-Comms / CoS`) | yes | Must be one of the rows in the Phase Map section. |
| `Closure criterion` | one-line plain English; concrete file path / state preferred | yes | Mirrors the matching row in the Phase Map. |
| `Current blocker` | one or more bulleted blockers; each MUST cite an upstream `QUA-NNN` ticket and a one-line reason | yes (use `(none — phase ready to close)` if literally nothing blocks) | Empty / vague blocker = DL-046 violation. |
| `Delegation target` | named agent ID(s) + role(s) + the action being delegated, per blocker | yes | If a blocker has no delegation, name `OWNER` and the escalation action instead. |
| `ETA` | absolute UTC date (`YYYY-MM-DD`) or `YYYY-MM-DD HH:MM UTC` | yes | Relative dates (`tomorrow`, `Thursday`) NOT permitted — stale-detector cannot reason about them. |
| `Parallel lanes` | optional bulleted lines; each names an in-flight non-critical-path issue + assignee + status | optional | Phase 6 (Public Dashboard) parallel-eligible from Phase 3 onward — surface here when active. |

### Required section: Phase Map (canonical, YYYY-MM-DD)

Format: a Markdown table with columns `#`, `Name`, `Status`, `Closure criterion`. The CURRENT phase row is bolded. The canonical phase set is defined in [QUA-677](../docs/ops/) parent description and re-stated here:

| # | Name | Closure criterion |
|---|------|-------------------|
| 0 | Foundation | T1-T6 isolation proof + DST validation evidence |
| 1 | Paperclip Bootstrap | Wave 0 hired + heartbeats |
| 2 | V5 Framework | Step 25 PASS + ADR |
| 3 | First V5 EA Through Pipeline | QM5_1003 baseline `report.csv` + G1 verdict on first card |
| 4 | V5 Portfolio Build | 5+ EAs through P0..P8 + first basket |
| 5 | Live Deployment on T6 | First V5 sleeve live 7 days, no rollback |
| 6 | Public Dashboard | Hourly snapshot stable 72 h |
| Final | Founder-Comms / CoS | OWNER says "now build" + 6 preconditions per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md` |

CEO does not skip, reorder, or fork phases. Phase 6 may run parallel from Phase 3 onward. Phase Final stays deferred — do not pull forward.

### Required section: File History

Append-only list of significant edits (file creation, schema changes, retroactive corrections). One bullet per edit, ISO timestamp + author + one-line trigger. Heartbeat refreshes of the Live Entry do NOT need a File History entry — only structural changes.

## Update protocol

### CEO heartbeat (every heartbeat — R-053-1)

1. Open `C:/QM/paperclip/governance/PHASE_STATE.md`.
2. Verify `Updated (UTC)` is current to your heartbeat. If you are not changing any other Live Entry field this heartbeat, still bump `Updated (UTC)` to `now()`.
3. If any field changed (blocker resolved, delegation reassigned, ETA slipped), edit it in place. Do NOT add a comment-history block — that lives in the issue thread, not here.
4. If the current phase closed, move the closing row in the Phase Map to `**CLOSED** YYYY-MM-DD (DL-XXX / QUA-NNN)`, bold the next phase, reset Live Entry to the next phase's blocker.
5. Add a one-liner to File History only on structural changes.

### Doc-KM (on demand and on Notion-mirror tick)

- Validate schema conformance (field names, ISO timestamp format, blocker citation present, ETA absolute).
- Run `scripts/check_phase_state_staleness.sh` to confirm freshness (or rely on the scheduled fire — see § Staleness gate).
- Mirror to Notion per `infra/notion-sync/PHASE_STATE_MIRROR_PLAN.md` (once ratified).
- Maintain THIS file when the schema needs to evolve.

## Staleness gate

Per [DL-053](../decisions/DL-053_ceo_operating_contract.md) R-053-1: `Updated (UTC)` older than 6 h triggers a Class-2 escalation per [12-board-escalation.md](12-board-escalation.md).

**"Class-2" mapping clarification.** DL-053 R-053-1 says "Class-2 escalation per processes/12-board-escalation.md". Process 12's existing Class 2 is *CEO ↔ CTO second-round disagreement*, which does not fit a stale-PHASE_STATE incident. The intent of DL-053 is "moderate severity, OWNER pinged via Paperclip approval channel, not Sev-0 direct ping". This contract treats stale PHASE_STATE.md as a NEW class to be added to process 12 in a follow-up edit (Doc-KM, gated on this file landing). Until that follow-up lands, the stale detector raises a `paperclip request_board_approval` on the still-stale PHASE_STATE issue thread (or on a fresh `phase-state-stale-YYYY-MM-DDTHHZ` issue if no thread is open) — matching process 12's Channel for non-Sev-0 escalations.

The detector script (`scripts/check_phase_state_staleness.sh`) emits a machine-readable JSON status block that downstream tooling (cron, CEO heartbeat preflight, Notion-mirror tick) can parse. See the script's header comment for exit codes and JSON shape.

### Wiring options

- **CEO heartbeat preflight** (recommended initial wiring): CEO runs the detector at the start of every heartbeat. If stale, CEO self-files the escalation issue and addresses it BEFORE picking a phase-3 deliverable. Lowest infrastructure footprint.
- **Paperclip routine** (later, gated on routine slot availability): a hourly routine assigned to Doc-KM runs the detector and files the escalation issue if stale. Doc-KM closes the issue once CEO updates the file. This decouples freshness enforcement from CEO discipline.

Initial wiring: CEO preflight only. Routine wiring is a Doc-KM follow-up issue (NOT this heartbeat) — needs CEO + DevOps sign-off so the routine doesn't double-fire on already-stale state during a CEO outage.

## Notion mirror

See [`infra/notion-sync/PHASE_STATE_MIRROR_PLAN.md`](../infra/notion-sync/PHASE_STATE_MIRROR_PLAN.md). The mirror is a **NEW direction** (Git operational state → Notion) on top of the existing one-way Notion → Git mirror policy (CEO 2026-04-27, QUA-151 comment `2e2f2b1f`). Direction-policy delta requires CEO ratification before the first sync; plan is documented and gated.

## Boundaries

- Doc-KM does NOT edit the Live Entry — only the structural surroundings (schema, headings, File History, mirror).
- CEO does NOT relocate the live file out of `C:/QM/paperclip/governance/` without a DL update — moving it would invalidate every reference in DL-053, this process, the detector script, and the mirror plan.
- Neither role auto-publishes the Notion mirror externally (no website / YouTube / newsletter — those need OWNER sign-off via separate processes).

## File History

- 2026-05-01 — process authored by Documentation-KM. Trigger: QUA-681 D1a (Doc-KM owns PHASE_STATE.md schema + stale detector + Notion mirror).
