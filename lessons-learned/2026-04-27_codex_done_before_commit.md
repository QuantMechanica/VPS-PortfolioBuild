# Lessons Learned — `done` Before Commit (Codex-class Drift on V5 Framework Build)

**Date:** 2026-04-27
**Phase gate:** Phase 1 (Paperclip Bootstrap) — closing
**Author:** Documentation-KM (QUA-189)
**Reviewer:** CEO + Board Advisor
**Severity:** P0 (Hard Rule violation: "no fantasy numbers — every claim cites a report/log/state entry")
**Cross-references:** [QUA-180](http://localhost:3100/QUA/issues/QUA-180) · [QUA-149](http://localhost:3100/QUA/issues/QUA-149) · QUA-153..QUA-167 · `paperclip-prompts/cto.md` · CTO `AGENTS.md` § "Done criteria" · `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` (L-D-08)

---

## 1. What happened

CTO worked through the V5 framework Implementation Order (`framework/V5_FRAMEWORK_DESIGN.md` § Implementation Order, 25 sequential steps). Steps 1..17 were marked `done` in Paperclip with comments naming the on-disk artifact path (e.g. "Step 11 complete: artifact added at `framework/include/QM/QM_TradeManagement.mqh`"). The artifacts existed on disk.

**The artifacts were not in `git log`.**

CEO discovered the drift at ~11:30 local while preparing the Wave 0 close. `git status --porcelain` returned:

```
?? framework/include/QM/QM_ChartUI.mqh
?? framework/include/QM/QM_Common.mqh
?? framework/include/QM/QM_DSTAware.mqh
?? framework/include/QM/QM_Entry.mqh
?? framework/include/QM/QM_Errors.mqh
?? framework/include/QM/QM_Exit.mqh
?? framework/include/QM/QM_KillSwitch.mqh
?? framework/include/QM/QM_Logger.mqh
?? framework/include/QM/QM_NewsFilter.mqh
?? framework/include/QM/QM_OrderTypes.mqh
?? framework/include/QM/QM_RiskSizer.mqh
?? framework/include/QM/QM_StopRules.mqh
?? framework/include/QM/QM_TradeContext.mqh
?? framework/include/QM/QM_TradeManagement.mqh
?? framework/include/QM_Branding.mqh
?? framework/include/news_rules/
?? framework/tests/
?? decisions/DL-001_v5_framework_review.md
?? decisions/DL-002_pipeline_infra_audit.md
```

15+ "done" deliverables uncommitted at peak. Only `d16d38d framework(step04): add QM_MagicResolver and seed magic registry` was actually in `git log framework/`.

CEO opened **QUA-180 [P0]** — "Commit ALL untracked framework + decisions files; ship per-step commit hashes." CTO ran a single batched commit pass and posted the missing commit hashes back into the per-step issue threads.

---

## 2. Why this matters

Two reasons CEO classified this as P0 (verbatim from QUA-180):

1. **Hard Rule violation.** The CTO Hard Rule list (in `paperclip-prompts/cto.md` and the CTO `AGENTS.md`) includes: *"no fantasy numbers — every claim cites a report/log/state entry."* A `done` status referencing only a filesystem path implies commit. It is not a commit. Anyone reading QUA-153..QUA-164 today and `git log`-ing `framework/` would see only step 04 and conclude the rest is missing.

2. **Drive-sync mass-delete risk (PC1-00).** Until QUA-181 landed (which it did at 11:42 today, *after* this drift was caught), uncommitted artifacts had **zero recovery** if Drive sync re-engaged. The V4 mass-delete incident (`lessons-learned/2026-04-20_mass_delete_incident.md`) is the precedent: 9 of 13 system prompts and large parts of `.git/` were Drive-Trashed in 13 seconds. Any uncommitted file in that window was at risk.

The drift class itself — coding agent marks deliverable `done` with file written but uncommitted — is the V4 L-D-08 pattern (Codex doc/code drift) recurring at the V5 framework-build stage. The V4 lesson predicted it. Phase 1 close caught it cleanly because CEO ran the cross-check before promoting downstream gates.

---

## 3. Root cause

Two converging factors:

**3a. Prompt ambiguity at the time of CTO's first-day work.**

The CTO `AGENTS.md` § "Done criteria" *did* state: *"An issue is `done` when: code merged + EA-vs-Card checklist passed (where applicable) + smoke test green or explicit waiver + commit + comment summary on the issue with links."*

But the same prompt did not insist that **the comment must include the commit hash**. CTO interpreted "commit + comment summary" as separable: artifact written → mark `done` → batch commit later. Plausible reading, wrong outcome.

**3b. No structural commit gate.**

There was no Paperclip-side hook or pre-`done` script that rejected a `done` transition without a commit hash in the close-out comment. The agent could mark `done` purely from issue-thread state. Without enforcement, prompt ambiguity propagated.

---

## 4. The fix

Per CEO direction on QUA-180, going-forward:

> **Any `done` status on a coding deliverable MUST include the commit hash in the close-out comment.**

This is now standard. CEO's "verify before promote" pattern (`git status --porcelain` cross-check before closing gate-level issues) is the verification mechanism.

### What this implies for prompts

- The CTO prompt's "Done criteria" line should be tightened to read: *"committed (commit hash in close-out comment) + comment summary on the issue with links."*
- The Documentation-KM, Pipeline-Operator, Development, and any future coding agent's prompt should adopt the same wording when their deliverable is code or repo-tracked artifacts.
- This change is documented here as a **proposed prompt-level patch** for CTO + OWNER to adopt via DL-NNN. Documentation-KM does not edit `paperclip-prompts/*.md` (boundary respected).

### What this implies for process

- CEO's pre-promote check is added to the process registry (item #5 of QUA-189, blocked on QUA-188).
- If a Paperclip pre-`done` hook becomes feasible later (e.g. agent-side script that calls `git rev-parse HEAD` and posts the hash automatically), DevOps should propose it. Until then, the pattern is human-in-the-loop CEO verification.

---

## 5. Format — Learning → V1 Behavior → V5 Behavior → Why

| Aspect | V1 Behavior | V5 Behavior | Why |
|---|---|---|---|
| Definition of `done` for code | Marked `done` when artifact existed on disk; commit was a "later" step. | `done` requires commit hash in close-out comment; uncommitted files are not `done`. | "No fantasy numbers" Hard Rule. Filesystem path != commit; anyone running `git log` should see the artifact. |
| Promote-to-next-gate verification | Implicit — trust the issue's `done` status. | CEO `git status --porcelain` cross-check before promoting any downstream gate. | The L-D-08 (V4) pattern recurs at every coding agent's first-day work. Catch it once per phase, not after the fact. |
| Recovery surface | Uncommitted files lost outright on Drive-sync incident; only commits survive. | Per QUA-181 mitigation, Drive-sync risk is reduced; per this rule, the work is in `git log` regardless. | Belt and braces: PC1-00 mitigation handles the architectural risk, the commit-hash rule handles the discipline risk. Two independent failure modes need two independent guards. |
| Prompt design for coding agents | "commit + comment summary" — separable, ambiguous on order. | "committed (commit hash in close-out comment) + comment summary" — single requirement, hash is the proof. | Prompt ambiguity becomes behavior; tighten the prompt rather than re-train the agent. (Proposed CTO-prompt patch — to be filed via DL-NNN, not by Doc-KM.) |
| Batch vs incremental commits | Batch at the end of the step block (15+ files at once). | Per-step commit OR batched-with-per-step-references — but each `done` MUST cite its own commit hash. | A 15-file batched commit is fine; the hash on each issue is what matters. The rule is about evidence, not granularity. |

---

## 6. Open follow-ups

- [ ] **CTO + OWNER (via DL-NNN):** Tighten the "Done criteria" line in `paperclip-prompts/cto.md` and other coding-agent prompts to require commit-hash-in-close-out-comment. Documentation-KM does not edit those files; flagging here as a learning-candidate for CTO territory.
- [ ] **Process registry refresh (QUA-189 item #5):** Capture "CEO verifies `git status` before promoting downstream gates" as a standard step. Blocked on QUA-188 (CEO autonomy waiver).
- [ ] **DevOps (future, optional):** Propose a Paperclip pre-`done` hook for coding agents that auto-checks for matching commit-hash references. No issue opened yet; surface once worktree-isolation rollout settles.

---

## 7. Versioning

| Version | Date | Author | Notes |
|---|---|---|---|
| v1.0 | 2026-04-27 | Documentation-KM (QUA-189) | Initial entry. CEO + Board Advisor pending review. |
