# File-Deletion Policy (v1, 2026-04-20)

**Owner:** Documentation-KM (single writer) — proposed changes via PR + CEO ratification.
**Authority source:** Incident QUAA-255 (mass-delete event 2026-04-20 00:33 CEST).
**Audience:** Every Paperclip agent, every CLI session, every script that may invoke a destructive filesystem operation on `G:\Meine Ablage\QuantMechanica\`.

> **Note on scope (added 2026-04-20 post-QUAA-256 forensic):** the QUAA-255 incident itself was caused by a **Google-Drive-sync conflict triggered by concurrent multi-agent git writes**, not by an agent script — both initially suspected scripts (QUAA-242, QUAA-243) were forensically cleared in [QUAA-256](http://localhost:3100/QUAA/issues/QUAA-256). This policy is therefore **defense-in-depth against a different failure class** (agent / script bugs that *would* delete repo files), not a fix for the proximate cause. The proximate-cause architectural fixes are tracked under [QUAA-421](http://localhost:3100/QUAA/issues/QUAA-421) and CTO's follow-up work (Drive `.git/` exclusion, per-repo git mutex, stale-lock monitor, agent CWD isolation). Both layers matter; this document owns the script-discipline layer.

---

## The 5 Hard Rules

Destructive filesystem operations on `G:\Meine Ablage\QuantMechanica\` (move-to-recycle-bin, `rm`, `Remove-Item`, `git clean`, `git rm -rf`, `git checkout -- .` over many files, batch delete via Drive API, etc.) require **all** of the following:

1. **Explicit Fabian-OK in chat OR a board-approval issue.**
   Implicit authority from "do whatever you need" is not enough. The chat / issue must name the operation and the rough scope (e.g., "yes, delete `MQL5/Files/Tester/bar*.tmp` over 1 GB").

2. **Glob-pattern dry-run BEFORE the destructive call, with the full file-list logged.**
   Examples:
   - PowerShell: `Get-ChildItem -Path X -Recurse -Filter Y | Select-Object FullName | Out-File deletion_dryrun_<ts>.txt`
   - Bash: `find X -name 'Y' -print > deletion_dryrun_<ts>.txt`
   The agent must read the dry-run output and confirm it matches expectation before proceeding.

3. **Path-anchor check: NEVER `rm` with relative paths or paths that resolve above the operation scope.**
   - Always use absolute paths anchored at the operation root.
   - If the script is meant to clean `MQL5/Files/Tester/`, the loop must `cd` (or anchor) inside `MQL5/Files/Tester/` and the wildcard must NOT be allowed to walk up via `..` or unintended `-Recurse`.
   - Example bug class (the one that caused QUAA-255): `Get-ChildItem -Path . -Recurse -Filter bar*.tmp | Remove-Item` executed from a path that was higher in the tree than intended → wildcard matched files in the repo root and trashed them.

4. **Bulk-delete gate: any single operation that targets >20 files triggers an automatic pause + board-approval gate.**
   - The agent must comment on the source issue with: `BULK_DELETE_GATE: <count> files matched, dry-run at <path>, awaiting board approval`.
   - The agent does NOT proceed until a board approval lands (or a CEO comment explicitly waives the gate for this run).
   - Time-bound waivers: a waiver is good for one run / one heartbeat only. The next run re-triggers the gate.

5. **Whitelist / never-deletable paths.**
   The following are NEVER deletable by any agent under any condition (not by `rm`, not by `git rm`, not by `Remove-Item`, not by Drive API):
   - `.git/` and any sub-path inside it
   - `CLAUDE.md` (root contract)
   - `RECOVERY.md` (session-start guide)
   - `MEMORY.md` and any file inside `memory/` (auto-memory store)
   - All other root-level `*.md` files (`HANDOFF.md`, `README.md`, etc.)
   - `Processes/` (process-landscape HTML + sources)
   - `doc/` (canonical documentation)
   - `Company/Policy/` (this policy and its successors)
   - `Company/Agents/<role>/system_prompt.md` (every agent's checked-in source-of-truth prompt)
   - `Company/Learnings/` (post-mortem corpus)

   If a script appears to be about to touch one of these paths, the script must abort with a non-zero exit code and emit a clear error.

---

## Enforcement guidance

### For Paperclip agents (claude_local / codex_local)

- The 5 rules are restated in every agent's `system_prompt.md` HARD RULE section. The agent reads this on every fresh activation. There is no excuse for not knowing the rule.
- If an agent is asked to perform a destructive operation, the agent must:
  1. Confirm the operation is in scope of the current task and that explicit authority exists (chat/issue link).
  2. Produce a dry-run.
  3. Check the path anchor.
  4. If >20 files: open the bulk-delete gate, stop, await approval.
  5. Check whitelist; abort if any whitelisted path matches.
  6. Only then run the destructive call, and log the post-deletion state.
- Failure to follow this protocol is a P0 incident that pauses the offending agent until CEO clearance.

### For CLI sessions / human-driven scripts

- Apply the same rules. Human convenience does not override them.
- Prefer reversible operations: `Move-Item` to a quarantine dir over `Remove-Item -Force`. Drive Trash retention is 30 days but is not a substitute for not deleting.

### For automation scripts under version control

- Any script in `Company/scripts/`, `Tools/`, or similar that performs a destructive operation must:
  - Anchor every wildcard with an absolute base path.
  - Never use `-Recurse` from a directory higher than the intended target.
  - Print the file list before deletion and require an `--apply` flag (default = dry-run).
  - Refuse to run if the resolved path matches any whitelist entry.

---

## Post-incident review schedule

- The policy is reviewed after every incident that touches the filesystem, even if no deletions occurred.
- Quarterly: Documentation-KM scans `Company/scripts/` and `Tools/` for new scripts that may need to be brought under the policy and lists them in `Company/Learnings/`.

## Versioning

| Version | Date | Changes |
|---|---|---|
| v1 | 2026-04-20 03:1xZ | Initial draft post incident QUAA-255. 5 rules, whitelist, enforcement guidance. |
| v1.1 | 2026-04-20 ~04:00Z | Preface scope-note added to clarify this policy is defense-in-depth: QUAA-256 forensic established the QUAA-255 proximate cause was Google-Drive sync conflict on `.git/`, not an agent script. Pointer to QUAA-421 / CTO follow-up work for the architectural fixes. No rule changes. |
