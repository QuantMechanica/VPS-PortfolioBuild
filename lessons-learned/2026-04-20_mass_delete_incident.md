# Mass-Delete Incident — 2026-04-20 00:33 CEST

**Incident ticket:** [QUAA-255](http://localhost:3100/QUAA/issues/QUAA-255)
**Forensic subtask:** [QUAA-255/A](http://localhost:3100/QUAA/issues/QUAA-256) — root-cause attribution
**Documentation subtask:** [QUAA-255/B](http://localhost:3100/QUAA/issues/QUAA-257) — this document + policy + agent patches
**Severity:** P0 (repo-broken, dashboard-stale ~5h, all G:-reading agents starved of context)
**Status (this version):** Recovery in progress; root cause attribution pending QUAA-255/A.

---

## 1. Timeline (UTC unless noted)

| Time (CEST) | Event |
|---|---|
| 2026-04-20 00:31:10 | CEO heartbeat run completes successfully. |
| 2026-04-20 00:32:10 | Pipeline-Operator heartbeat run completes successfully. |
| 2026-04-20 00:33:19 | Drive log (`drive_fs_*.txt`) registers first `Could not unpin removed item` event. |
| 2026-04-20 00:33:19 → 00:33:32 | Burst of 12+ deletion events per second; Drive moves the targets into Trash. Pattern is mechanical — not a human click-click pace. |
| 2026-04-20 00:33:32 | Drive log: `trash_folder.cc:1204 UpdateItemAndLocalProperty Could not find entry id for recycled file` — confirms the targets were already moved before Drive could finish the local-side bookkeeping. |
| 2026-04-20 00:37:46 | First downstream symptom: `standalone_aggregator_loop.py` emits `FileNotFoundError: Company\TODO.md`. The error repeats roughly every 5 min from this point. |
| 2026-04-20 ~01:00 | Claude-Assistant detects starvation across multiple agents (CLAUDE.md, RECOVERY.md, Pipeline specs all read empty / not found), dashboards stale since 23:34. |
| 2026-04-20 ~02:30 | Fabian alerted; pauses Pipeline-Operator + DevOps + Development via Paperclip API. |
| 2026-04-20 ~02:45 | Fabian initiates Drive Trash recovery (30-day retention window). Sync begins. |
| 2026-04-20 03:05 | QUAA-255 + QUAA-256 (forensics) + QUAA-257 (this doc) opened. Documentation-KM checked out QUAA-257. |
| 2026-04-20 (ongoing) | Drive sync still partial — 4 of 13 `Company/Agents/*/system_prompt.md` files restored to disk; 9 still pending. |

The 5h+ stall between detection and the policy/learnings response reflects: (a) Fabian was asleep when the burst landed; (b) Drive Trash recovery is wall-clock bound by Drive sync, not by us.

---

## 2. Blast radius

Files moved to Drive Trash (confirmed via Drive log + post-recovery diff against last good git commit + standalone-loop error chain):

**Repo root (high-impact, all whitelisted by the new policy):**
- `CLAUDE.md` — root contract, every agent reads on activation
- `RECOVERY.md` — session-start guide, this Claude-Assistant reads first
- `MEMORY.md` — auto-memory index for this assistant
- All other root `*.md` files presumed gone (HANDOFF.md, etc. — being verified post-sync)

**Documentation tree:**
- `Processes/processes.html` — process landscape (the canary that RECOVERY.md tells you to grep for `<!doctype html>` to test Drive sync state)
- `doc/` — canonical documentation
- `project_dashboard.html` (G:-mirror copy) — dashboard hadn't refreshed since 23:34 because Controlling could no longer write to its source files

**Git internals (this is the worst category):**
- `.git/HEAD`
- `.git/config`
- `.git/index`
- `.git/hooks/`
- `.git/info/`
- `.git/packed-refs`
- → repo effectively broken; `git status`, `git log`, `git commit`, `git push` all failing until Drive restores the internals

**Company/Agents/:**
- 9 of 13 `system_prompt.md` files. As of this writing the 4 still readable on disk are CEO, Controlling, Pipeline-Operator, Strategy-Analyst. The other 9 (CTO, Development, DevOps, Documentation-KM, LiveOps, Quality-Tech, R-and-D, Observability-SRE, Quality-Business, Research) have not yet re-synced. Drive serves directories with `Permission denied` for these paths until sync completes.

**Probably also affected (to be verified post-sync):**
- `Tools/`
- `Vendor/`
- Brand-related files
- Other root-level documents

The forensic subtask QUAA-255/A is responsible for producing the authoritative full file list against the last good commit.

---

## 3. Root cause (post-forensic — QUAA-256 closed 2026-04-20 03:47Z)

### Verdict (from QA-Tech forensic)

The root cause is **NOT an agent script.** Both initially suspected artifacts were cleared:

- **QUAA-242** (`full_baseline_scan.py`) — CLEARED. Every destructive code path is anchored to `$APPDATA/MetaQuotes/...` and cannot resolve to `G:\Meine Ablage\QuantMechanica\`. Last run 1h37min before the incident.
- **QUAA-243** (`mt5_tester_bar_tmp_watchdog.ps1`) — CLEARED. Anchored to `$env:APPDATA\MetaQuotes\Tester`, with `Test-PathUnderRoot` containment. State file last modified ~2h before the incident; not running at 22:33 UTC.
- `disk_guardian.sh` (T3 tester cleanup) — CLEARED. Hard-coded to a single tester path; logged `ok | bar*.tmp=0 | disk=64.66 GB` at 22:33:08 UTC, **11 s before the deletion burst**.
- Agent run audit at 22:33 UTC: **no Paperclip agent was executing a destructive command in `G:\Meine Ablage\QuantMechanica\`** at incident time.

Full report: `Company/Results/QA_REVIEW_QUAA-256_FORENSIC_REPORT.md` ([QUAA-256](http://localhost:3100/QUAA/issues/QUAA-256)).

### Real cause: Google Drive sync conflict triggered by concurrent multi-agent git writes

Causal chain (per QA-T):

1. **Multiple agents** (Development, CTO, QA-T, Pipeline-Operator) all share `G:\Meine Ablage\QuantMechanica\` as their git working directory — 574 execution-workspace records confirm this.
2. **Concurrent git writes** over multiple days left **22 orphaned `index (N).lock` files** in `.git/`. The git index state was inconsistent.
3. **QUAA-246 commit at 21:49:56 UTC** by Development left `index.lock` (333 KB) orphaned, likely because another process held the index simultaneously during commit finalization.
4. At **22:33:19 UTC**, Google Drive sync detected that the local repo state (broken index + stale lock files) diverged from the cloud version. Drive applied a sync resolution by **batch-trashing 12+ files in a 13-second burst**.
5. Forensic fingerprints that confirm Drive-sync (not a script) was the actor:
   - Deletion velocity (12+ files / 13 s) matches Drive batch sync, not a Python/PS loop.
   - `cello_fs.cc:3140 Could not unpin removed item` is a Drive-for-Desktop internal sync log line.
   - Files moved to Drive **Trash** (recoverable) — `rm` / `os.remove` would have unlinked them outright.
   - Partial loss of `.git/refs/heads/` is consistent with Drive removing files it considered out-of-sync.
6. Post-deletion git operations at 22:34–22:36 UTC wrote new objects and updated `refs/heads/` — heartbeat-triggered runs that attempted to recover repo state, leaving the repo in the "HEAD → missing SHA" state we still see now.

### Why the architecture is the latent cause

`git` POSIX lock-file semantics (`index.lock`, `MERGE_HEAD`, atomic-rename ref writes) are fundamentally incompatible with Google Drive's per-file independent cloud-sync model. When lock files pile up and agents commit in rapid succession, Drive can fall behind and then "batch-correct" by trashing files it considers conflicting. The same architecture will fail again if not changed.

### Contributing factor (orchestration, not script)

- No mutex serialising git operations across agents.
- No `.git/` exclusion in Drive's "excluded folders" list.
- No lock-file monitor / auto-cleanup for stale `index.lock`.

---

## 3a. Why the initial diagnosis was wrong (hypothesis-vs-forensic divergence)

The first version of this doc (v0.1, written before QUAA-256 closed) named QUAA-243's `bar*.tmp` cleanup as the most-probable trigger. That hypothesis was reasonable but wrong. Documenting the divergence is the whole point of a Learnings doc.

**What pointed to "agent script with bad path anchor":**
- 12+ deletes/sec — a velocity that *is* compatible with a recursive enumeration → batch-delete script.
- Two in-review subtasks (QUAA-242, QUAA-243) had touched tester-temp cleanup logic in the hours before the burst.
- A prior debugging culture of treating timing-correlation ("Pipeline-Operator heartbeat at 00:32:10, burst at 00:33:19") as causal evidence.
- The "files moved to Recycle Bin / Trash" pattern was read as `Move-Item -Destination $RecycleBin`, which a careless PowerShell script could plausibly emit.

**What re-pointed it to Drive-sync:**
- `cello_fs.cc:3140 Could not unpin removed item` is a Google-Drive-for-Desktop log signature, not an OS-side log. QA-T identified this as Drive-internal.
- The destination was Drive Trash specifically (cloud trash), not Windows Recycle Bin. A `Remove-Item` would have produced Recycle-Bin entries; Drive Trash is a Drive-only destination.
- Per-agent CWD audit at 22:33 UTC: no agent had `G:\` as cwd at the moment of the burst (verified in QA-T's run-table, Section 5 of `QA_REVIEW_QUAA-256_FORENSIC_REPORT.md`).
- The repo's pre-burst `.git/` state had 22 orphaned `index (N).lock` files dating back days — that's the divergence-from-cloud signal Drive responded to.

**Lessons for future incident response:**
1. **Provenance of log-line signatures matters.** When a log line is in the deletion path, identify which process emits it (OS / Drive client / script) before assigning blame.
2. **Destination of a "delete" is a fingerprint.** Drive-Trash vs Windows-Recycle-Bin vs unlinked-outright are three different attackers.
3. **Per-agent CWD audit at incident time** belongs in the first 30 minutes of forensic, not the last 30. It would have cleared QUAA-242/243 at hour zero.
4. **Hypothesis updates require new evidence to publish.** v0.1 of this doc was correct to mark Section 3 as `pending QUAA-255/A` rather than asserting the bar*.tmp story; the structure carried the uncertainty correctly.

---

## 4. Why existing guards failed

Two distinct guard-classes were missing: agent-script discipline (would have prevented the *suspected* cause) and Drive-sync-architecture mitigations (would have prevented the *actual* cause). The first class is now closed by the policy doc; the second class is the open architectural risk that QUAA-256 surfaces.

### 4a. Agent-script discipline (defense-in-depth, NOT the proximate cause this time)

| Missing guard | What it would prevent |
|---|---|
| **No path-anchor check.** Scripts could `Remove-Item` with relative paths and `-Recurse` from the calling shell's cwd. | Future incidents where a script *does* touch the repo. |
| **No bulk-delete gate.** A single operation could move 100s of files in one shot with no review. | Future scripted bulk-deletes regardless of cause. |
| **No whitelist.** `.git/`, `CLAUDE.md`, `RECOVERY.md` had no protected status. | Future scripted touches of canonical files. |
| **No mandatory dry-run.** Scripts could go straight to destruction without ever printing the file list. | Future "I didn't realise it would match those" classes. |
| **No agent-side checklist in system prompts.** Agents had no explicit reminder that destructive ops are special. | Future agent-script blind spots. |

These are addressed by `Company/Policy/file_deletion_policy.md` v1 + the HARD RULE block appended to every `system_prompt.md`. They are still worth having even though they were not the proximate cause this time — defense-in-depth.

### 4b. Drive-sync-architecture risk (the actual proximate cause — STILL OPEN)

| Missing guard | What it would prevent |
|---|---|
| **No `.git/` exclusion in Google Drive sync settings.** Drive treats every `.git/` file as independently syncable, conflicting with git's atomic-rename + lock-file semantics. | Drive ever "batch-correcting" the repo by trashing files it considers stale. |
| **No mutex serialising git operations across agents.** Multiple agents commit concurrently; orphaned `index (N).lock` files pile up. | The conflict state that triggered Drive's resolution burst. |
| **No stale-lock-file monitor.** 22 orphaned `index (N).lock` files survived multiple days. | The pre-burst divergence signal. |
| **No agent CWD isolation.** Codex agents work directly in the repo root, multiplying concurrent-write surface. | Concurrent writes from multiple agents to the same `.git/`. |

These are tracked in QA-T's recommendations (Section 8 of `QA_REVIEW_QUAA-256_FORENSIC_REPORT.md`) and are owned by CTO via [QUAA-421](http://localhost:3100/QUAA/issues/QUAA-421) (repo repair) and follow-up architectural work. Until they are closed, the same incident class can recur on the next concurrent-commit storm.

---

## 5. New guard patterns introduced

The single source of truth is `Company/Policy/file_deletion_policy.md` (v1). The 5 rules:

1. Explicit Fabian-OK in chat OR explicit board-approval issue.
2. Glob-pattern dry-run BEFORE the destructive call, with full file list logged.
3. Path-anchor check — never `rm` with relative paths or paths that resolve above the operation scope.
4. Bulk-delete (>20 files in one operation) → automatic pause + board-approval gate.
5. Whitelist of never-deletable paths (`.git/`, `CLAUDE.md`, `RECOVERY.md`, `MEMORY.md`, root `*.md`, `Processes/`, `doc/`, `Company/Policy/`, `Company/Agents/<role>/system_prompt.md`, `Company/Learnings/`).

The 5 rules are restated inline (verbatim) in every agent's `system_prompt.md` HARD RULE section, so agents see the rule even without reading the policy doc.

---

## 6. Recovery procedure

### What Fabian did
1. Detected starvation symptoms (agents idle, dashboard stale, repo broken).
2. Paused Pipeline-Operator + DevOps + Development via Paperclip API to prevent further destructive runs while the cause is unknown.
3. Restored the affected files from Drive Trash (right-click → Restore in the Drive web UI; Drive then re-syncs locally).
4. Opened QUAA-255 + QUAA-255/A (forensics) + QUAA-255/B (this documentation work).

### What is still in progress at the time of this writing
- Drive local-sync of the restored files. As of QUAA-257 checkout at 03:05 UTC, only 4 of 13 `Company/Agents/*/system_prompt.md` are readable on disk; the other 9 directories return `Permission denied` until Drive serves them.
- `.git/` internals re-sync.
- `standalone_aggregator_loop.py` is still emitting `FileNotFoundError` until `Company/TODO.md` is back on disk.

### What un-blocks un-pause of the agents
- This Learnings doc committed to git.
- `Company/Policy/file_deletion_policy.md` committed.
- All 13 `Company/Agents/*/system_prompt.md` patched with the HARD RULE block (currently 4/13; the remaining 9 must be patched once Drive sync completes them on disk).
- Forensic findings from QUAA-255/A appended to Section 3 of this doc.
- CEO clearance given on the parent issue.

### What we should do next time the same thing happens
- Same recovery path (Drive Trash → Restore) as long as we are inside the 30-day window.
- Bring the file-deletion policy in scope of any new agent during onboarding (mandatory-read).
- Treat any agent that triggers a guard violation as auto-paused; require explicit board approval to un-pause.

---

## 7. Open items

- [x] ~~QUAA-255/A: forensic root-cause finalised; appended to Section 3.~~ — **CLOSED 2026-04-20 03:47Z by QA-Tech ([QUAA-256](http://localhost:3100/QUAA/issues/QUAA-256))**. Sections 3 + 3a updated.
- [ ] **[QUAA-421](http://localhost:3100/QUAA/issues/QUAA-421) (CTO):** repair the corrupted `.git/` (HEAD → missing SHA, 25 `index (N).lock` files). P0 — blocks the single commit covering all three deliverables of QUAA-257.
- [ ] **Drive sync** completes and the remaining 9 `Company/Agents/*/system_prompt.md` files re-appear on disk (tracked under QUAA-257). Patched 4/13 in this work; remaining 9 patched once readable.
- [ ] **CTO architectural follow-ups** from QA-T Section 8: (a) `.git/` excluded from Google Drive sync, (b) Paperclip-side per-repo git mutex, (c) stale-`index.lock` monitor + auto-cleanup, (d) Codex agent CWD isolation via worktrees. Each should become its own issue under QUAA-255 once CTO scopes them.
- [ ] Un-pause Pipeline-Operator, DevOps, Development per CEO direction on [QUAA-255](http://localhost:3100/QUAA/issues/QUAA-255) (QA-T cleared all three; no longer gated on this Learnings doc per CEO comment on [QUAA-257](http://localhost:3100/QUAA/issues/QUAA-257) at 2026-04-20 03:54Z).

---

## 8. Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v0.1 | 2026-04-20 03:1xZ | Documentation-KM (QUAA-257 run d7480baf) | Initial draft. Section 3 marked pending QUAA-255/A. Section 6 reflects partial Drive recovery. |
| v0.2 | 2026-04-20 ~04:00Z | Documentation-KM (QUAA-257 follow-up wake) | Section 3 rewritten with QUAA-256 forensic verdict (Drive-sync conflict, not agent script). Section 3a added (hypothesis-vs-forensic divergence). Section 4 split into 4a (script-discipline guards, defense-in-depth) and 4b (Drive-sync architectural guards, still open under [QUAA-421](http://localhost:3100/QUAA/issues/QUAA-421) + CTO follow-ups). Section 7 open-items refreshed against current ticket state. |
