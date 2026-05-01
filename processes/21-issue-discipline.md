# Process 21 — Issue Inflation Discipline + Blocked-Issue Unblock-Owner Convention

**Owner:** [Documentation-KM](/QUA/agents/documentation-km) (codifier); enforcer authority: [Quality-Tech](/QUA/agents/quality-tech) + [Documentation-KM](/QUA/agents/documentation-km) per [DL-051](../decisions/DL-051_housekeeping_freeze_rule.md).
**Authority:** [DL-057](../decisions/2026-05-01_issue_inflation_discipline.md) (Issue Inflation Discipline) + [DL-051](../decisions/DL-051_housekeeping_freeze_rule.md) (Housekeeping-Freeze Rule) + [DL-046](../decisions/DL-046_meta_work_purge_qua641.md) (anti-theater principle).
**Trigger:** QUA-644 audit — 12,200 done issues in 7 days; 549 smoke-test mentions; 69 blocked issues with unset unblock-owner.
**Reference:** [QUA-647](/QUA/issues/QUA-647).

---

## 1. Issue vs. Comment Decision Rule

**Default: post a comment.**

Create a new issue only when **all three** of the following are true:

1. The work unit is **separable** — another agent can pick it up independently without reading the parent thread.
2. The work unit has a **distinct acceptance criterion** — a specific, verifiable done condition that differs from the parent's.
3. The work unit represents a **new root-cause hypothesis or a new workstream**, not a continuation of an in-progress investigation.

**Use a comment instead of an issue for:**

- Per-heartbeat debug observations ("tried X, got error Y, trying Z next").
- Incremental progress updates on an in-progress issue.
- Smoke-test runs, single-attempt verification results, or retries.
- Status changes with no durable output (e.g., "blocked pending X, no new evidence").
- Follow-up notes that refine understanding of an existing deliverable without creating new work.

**Anti-pattern to avoid:** spawning one child issue per heartbeat-iteration of the same debugging loop. The issue tree is a work-routing structure, not a log.

---

## 2. Per-Heartbeat Issue-Creation Budget

| Agent class | New issues per heartbeat (soft cap) | Hard limit |
|-------------|-------------------------------------|------------|
| IC (Research, Doc-KM, DevOps, Pipeline-Op, etc.) | 0–2 | 5 |
| Manager (CEO, CTO, Quality-Tech, Quality-Business) | 0–5 | 10 |
| Board Advisor / OWNER | uncapped | — |

Exceeding the soft cap is allowed with a `[gate-test]` annotation per [DL-051](../decisions/DL-051_housekeeping_freeze_rule.md) explaining which bucket the excess issues advance. Exceeding the hard limit in a single heartbeat is a DL-046 R-046-1 violation.

**DL-051 gate-test requirement:** every new issue body MUST include one of:

```
[gate-test] advances: <active Phase 3 EA gate | Public Dashboard MVP / M3 | parked deliverable in QUA-665 D2 | real incident with evidence>
```

OWNER-authored, Board-Advisor-audit, and explicitly delegated gated-parent-subtask issues are exempt from the `[gate-test]` annotation.

---

## 3. Blocked-Issue Unblock-Owner Convention

Every issue transitioned to `blocked` status **MUST** declare an unblock owner before or at the moment of the `blocked` PATCH.

### 3.1 Encoding (until platform-native field ships)

Embed in the issue **description** (not a comment — comments can be buried):

```html
<!-- unblock_owner: <value> -->
<!-- block_class: <sequencing-blocked | capacity-blocked> -->
```

Where `<value>` is one of:

| Value type | Example | When to use |
|---|---|---|
| Named agent role | `cto` / `pipeline-operator` / `quality-tech` | A specific agent must act to unblock |
| Named user | `owner` | OWNER decision required |
| Workstream signal | `unblock_on:src01_s01_complete` | Auto-unblockable once a milestone lands |
| Blocker issue ID | `unblock_on_issue:QUA-686` | Paperclip `blockedByIssueIds` is the machine-readable form; the HTML comment is the human-readable companion |

When the blocker is another issue, **also** set `blockedByIssueIds` via PATCH so Paperclip auto-wakes the dependent assignee on resolution.

### 3.2 Blocked-issue triage cadence

| Role | Obligation |
|---|---|
| CEO | Scan all `blocked` issues in the inbox every 2 heartbeats; confirm unblock_owner is set or escalate to OWNER |
| Quality-Tech | Flag missing unblock_owner as a DL-057 violation; propose cancel or reassign |
| Documentation-KM | Update this process doc when new block-class patterns emerge |

---

## 4. Block-Class Taxonomy

### `sequencing-blocked`

By-design dependency — the blocked issue cannot start until an upstream milestone completes. This is expected and healthy.

**Signs:** `blockedByIssueIds` is set to a real upstream issue; the upstream is actively in-progress; ETA is defined.

**Correct action:** set `blockedByIssueIds`, embed `unblock_on_issue:QUA-NNN`, leave the issue parked until Paperclip auto-wakes it.

**Anti-pattern:** checking-in to a sequencing-blocked issue every heartbeat to "prove awareness." That is keepalive churn, a DL-046 R-046-2 violation.

### `capacity-blocked`

Real bottleneck — the work is ready to proceed but an agent or OWNER decision is unavailable.

**Signs:** unblock_owner is a named agent or `owner`; no upstream issue is the direct cause; the blocker is calendar time or a human decision.

**Correct action:** name the unblock owner explicitly; escalate per [12-board-escalation.md](12-board-escalation.md) if the block has exceeded the SLA below.

**Capacity-block SLA:**

| Unblock owner | Acceptable wait | Escalation |
|---|---|---|
| Any IC agent | 1 heartbeat (agent's own cadence) | Class-3 escalation to CEO |
| CEO | 2 heartbeats | Class-2 escalation to OWNER |
| OWNER | 24 h | Class-1 (Board Advisor direct) |

---

## 5. Enforcer Flow

```
New issue appears
    ↓
Does it have a [gate-test] annotation? ──No──→ Quality-Tech cancels or requests annotation
    ↓ Yes
Is it separable + distinct acceptance criterion + new workstream? ──No──→ Convert to comment, cancel issue
    ↓ Yes
Issue proceeds normally

Issue transitions to `blocked`
    ↓
Is <!-- unblock_owner: ... --> present in description? ──No──→ Quality-Tech / Doc-KM adds the field or moves back to in_progress with a note
    ↓ Yes
Is <!-- block_class: ... --> present? ──No──→ Quality-Tech / Doc-KM adds the field
    ↓ Yes
For sequencing-blocked: is blockedByIssueIds set? ──No──→ PATCH blockedByIssueIds
    ↓ Yes
Issue parks correctly; Paperclip auto-wakes on blocker resolution
```

---

## 6. Violations and Consequences

| Violation | Rule reference | Consequence |
|---|---|---|
| New issue without `[gate-test]` | DL-051 R-051-1 | Immediate cancel by Quality-Tech or Doc-KM |
| `blocked` issue without `unblock_owner` | DL-057 R-057-1 | Quality-Tech / Doc-KM adds field or reverts to `in_progress`; non-compliance note in issue thread |
| Per-heartbeat churn issues (debug-iteration pattern) | DL-046 R-046-1 | Cancel; consolidated comment requested |
| Keepalive-evidence commits on a blocked issue | DL-046 R-046-2 | CTO to reverse commit; Class-3 escalation to CEO |

---

## 7. Revisit Gate

This rule is re-evaluated when either of:

- The 30-day `blocked` issue count exceeds 80 (current baseline: 69 at 2026-05-01 audit).
- The per-week new-issue count exceeds 15,000 (current baseline: 12,200 at 2026-05-01 audit).

Doc-KM opens a `learning-candidate` issue on either trigger; CEO + Board decide on amendments to this process.

---

*Last updated: 2026-05-01. Authority: [DL-057](../decisions/2026-05-01_issue_inflation_discipline.md). Authored by [Documentation-KM](/QUA/agents/documentation-km) under [QUA-647](/QUA/issues/QUA-647).*
