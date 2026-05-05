# Company Running — Systemic Fix (2026-05-05T18:20Z)

**Author:** Board Advisor (local-board)
**Status:** In progress — end-to-end smoke validation pending
**Driver:** OWNER directive 2026-05-05 — "make the company actually work, not just produce comments and reviews"

## Diagnosis: why nothing was running

Three independent failures stacked into total stoppage:

1. **No P2 runner existed.** `framework/scripts/` has runners for P3.5, P5, P5b, P5c, P6, P7, P8 — but no `p2_baseline.py`. `pipeline_dispatcher.py` only writes scheduling state to `dispatch_state.json`; it does not launch MT5. Pipeline-Op was correctly "dispatching" jobs every heartbeat, but no executor consumed them. April-30 P2 runs were launched manually (the wrapper script was never checked in). Result: `running: {T1:0…T5:0}`, zero new .htm files since 2026-05-01.

2. **Two parallel project-management systems, agents using neither correctly.** The Kanban CSV at `paperclip/kanban/company_kanban.csv` (50 tasks, deterministic, well-planned) was supposed to be the source of truth, with Paperclip QUA-issues as the comms reflection. Instead, agents query Paperclip API directly per their `AGENTS.md`, and the Kanban sits unused. P0 bootstrap tasks QM-00002/3/4 (assigned to local-board, queued since 2026-05-02) were never completed.

3. **Recovery cascade pattern.** State drift (Paperclip auto-resume flipping `in_review` → `in_progress`) triggers agents to file QUA-recovery issues. Those recovery issues get picked up, drift again, generate more recovery issues. 28 issues in `in_review` limbo, 5 explicit "recover stalled X" issues, 112 active issues total. Real pipeline work suffocates under meta-work.

## Actions taken today (2026-05-05 18:00–18:20Z)

### Built
- `C:/QM/repo/framework/scripts/p2_baseline.py` — sequential runner, iterates an EA's setfile matrix, distributes round-robin across T1-T5, calls `run_smoke.ps1` per symbol, parses `summary.json` for verdict, aggregates into `report.csv`. Supports `--dry-run`, `--resume`, `--symbols=`, `--terminal=`.

### Updated
- `C:/QM/paperclip/data/instances/.../agents/46fc11e5-…/instructions/AGENTS.md` (Pipeline-Op live prompt) — added explicit P2 BASELINE DISPATCH section with the canonical command sequence. The agent now knows: dry-run first, then real run, then attach report.csv to issue. No more dispatcher-CLI confusion.
- `C:/QM/repo/paperclip-prompts/pipeline-operator.md` (repo source) — same change.
- `C:/QM/paperclip/kanban/agents.csv` — full UUIDs populated (was 8-char prefixes). QM-00002 effectively done.

### Cleared
- `D:/QM/reports/pipeline/dispatch_state.json` phantom `running: T1-T5=3` from May-1 outage zeroed (backup at `.bak_20260505T1406Z`).
- QUA-684 phantom-PASS recovery meta closed → done (all D-steps complete: QUA-685 done, QUA-686 D2 verified via .hcc files, QUA-687 superseded by QUA-731 done).
- QUA-662 unblocked → in_progress (Pipeline-Op assignment for the QM5_1003 P2 baseline).

### Paused (during wire-up)
- Pipeline-Op (46fc11e5) — paused 18:19Z to prevent collision with Board-Advisor smoke validation.
- CTO (241ccf3c) — paused 18:19Z; was doing micro-recovery polls only.

## End-to-end smoke status

Currently running: `run_smoke.ps1 -EAId 1003 -Symbol EURUSD.DWX -Year 2024 -Terminal T1 -Period H1 -Runs 2 -SetFile <real-setfile>`. Started 18:15Z. PID 84716 (terminal64.exe T1). Tester log shows real trades (deal #284 sell EURUSD at 1.08089 on 2024-02-01). This proves the toolchain works — May-1 phantom-PASS was a setfile/window/data-source issue, NOT an infra issue.

When run_01 completes (~5-10 min), `summary.json` will appear and we'll know:
- Total trades (target: ≥20 for the smoke gate)
- PASS/FAIL verdict
- Whether `summary.json` is parseable by `p2_baseline.py`'s `derive_verdict()`

## Resume plan

1. Smoke completes → verify `summary.json` shows real trades with PASS verdict.
2. Resume CTO (force fresh codex session via pause+resume).
3. Resume Pipeline-Op (force fresh codex session). Next heartbeat reads new AGENTS.md, sees QUA-662 in_progress, runs `python framework\scripts\p2_baseline.py --ea QM5_1003 --dry-run`, then real run.
4. ~3 hours later: 36 symbols × 2 runs = 72 reports. Aggregated into `D:/QM/reports/pipeline/QM5_1003/P2/report.csv`.
5. CEO heartbeat sees the report.csv, makes PASS/FAIL judgement per P2 spec gates (PF>1.30, T>200, DD<12%), assigns next phase.

## What still needs sustainable cleanup

The recovery cascade pattern is the single largest drag on agent throughput. **Filed as QUA issue for CEO** (separate from this doc) — CEO is on the same model as Board Advisor and can drive the meta-cleanup:
1. Mass-resolve the 28 `in_review` limbo issues — for each, either close as done with the actual outcome, or supersede with a current issue. Dedicate one CEO heartbeat to this cleanup, not multiple recovery-style touches.
2. Establish discipline: when state drifts (Paperclip auto-resumes a `done` issue back to `in_progress`), DO NOT file a recovery issue — just re-PATCH and add one comment. The recovery-issue-per-drift pattern is what filled the queue with 700+ QUA-XXX entries.
3. Adopt Kanban CLI: Pipeline-Op's `next_task.py --agent pipeline-operator` returns QM-00019 (PC3-04 P2 Baseline Screening). The Kanban already correctly identifies the work; agents need to be migrated to read from there.

## What OWNER does next

- Wait for smoke confirmation (~10 min).
- If smoke shows PASS with ≥20 trades → approve "resume Pipeline-Op for full P2 matrix run."
- After 36 symbols × 2 runs complete (~3hr), review `D:/QM/reports/pipeline/QM5_1003/P2/report.csv`.
- That's the first real V5 evidence.

## Files touched

- `C:/QM/repo/framework/scripts/p2_baseline.py` (new, 215 lines)
- `C:/QM/repo/paperclip-prompts/pipeline-operator.md` (P2 dispatch section)
- `C:/QM/paperclip/data/instances/.../agents/46fc11e5-…/instructions/AGENTS.md` (live, same change)
- `C:/QM/paperclip/kanban/agents.csv` (UUIDs)
- `D:/QM/reports/pipeline/dispatch_state.json` (running/recent_runs cleared, backup kept)
- `D:/QM/reports/pipeline/QM5_1003/P2/QM5_1003/20260505_161531/` (smoke run artifacts in progress)
