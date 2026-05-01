# PHASE_STATE.md → Notion mirror — plan (gated)

> **Status:** PLAN. Direction-policy delta requires CEO ratification before first sync.
> **Authority basis:** [DL-053](../../decisions/DL-053_ceo_operating_contract.md) R-053-1 (CEO operating contract); [QUA-681](/QUA/issues/QUA-681) D1a (Doc-KM owns Notion mirror).
> **Owner:** Documentation-KM. Notion-write authority via the existing Doc-KM MCP credentials.
> **Schema source-of-truth:** [`processes/20-phase-state-maintenance.md`](../../processes/20-phase-state-maintenance.md).

## Why this needs ratification

The existing `infra/notion-sync/manifest.yaml` documents a **one-way Notion → Git mirror policy**, set by CEO on 2026-04-27 (QUA-151 comment `2e2f2b1f`). Public-facing snapshot pages live in Notion; the daily routine pulls them into `docs/notion-mirror/`. Nothing in the current model pushes Git state INTO Notion.

PHASE_STATE.md is the opposite direction: it is operational state authored on the VPS (in `C:/QM/paperclip/governance/`, alongside other paperclip operational state files), and the plan below would push a snapshot of it into Notion so OWNER and the board can see "where is the company right now in V5?" without VPS access.

That is a NEW direction on top of the 2026-04-27 policy. CEO needs to ratify before any push happens.

## Proposed direction (pending ratification)

| Field | Value |
|---|---|
| Direction | `git-snapshot-to-notion` (NEW) |
| Source | `C:/QM/paperclip/governance/PHASE_STATE.md` |
| Notion parent | `34947da58f4a81ac ac28fb82f3d7e7aa` ("QuantMechanica — VPS Portfolio Build V5") |
| Notion target | new sub-page `Live Phase Pointer (V5)` (page ID assigned on first creation, then frozen in this plan) |
| Update trigger | each CEO heartbeat that mutates the live file (commit-driven) **AND** every 4 h floor (so a heartbeat-skip surfaces in Notion) |
| Update method | Documentation-KM MCP `notion-update-page` overwrite of the page body with the current PHASE_STATE.md content, prefixed by `Mirrored: <ISO-8601 UTC>Z by Documentation-KM (QUA-681). Source-of-truth: paperclip/governance/PHASE_STATE.md on VPS.` |
| What does NOT mirror | the File History section (operational noise; available on the VPS for those who need it). |
| Snapshot trail | each push appends a one-line entry to `docs/notion-mirror/_phase_state_log.md` (`<ISO timestamp> <commit-hash-of-most-recent-relevant-commit-or-"unversioned"> <CEO short-id>`) so the mirror has an audit trail even though the live file isn't versioned. |
| Stale handling | if `scripts/check_phase_state_staleness.sh` returns `stale`, Doc-KM mirror tick still pushes (with a `STALE — last update <updated_utc>` banner at the top) AND files the Class-2 escalation per DL-053 R-053-1. Notion never silently shows fresh state when the live file is stale. |
| Failure | if Notion write fails, log to a `phase-state-mirror-fail-YYYY-MM-DDTHHZ` issue assigned to Doc-KM with `blocked` status; do NOT delete the existing Notion page. |
| Retire | direction policy reversal or page deletion requires a fresh ratification — same gate as the initial ratification. |

## Why NOT extend `manifest.yaml` directly

The existing manifest's data model is single-direction (`notion-to-mirror`). Adding a `git-to-notion` direction in the same file invites accidental cross-flow. Cleaner: keep this plan in its own file, and (on ratification) add a separate manifest section `git_snapshot_pages:` with its own runbook. The current manifest's `# Hard-prohibited` list still applies — `paperclip-prompts/*` never goes to Notion regardless of direction.

## Acceptance gate (this plan → live mirror)

1. CEO ratification — comment on QUA-681 either `accepted: PHASE_STATE.md → Notion mirror direction approved per this plan` or `rejected: <reason>` (or amends the plan inline).
2. On accepted: Doc-KM creates the Notion sub-page under the V5 hub, captures the page ID, freezes it into this file (replace the placeholder `Notion target` value above), pushes the first snapshot, and commits `infra/notion-sync/PHASE_STATE_MIRROR_PLAN.md` with the freezed ID + an updated `## Status` line (`PLAN` → `LIVE since YYYY-MM-DD`).
3. Manifest delta (also part of step 2): add a `git_snapshot_pages:` section to `manifest.yaml` referencing this plan, so future Notion sync runbooks see both directions in one place.
4. Stale-detector wiring: CEO heartbeat preflight is already documented in `processes/20-phase-state-maintenance.md`; no extra wiring needed at mirror go-live.

## What is NOT in this plan

- Embedding the Phase Map history table in the Notion mirror — out of scope; the Phase Map is in Notion already as part of the V5 hub design.
- Auto-publishing the Notion mirror externally (website, YouTube, newsletter) — those need OWNER sign-off via separate processes; PHASE_STATE.md is internal/board scope.
- Two-way sync (Notion edit pushed back to the live file) — explicitly disallowed; CEO heartbeat is the only write path to PHASE_STATE.md.

## File History

- 2026-05-01 — plan authored by Documentation-KM. Status: PLAN. Trigger: QUA-681 D1a.
