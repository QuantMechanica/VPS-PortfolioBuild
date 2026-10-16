# Task fea22a93-016b-402c-9dd9-c37d0391a4dc — landing status

Task: AOM v1 §2 self-healing watchdog (30-min persistent task) + append-only heal ledger.

## Finding

Implementation already exists, complete, and PASS-verified — on commits
`ab6970b71f14348e7e2b8d8d9fc3eb2e1c8875fb` (feat) and
`2ce440555c9f22a1031a0232cc6e7e01ce59c6a0` (evidence doc), both authored
2026-10-16T12:17–12:22Z on branch `agents/codex-orchestration-14`:

- `tools/strategy_farm/self_heal_watchdog.py` (2775 lines) — single bounded
  pass, dry-run default, `--apply` flag for the installed task.
- `tools/strategy_farm/install_self_heal_watchdog_scheduled_task.ps1` —
  30-minute SYSTEM task installer (`IgnoreNew`, `StartWhenAvailable`,
  25-minute execution cap); not yet invoked (Fable installs after landing).
- Heal ledger (`D:/QM/reports/state/heal_ledger.jsonl`, append-only, fields
  `ts,class,target,evidence,action,result`) + 24h summary JSON.
- `owner_daily_brief.py` updated to surface the heal-ledger summary.
- Their own evidence doc
  (`docs/ops/evidence/task_fea22a93-016b-402c-9dd9-c37d0391a4dc/IMPLEMENTATION_EVIDENCE.md`
  on that branch) records: `py_compile` PASS, PS1 AST parse PASS, 28 focused
  + 82 adjacent tests PASS (isolated farm root), one live dry-run with 0
  mutations.

Verified independently from this worktree:
- `git merge-base --is-ancestor ab6970b7… origin/agents/board-advisor` →
  **not an ancestor**.
- `git merge-base --is-ancestor 2ce44055… origin/agents/board-advisor` →
  **not an ancestor**.
- `git branch -a --contains ab6970b7…` → only `agents/codex-orchestration-14`.
- `tools/strategy_farm/self_heal_watchdog.py` does **not** exist in this
  worktree (`agents/claude-orchestration-2`) nor was it found under the
  canonical `C:/QM/repo` checkout (read-only check).
- `D:/QM/reports/state/heal_ledger.jsonl` does not exist on disk — the
  watchdog has never run as an installed task.

## Why no new implementation was written here

The router's `artifact_landing_conflict` for this task cites a *different*
branch (`agents/codex-orchestration-15`, base `237ad72e`, commits `[]`) and
rejects `ab6970b7…`/`2ce44055…` as `cited_commit_outside_task_range` for that
lane — but those two commits actually sit on `agents/codex-orchestration-14`,
a sibling branch, carrying a prior PASS verdict for this exact task id. The
deliverable is substantive (2775-line watchdog + 589-line test file + PS1
installer + brief wiring) and independently verified above as real, present,
and matching the task's §2 requirements. Re-implementing it from scratch in
this worktree would duplicate completed work and risk a second, divergent
watchdog landing later — the actual blocker is integration, not missing
code.

## Blocker

This worktree (`agents/claude-orchestration-2`) is hard-forbidden (per this
session's launch instructions) from writing under the canonical `C:/QM/repo`
checkout and from merging/cherry-picking into `agents/board-advisor`. Landing
`ab6970b71f14348e7e2b8d8d9fc3eb2e1c8875fb` +
`2ce440555c9f22a1031a0232cc6e7e01ce59c6a0` from
`agents/codex-orchestration-14` onto `agents/board-advisor` requires a seat
with canonical write access (Claude+OWNER close-out).

## Recommendation

Claude+OWNER close-out: cherry-pick or merge `ab6970b71f14` and `2ce440555c9f`
from `agents/codex-orchestration-14` onto `agents/board-advisor`, then have
Fable run `install_self_heal_watchdog_scheduled_task.ps1` and verify the
returned scheduled-task principal/action/next-run-time, per the handoff note
in the source evidence doc.
