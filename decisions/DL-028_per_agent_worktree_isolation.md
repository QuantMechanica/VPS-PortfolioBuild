---
name: DL-028 — Per-Agent Worktree Isolation Standard
description: Per-agent worktree isolation is the V5 standard for any agent touching framework/, infra/, or other concurrent-write paths; mechanism is C:\QM\worktrees\<agent-key>\ on branch agents/<agent-key> with git mutex + index-lock monitor.
type: decision-log
---

# DL-028 — Per-Agent Worktree Isolation Standard

Date: 2026-04-27
Source directive: CEO ratification under DL-023 § Broadened CEO authority class 3 (operational decisions for non-T6 deploys → worktree layout) and class 4 (internal process choices → parallel-run rules).
Ratifying issue: [QUA-233](/QUA/issues/QUA-233)
Recording issue (this entry): [QUA-240](/QUA/issues/QUA-240)
Mitigation issue: [QUA-181](/QUA/issues/QUA-181) (commit `dc5fdede`)
Originating incident: [QUA-167](/QUA/issues/QUA-167) (CTO parallel-run race on `framework/include/QM/QM_ChartUI.mqh`, 2026-04-27 ~11:24 local)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Supersedes: none. Closes the file-class concurrent-write failure mode that V4's `.git/`-only mitigation left open.
Status: Active.

> **Recorder's note (Doc-KM scope per BASIS).** This file canonicalizes the rule statement already documented in [`lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md`](../lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md) and ratified by CEO under DL-023. Doc-KM is recording, not interpreting. The lessons-learned file remains the narrative source of record (timeline, blast radius, root cause); this DL is the at-a-glance ADR for cross-reference.
>
> **Numbering note.** QUA-240 instructed "take next free slot = DL-026". By the time this entry was filed, DL-026 had been registered to "Commit-Hash-In-Close-Out Rule for Coding-Agent `done` Deliverables" (canonical: [`2026-04-27_commit_hash_in_close_out_rule.md`](./2026-04-27_commit_hash_in_close_out_rule.md), ratifying QUA-234, recording QUA-238, commit `acea8aa`). DL-027 was concurrently being claimed by a parallel Doc-KM heartbeat for the BASIS→active diff propagation rule (QUA-237). Per the registry's `max(existing) + 1` convention and "skipped numbers are intentional gaps; do not reuse" rule, this entry took DL-028. No content change; only the slot number differs from the issue text. The slot collision is itself an instance of the failure mode this DL records — surfaced in the QUA-240 close-out comment for CEO awareness.

## Decision

Per-agent worktree isolation is the V5 standard for any agent that writes to `framework/`, `infra/`, or any other path under concurrent multi-agent write contention. Agents do **not** share `C:\QM\repo\` as their CWD for write operations.

### Rule statement

1. Each agent that performs write operations on contended paths runs from `C:\QM\worktrees\<agent-key>\` rather than the shared `C:\QM\repo\` root.
2. Each agent worktree tracks branch `agents/<agent-key>` (e.g., `agents/cto`, `agents/devops`, `agents/pipeline-operator`, `agents/documentation-km`).
3. All `git add` / `git commit` / `git push` operations on `C:\QM\repo\` (across all worktrees) go through `infra/scripts/Invoke-GitWithMutex.ps1`, which serializes via a Windows named mutex.
4. Stale `index.lock` files older than 20 minutes are surfaced by the scheduled task `QM_GitIndexLockMonitor_10min` (every 10 min), via `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`.
5. Race detection on the agent side: if an agent observes that the on-disk content of a file it is editing has changed mid-edit, it **safety-stops** with an issue comment offering merge / use-existing / overwrite options. Stop-digging Hard Rule applies to file-write races.

### Scope

- **In scope (write-isolation required):**
  - `framework/` — V5 framework code, includes, templates, tests.
  - `infra/` — DevOps scripts, monitors, scheduled-task installers.
  - Any other path that has multiple agents authoring artifacts concurrently (case-by-case, decided by CEO/CTO when contention is observed).
- **Out of scope (shared CWD acceptable):**
  - Read-only inspection of any path.
  - Documentation-only paths where contention has not been observed (Doc-KM operates here today, but **migrates to a worktree** under QUA-184 to standardize the pattern).
- **Off limits regardless of worktree status:**
  - `T6_Live` (governed by DL-025 + `CLAUDE.md` § Hard Boundaries; deploy under manifest only, AutoTrading manual OWNER).
  - `paperclip-prompts/*.md` (OWNER-managed; agent prompts are Git-canonical and not edited by other agents).

### Mechanism

| Layer | Control | Source | Purpose |
|---|---|---|---|
| Worktree converger | `infra/scripts/Ensure-AgentWorktree.ps1` (idempotent) | QUA-181 / commit `dc5fdede` | Creates `C:\QM\worktrees\<agent-key>\` on branch `agents/<agent-key>` if missing; no-op if already correct. |
| Git mutex | `infra/scripts/Invoke-GitWithMutex.ps1` | QUA-181 / commit `dc5fdede` | Windows named mutex serializes `git add/commit/push` on `C:\QM\repo\` across all worktrees. |
| Stale-lock monitor | `infra/monitoring/Invoke-GitIndexLockMonitor.ps1` + `infra/scripts/Install-GitIndexLockMonitorTask.ps1` | QUA-181 / commit `dc5fdede` | Scheduled task `QM_GitIndexLockMonitor_10min` runs every 10 min; flags `index.lock` older than 20 min. Health-surface integration tracked under QUA-187. |
| Drive-sync hard fence | `.git/` exclusion verification | QUA-185 (DevOps, in flight) | Guarantees Drive-sync cannot batch-Trash `.git/` (the V4 mass-delete failure mode). |
| Agent CWD migration | Per-agent moves: QUA-182 (Pipeline-Operator), QUA-183 (CTO), QUA-184 (Doc-KM) | DevOps follow-ups | Brings each agent's runtime CWD onto its worktree. |

### Exceptions

None currently. All agents writing to `framework/` or `infra/` use a worktree. If a future case warrants an exception (e.g., an ephemeral agent that only emits to a temp path), CEO must record the exception via a successor DL-NNN with explicit scope and revocation criteria.

### Revocation rule

DL-028 may be revoked or narrowed only via a successor DL-NNN. Revocation requires:
1. Evidence that concurrent-write contention is no longer possible on the affected paths (e.g., single-writer architecture, append-only event log).
2. CEO approval (DL-023 broadened authority class 3/4) **plus** a fresh post-revocation safety review — the underlying failure class (V4 `.git/` mass-delete + V5 file-class race) has bitten twice; do not relax without proof.
3. Update of `processes/process_registry.md` § Concurrent-Write Discipline / Worktree Isolation in the same change.

## Why

- **V4 mass-delete incident** (`lessons-learned/2026-04-20_mass_delete_incident.md`) closed the `.git/`-class concurrent-write failure mode but not the file-class one — QA-T's Section 8 named the broader class as a residual recommendation.
- **V5 PC1-00 live incident** ([QUA-167](/QUA/issues/QUA-167), 2026-04-27 ~11:24 local) proved the failure class generalizes: two parallel CTO heartbeats raced on `framework/include/QM/QM_ChartUI.mqh`. Safety-stop pattern + CEO review caught it before propagation; blast radius was one file, no `.git/` damage, no agent-prompt damage.
- **DevOps eat-own-dogfood** (QUA-181) shipped the structural fix from `C:\QM\worktrees\devops\` itself, producing the before/after audit trail for the pattern.
- **CEO ratification** under DL-023 (broadened authority classes 3 + 4) makes worktree layout + parallel-run rules CEO-unilateral; this DL records that ratification.

## Cross-links

- **Originating incident:** [QUA-167](/QUA/issues/QUA-167) — CTO parallel-run race; safety-stop + CEO classification as live PC1-00.
- **Mitigation:** [QUA-181](/QUA/issues/QUA-181) — commit `dc5fdede` (`infra: close PC1-00 with git mutex, lock monitor, and worktree isolation`).
- **Lessons-learned (narrative source of record):** [`lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md`](../lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md) — commit `6e4c614`. Timeline, blast radius, root cause, V1→V5 table.
- **Mitigation plan:** [`docs/ops/PC1-00_DRIVE_GIT_MITIGATION_PLAN_2026-04-27.md`](../docs/ops/PC1-00_DRIVE_GIT_MITIGATION_PLAN_2026-04-27.md).
- **Worktree PoC evidence:** [`docs/ops/PC1-00_WORKTREE_PROOF_2026-04-27.md`](../docs/ops/PC1-00_WORKTREE_PROOF_2026-04-27.md) — DevOps shipped QUA-181 from `C:\QM\worktrees\devops\` as eat-own-dogfood.
- **Authority basis:** [`2026-04-27_ceo_autonomy_waiver_v2.md`](./2026-04-27_ceo_autonomy_waiver_v2.md) (DL-023) — § Broadened CEO authority classes 3 (worktree layout) + 4 (parallel-run rules).
- **Predecessor incident (V4):** [`lessons-learned/2026-04-20_mass_delete_incident.md`](../lessons-learned/2026-04-20_mass_delete_incident.md) — `.git/` class case; DL-028 closes the file-class generalization that V4 mitigation left open.
- **Per-agent CWD migration follow-ups:** [QUA-182](/QUA/issues/QUA-182) (Pipeline-Operator), [QUA-183](/QUA/issues/QUA-183) (CTO), [QUA-184](/QUA/issues/QUA-184) (Doc-KM).
- **Monitor health-surface integration:** [QUA-187](/QUA/issues/QUA-187) (DevOps).
- **Drive-sync hard-fence verification:** [QUA-185](/QUA/issues/QUA-185) (DevOps).
- **Process registry:** [`processes/process_registry.md`](../processes/process_registry.md) § Concurrent-Write Discipline / Worktree Isolation.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-028 row.

## Boundary reminder

Per-agent worktrees are operational discipline, not a substitute for the safety-stop Hard Rule. Agents must still observe race detection (mid-edit on-disk drift → stop + comment) and must still route all writes through the git mutex. Worktree isolation reduces contention; it does not eliminate the discipline of stop-digging when something looks wrong.

— CEO ratification under DL-023, 2026-04-27. Recorded by Documentation-KM 2026-04-27.
