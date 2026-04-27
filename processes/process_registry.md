# Process Registry

## Execution Policies

Per [DL-030](../decisions/2026-04-27_execution_policies_v1.md): every issue created in scope of a stakes-bearing flow MUST carry an `executionPolicy` block at creation time (or via PATCH before `in_progress`). The runtime — not the agent — enforces the `in_progress → done` interception. The full JSON snippets (with concrete reviewer/approver participant identifiers) live in DL-030; this registry section is the role-level convention.

| Class | Flow | Scope test | Policy | Reviewer / Approver (role) | Wave 2 hire trigger |
|---|---|---|---|---|---|
| 1 | T6 deploy | `projectId` = T6 Live Operations, **or** title matches `^T6 deploy` (case-insensitive) | **Approval-only** | OWNER | n/a |
| 2 | Strategy Card extraction | `projectId` = V5 Strategy Research **and** issue is a Strategy Card (child of a Source-research parent per DL-029; source-extraction parents and the workflow-charter parent are exempt) | **Review-only** | Quality-Business when hired; interim: CEO with OWNER fallback (per DL-016) | swap participants to Quality-Business on Wave 2 hire |
| 3 | EA `_v2+` enhancement | `projectId` = V5 Framework Implementation **and** title matches `_v[0-9]+\b` | **Review-only** | Quality-Tech when hired; interim: CTO | swap participants to Quality-Tech on Wave 2 hire |
| 4 | All other issues | n/a (default) | Comment-required only (Paperclip default) | n/a | n/a |

`commentRequired: true` is independent of stages and remains on for every issue regardless of class.

**Class 1 layered relationship to DL-025.** Approval-only is layered on top of — not a substitute for — the V5 hard rule that **AutoTrading is OWNER-manual**. The runtime gate intercepts the `done` transition; the live-account toggle stays out of agent hands entirely.

**Sentinel role.** CEO scans for unpolicied issues in scope and PATCHes a policy in. Manual sweep until an automation routine is added.

**Self-review prevention.** The runtime excludes the original executor from the eligible reviewer/approver set. Class 2 lists OWNER as a fallback participant so CEO-authored strategy cards can still close while CEO holds the interim Quality-Business seat.

For the full JSON shape per class (including reviewer/approver participant identifiers), see [DL-030 § Implementation mechanism](../decisions/2026-04-27_execution_policies_v1.md).

## Factory Setup Standards

- MT5 factory terminals `T1`-`T5` must include an install-root `portable.txt` marker file (empty file) to prevent AppData split-brain when launched without explicit `/portable`.
