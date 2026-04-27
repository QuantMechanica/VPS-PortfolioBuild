# Lessons Learned — PC1-00 Live Incident on QUA-167 (CTO Parallel-Run Race)

**Date:** 2026-04-27
**Phase gate:** Phase 1 (Paperclip Bootstrap) — closing
**Author:** Documentation-KM (QUA-189)
**Reviewer:** CEO + Board Advisor
**Severity:** P1 (file-level concurrent-write race; safety-stop prevented data loss)
**Cross-references:** [QUA-167](http://localhost:3100/QUA/issues/QUA-167) · [QUA-180](http://localhost:3100/QUA/issues/QUA-180) · [QUA-181](http://localhost:3100/QUA/issues/QUA-181) · `lessons-learned/2026-04-20_mass_delete_incident.md` · `docs/ops/PC1-00_DRIVE_GIT_MITIGATION_PLAN_2026-04-27.md` · `docs/ops/PC1-00_WORKTREE_PROOF_2026-04-27.md`

---

## 1. Timeline (local time, 2026-04-27)

| Time | Event |
|---|---|
| 11:21:28 | CTO starts QUA-167 (V5 framework Step 15 — `framework/include/QM/QM_ChartUI.mqh`). |
| ~11:24 | While CTO is editing `QM_ChartUI.mqh`, a second CTO run (parallel heartbeat) is also writing to the same file. CTO's edit-side observes the on-disk content has changed under it to a different implementation. |
| 11:26:17 | CTO **safety-stops** and posts an issue comment: "Unexpected concurrent change detected, so I stopped per your safety rule." Three options offered (use on-disk, overwrite, merge). |
| 11:29:26 | The other CTO run completes the implementation cleanly and posts the success comment with module path + verification evidence. |
| 11:33:04 | CEO reviews and confirms the safety-stop was correct; classifies the event as the **live PC1-00 problem in miniature** — two of CTO's own parallel runs racing on the same file in the same repo. CEO halts further parallelism on QUA-149's children until QUA-180 (commit pass) and QUA-181 (mitigation) land. |
| 11:35–11:36 | DevOps ships the QUA-181 mitigation **from an isolated worktree** (`C:\QM\worktrees\devops\`, branch `agents/devops`) — eat-own-dogfood. Commit `dc5fdede`. |
| 11:41:43 | CEO accepts QUA-181 as `done` after verifying all five acceptance criteria on disk. |
| 11:42:09 | DevOps opens follow-up child issue `QUA-187` for monitor-surface integration. Phase 1 acceptance gate goes GREEN. |

The window between race-detection and structural mitigation was **~17 minutes**, because the safety-stop was already in place on the CTO side and DevOps had already been dispatched on QUA-181 in parallel.

---

## 2. Blast radius

- One file (`framework/include/QM/QM_ChartUI.mqh`) was overwritten by the second CTO run. Nothing was lost — both runs were producing the same V5 Step 15 deliverable, and the late-arriving run shipped a clean commit (`210e541`).
- No `.git/` corruption. No Drive-Trash event. No agent-prompt damage.
- The damage that *did not* happen — the V4 mass-delete pattern at file-class scale — is exactly what the V4 incident (`lessons-learned/2026-04-20_mass_delete_incident.md`) predicted would recur if concurrent-write architecture was not changed.

The blast radius was small **because** the safety-stop pattern already existed in the CTO's prompt (Hard Rule: "stop digging — if a fix worsens outcomes, revert, don't double down") and CEO's review pattern caught the incident class before it propagated.

---

## 3. Root cause

**Two parallel Paperclip heartbeats of the same agent (CTO) were both assigned to the same in-progress issue (QUA-167) and both attempted to write to the same on-disk file.**

The agent's `heartbeat: 1 hour` cadence + a wake-on-comment event landed two runs on overlapping intervals. Both runs:
- read the issue,
- saw the deliverable was uncommitted,
- generated their own implementation of `QM_ChartUI.mqh`,
- raced on the filesystem write.

This is the **per-file** sibling of the V4 mass-delete incident, which was the **per-`.git/`** case. Both share the architectural cause: multiple concurrent writers against a path that has lock-file or atomic-write semantics, with no mutex.

### Why the V4 lesson did not pre-empt this

The V4 lesson focused on the `.git/` directory specifically (Drive-sync conflict resolution batch-trashing files). The going-forward rules from V4 — `.git/` exclusion from Drive sync, `index.lock` monitor, file-deletion CEO-OK — addressed the `.git/` failure mode, **not** the application-file failure mode. The full failure class (concurrent writers without mutex on any contended path) was named in QA-T's Section 8 recommendations but had not been fully closed before today.

The today incident is the proof that the failure class generalizes.

---

## 4. The structural fix (QUA-181)

DevOps shipped three controls in commit `dc5fdede` from an isolated worktree:

1. **Per-repo git mutex** — `infra/scripts/Invoke-GitWithMutex.ps1` serializes any agent's `git add/commit/push` on `C:\QM\repo\` via a Windows named mutex.
2. **Stale-lock monitor** — `infra/monitoring/Invoke-GitIndexLockMonitor.ps1` + `infra/scripts/Install-GitIndexLockMonitorTask.ps1`. Idempotent installer. Runs on a 10-minute scheduler (`QM_GitIndexLockMonitor_10min`). Detects `index.lock` files older than 20 minutes and emits machine-readable status.
3. **Worktree isolation converger** — `infra/scripts/Ensure-AgentWorktree.ps1`. Idempotent. Creates `C:\QM\worktrees\<agent-key>\` on branch `agents/<agent-key>` for any agent that should have its own CWD. Verified PoC: DevOps itself worked from `C:\QM\worktrees\devops\` to ship QUA-181 (`docs/ops/PC1-00_WORKTREE_PROOF_2026-04-27.md`).

The eat-own-dogfood pattern is the structural correctness signal: DevOps proposing worktree isolation while *not* using one would have been weaker evidence. By using the converger to do the QUA-181 work itself, DevOps produced a real before/after for the audit trail (per CEO's option-2 instruction at 11:33:04).

---

## 5. Going-forward rule (the lesson)

**Per-agent worktree isolation is now the standard for any agent touching `framework/`, `infra/`, or any path under concurrent multi-agent write contention.**

Mechanism:
- Agents run from `C:\QM\worktrees\<agent-key>\` rather than the shared `C:\QM\repo\` root.
- Branch convention: `agents/<agent-key>`.
- All `git add/commit/push` go through `Invoke-GitWithMutex.ps1`.
- Stale `index.lock` files older than 20 min are surfaced by the 10-min monitor task (`QM_GitIndexLockMonitor_10min`).

Documentation-KM does not own enforcement — that's CTO + DevOps. Documentation-KM owns the lesson record (this file) and propagating the rule into the process registry once item #5 of QUA-189 unblocks.

---

## 6. Format — Learning → V1 Behavior → V5 Behavior → Why

| Aspect | V1 Behavior | V5 Behavior | Why |
|---|---|---|---|
| Concurrent writers on contended files | All agents share `C:\QM\repo\` as CWD; multiple parallel heartbeats can write the same file simultaneously. | Per-agent worktree isolation under `C:\QM\worktrees\<agent-key>\` for any agent touching `framework/`, `infra/`, or other contended paths. | The V4 mass-delete incident generalized today on a single file. The full failure class is concurrent writers without mutex on any contended path, not only `.git/`. |
| Race detection | Implicit — agent might silently overwrite or get overwritten. | Explicit — agent observes that on-disk content has changed mid-edit and **safety-stops** with an issue comment offering merge/use-existing/overwrite options. | Stop-digging Hard Rule applied to file-write races. Safety-stop preserves both versions for human review rather than picking a winner blind. |
| Recovery from race | Detect failure later, often after downstream gates have promoted bad state. | CEO `git status --porcelain` cross-check before promoting downstream gates; concurrent-write events get a lessons-learned entry, not a quiet rebase. | Aligns with `no fantasy numbers` Hard Rule: every claim cites a report/log/state entry; concurrent-write events leave a record. |
| Mitigation cadence | V1 fixed `.git/`-only after the mass-delete; the file-class case stayed open as a QA-T Section-8 recommendation. | V5 closes the full concurrent-write class via mutex + stale-lock monitor + worktree isolation, all idempotent and convergence-installed. | A failure class isn't closed until every on-VPS path that exhibits it is covered. The V4 lesson stopped one step short. |

---

## 7. Open follow-ups

- [ ] **QUA-187 (DevOps):** Integrate git index-lock monitor into canonical infra health surface. (Spawned by QUA-181 close.)
- [ ] **CTO + Pipeline-Op + Doc-KM rollout** of the `Ensure-AgentWorktree.ps1` converger to their own CWDs (tracked by DevOps under QUA-182/183/etc.).
- [ ] Process registry refresh (item #5 of QUA-189) — record worktree isolation as standard for concurrent-write agents. **Blocked on QUA-188 (CEO autonomy waiver) per QUA-189 coordination notes.**

---

## 8. Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v1.0 | 2026-04-27 | Documentation-KM (QUA-189) | Initial entry. CEO + Board Advisor pending review. |
