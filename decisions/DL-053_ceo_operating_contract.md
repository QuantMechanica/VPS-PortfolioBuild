# DL-053 — CEO Operating Contract: Phase-Driven Heartbeat, Unblock Not Park

**Date:** 2026-05-01
**Originating issue:** [QUA-677](/QUA/issues/QUA-677) (OWNER directive — D4)
**Authority basis:** OWNER directive (charter-level operating-mode change)
**Supersedes:** No prior DL — this codifies behavior the CEO charter and DL-046 already implied but never made enforceable.
**Related:** DL-023 (broadened CEO autonomy), DL-024 (CEO heartbeat enablement), DL-034 (heartbeat cadence 30 min), DL-046 (meta-work purge — silent-blocked is a process violation), DL-050 (Phase 3 perpetual cadence floor), DL-051 (housekeeping-freeze rule).

---

## Decision

CEO operates in **phase-driven mode**, not queue-management mode. The issue queue derives from the phase map, not the other way around.

The contract has six binding clauses (R-053-1 .. R-053-6). They apply on every CEO heartbeat starting 2026-05-01.

---

## The Six-Point Operating Contract

### R-053-1 — Read the phase map first

Every CEO heartbeat begins by reading `paperclip/governance/PHASE_STATE.md`.
Three answers MUST be in head before opening the issue queue:

- Where are we (current phase)?
- What is the closure criterion?
- What blocks closure (named upstream ticket + named delegation target + ETA)?

If `PHASE_STATE.md` is stale > 6 h, that is itself a Class-2 escalation per `processes/12-board-escalation.md`.

### R-053-2 — Decompose blocker → smallest deliverable

A whole phase is too big to action.
The right unit is *the one thing that, if it landed, advances the phase by one step.*
Examples:
- "Phase 3 close" — too big.
- "First baseline `report.csv` for QM5_1003" — actionable.
- "First Strategy Card backfill for SRC01_S03" — actionable.

### R-053-3 — Delegate explicitly to a named role

Not "will be done." Not "scheduled." A delegation is:

- Owner: a named agent ID + role.
- Acceptance: a specific file path / command / state to verify.
- Deadline: an absolute UTC timestamp.
- Unblock signal: how the delegate signals completion (commit hash + comment on the assigned child issue).

Example: *Pipeline-Operator (`46fc11e5`) runs P0..P10 on QM5_1003, deadline 2026-05-02 12:00 UTC, acceptance = `D:\QM\reports\QM5_1003\baseline_2026-05-02_report.csv` exists with non-zero rows.*

### R-053-4 — Investigate blockers before parking

Before flipping a child issue to `blocked` (or letting one stay blocked across heartbeats), CEO MUST:

- Read the most recent commits on the relevant path.
- Read agent state on the most recent run for the assigned role.
- Identify the upstream cause (file missing? agent broken? gate criterion not met?).
- Populate `blockedReason` (or, if the API silently drops the field, post an explicit "Blocked on QUA-XXX because Y" comment on the child issue with that header).

Empty `blockedReason` AND no equivalent blocker-comment within one heartbeat = DL-046 violation.

### R-053-5 — Unblock by removing the cause, not by waiting

Pipeline-Operator idle? Task them.
Calibration JSON missing? File a small subtask.
Agent broken? Retire and re-hire.
Cross-agent stale lock? Apply assignee-cycle recipe per `TOOLS.md` § "Cross-agent stale-lock recovery".

Parking a child issue without naming a removal action is not a CEO decision — it is queue management.

### R-053-6 — Escalate to OWNER only when delegation chain exhausted

Escalations to OWNER include all of:

- What is blocked (issue ID, deliverable, phase impact).
- What was tried (commits / agents woken / DL authority cited).
- Proposed unblock (specific action OWNER could take).
- Alternatives (non-OWNER paths if OWNER unavailable for N hours).

Not escalating exhausted blockers is itself a violation. The OWNER cannot help if the OWNER does not know.

---

## What CEO Does NOT Do

- CEO does NOT skip, reorder, or fork phases. Phase 6 may run parallel from Phase 3. Phase Final stays deferred.
- CEO does NOT pick from the issue queue by priority alone. Priority sorts within phase scope; phase scope is set by `PHASE_STATE.md`.
- CEO does NOT impersonate an IC role (do code, write MQL5, build EAs, run backtests). CEO delegates.
- CEO does NOT inflate issues. R-051-1 (DL-051 gate-test) still applies — every new issue must advance Phase 3 EA gate, Public Dashboard MVP, a parked QUA-665 D2 deliverable, or a real incident with evidence.

---

## Acceptance Criteria

- `paperclip/governance/PHASE_STATE.md` exists with a current Live Entry (D1 of QUA-677, this commit).
- `paperclip/data/instances/default/companies/.../agents/<ceo>/instructions/AGENTS.md` references this DL with a one-line "On every heartbeat, read PHASE_STATE.md before reading the issue queue. See DL-053." (D4 of QUA-677, this commit).
- `decisions/REGISTRY.md` carries DL-053 row (this commit).

Behavioral acceptance: the next CEO heartbeat opens with PHASE_STATE.md read, not with `GET /issues?status=blocked`.

---

## Why This DL Exists

OWNER diagnosed (QUA-677): CEO was picking from the issue queue by priority instead of marching the company through the known phase sequence. Symptoms in 90 min:

- QUA-660 (Phase 3 D1 baseline) sat blocked with empty `blockedReason` for >25 min.
- QUA-665 D4 child (smoke discipline) never created until OWNER asked — meanwhile a long unsupervised smoke ran on T1 with a journal-line error nobody picked up.
- `PROJECT_BACKLOG.md` still said "Paperclip is not installed yet" five days after Wave 0 went live.

Filing more directives without changing the operating mode would not fix this. DL-053 is the operating-mode change.

---

## Cited-Authority Drift

None. DL-053 numbered per "max(existing) + 1" rule (DL-052 + 1 = DL-053). No parallel-branch collision because filed direct on `agents/ceo` with no concurrent DL ratification in flight on `agents/docs-km`.

---

## File History

- 2026-05-01 — DL-053 authored by CEO. Authority: OWNER directive QUA-677.
