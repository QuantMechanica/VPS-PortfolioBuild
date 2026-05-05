---
name: DL-058 — No recovery issue for Paperclip state drift
description: When Paperclip auto-resume flips a `done` issue back to `in_progress`/`todo`/`in_review`, agents MUST NOT file a recovery issue. Re-PATCH the original issue with one drift-correction comment. The recovery-of-recovery cascade pattern is what filled the queue with 700+ entries by 2026-05-05.
type: decision-log
authority: OWNER 2026-05-05 — proposed by Board Advisor in QUA-737, adopted by CEO as R-046-6 in CEO AGENTS.md, ratified company-wide as DL-058.
date: 2026-05-05
supersedes: nothing — extension of DL-046 (anti-theater meta-work purge)
related: DL-046, QUA-737, QUA-714, QUA-732, QUA-733, QUA-735, QUA-736
---

## The rule (binding for all agents)

**When Paperclip's auto-resume / checkout / status-machine flips a `done` (or `cancelled`) issue back to `in_progress` / `todo` / `in_review`, you MUST:**

1. Re-PATCH the original issue back to its terminal status (`done` or `cancelled`).
2. Post EXACTLY ONE one-line comment: `drift correction: status was already <terminal> at <commit hash or ISO timestamp or evidence path>`.
3. Stop. No new issues. No subtasks. No "recovery" sub-issue.

That's it. One mutation per drift, one comment, end of story.

## What this rule replaces

Before DL-058 (i.e. up to 2026-05-05), the observed pattern was:

1. Issue X marked `done`.
2. Paperclip auto-resume drift flips X back to `in_progress`.
3. Agent A files "QUA-Y: recover stalled issue X".
4. Agent A also files a recovery-evidence sub-issue.
5. Agent B picks up QUA-Y, starts a sub-investigation, files QUA-Z.
6. Result: 1 piece of real work spawned 4-8 meta-issues. None advance the pipeline.

Receipts (sample, 2026-05-05):
- QUA-731 (Step 5 DL-054 splice) → drifted → QUA-733 (recovery) → drifted → QUA-735 (sub-recovery) → QUA-736 (QT cleanup).
- QUA-714 ("Recover stalled issue QUA-662").
- QUA-684 (phantom-PASS recovery meta) → drifted → re-opened multiple times.

By 2026-05-05 18:00Z: **112 active issues**, **28 in `in_review` limbo**, **5+ explicit "recover stalled" issues**. Pipeline-Op spent multiple heartbeats doing state-correction on QUA-736 and zero seconds dispatching. CEO spent multiple heartbeats acknowledging closures of recovery issues.

## Why state drift happens (so you understand what to ignore)

Paperclip's checkout / heartbeat handshake re-opens an issue when:

- An agent's run starts a fresh codex session and reads the issue's pre-PATCH state from cache.
- The auto-resume cron runs against an in-flight `expectedStatuses` filter that includes terminal statuses.
- Concurrent agents both observe an issue mid-transition and one writes a stale view back.

These are infrastructure artifacts, not new work. The status-machine churn is not a signal that the EA needs more code, the gate needs more enforcement, or QT needs another sign-off. It is a signal that Paperclip serialised its event stream out of order.

## What is still a legitimate recovery issue

DL-058 does NOT forbid recovery issues. It forbids them for **status drift only**. Legitimate recovery issues remain required when:

- A real production incident occurred (T6 trade rejected, MT5 tester crashed mid-run, dispatch_state.json corrupted on disk).
- A contract was broken (an EA produced phantom-PASS, a gate was bypassed, a setfile was wrong).
- An artifact is genuinely missing and blocking downstream work (report.htm not produced, .hcc data incomplete for a symbol — see QM-00006xx series for the data import gap).
- An agent is stuck in a loop OWNER cannot break without a board-pause (DL-046 / QUA-702 escalation pattern).

The test: would a clean fresh-eyes engineer reading the queue tomorrow be able to act on this issue? If yes, file it. If the issue title is "recover stalled X" or "drift correction for Y" or similar status-machine commentary, do NOT file it.

## Enforcement

- **CEO** verifies on each heartbeat that no new recovery-of-status-drift issues were created in the prior heartbeat. If CEO observes one, CEO PATCHes it to `cancelled` with `drift_correction_violation` reason and posts one comment pointing the offending agent at DL-058.
- **Pipeline-Op, CTO, Development, Doc-KM, DevOps, QT, QB, CoS** apply the rule directly per their AGENTS.md (already updated for CEO + Pipeline-Op + CTO 2026-05-05; remaining agents adopt on next BASIS refresh).
- **Board Advisor** writes the DL (this file), monitors the active in_review count, and will mass-resolve cascade artifacts down to ≤5 per QUA-737 acceptance.

## Acceptance criteria for "the rule worked"

Measured 2026-05-12 (one week after adoption):

- Active in_review count ≤ 10 (vs 28 today)
- Total active issues ≤ 50 (vs 112 today)
- Zero new issues in the prior week with title matching `^(recover|drift|stall|stalled|state[-_ ]?correction)` regex
- CEO heartbeats no longer mention "drift correction" as a tracked agenda item

If those four hold, DL-058 is working. If not, escalate back to OWNER for revision.

## Implementation receipts

- 2026-05-05T18:30Z: Board Advisor proposed via [QUA-737](http://127.0.0.1:3100/api/issues/a6a79b9f-60e9-4c22-afe7-4d8c6f4bee9f) (full body in first comment).
- 2026-05-05T~18:35Z: CEO adopted in own AGENTS.md as R-046-6 ("Pending company-wide ratification via DL-058").
- 2026-05-05T17:14Z: Board Advisor authored this DL (Nummer 5 per OWNER directive).
- TODO: CTO + Pipeline-Op + Doc-KM mirror the rule in their respective AGENTS.md on next BASIS refresh.
- TODO: CEO drives the in_review limbo cleanup as part of QUA-737 closure.
