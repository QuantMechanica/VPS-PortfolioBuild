# Q02 → Q03 Pump Bug — Live Uncommitted Fix Detected

**Date:** 2026-05-25T18:12Z
**Author:** Claude (4-hourly verification + resolution pass)
**Related task:** agent_tasks.id = `0bf5dc87-dec2-4617-b740-9efb5f1d487d` (priority 90, ops_issue, now in `OPS_FIX_REQUIRED`)
**Related memory:** `project_qm_q02_q03_pump_bug_2026-05-25`

## TL;DR

The Q02 → Q03 cascade bug **is being addressed** by a live, **uncommitted** edit to `tools/strategy_farm/farmctl.py` on the `agents/board-advisor` worktree (`C:\QM\repo`). The fix is real, productive, and visibly draining the strand backlog. It has **no git provenance** — no commit, no stash, not on any branch — so it will be lost the next time something pulls or resets the working tree.

## Evidence the fix is live and working

```
$ git status --short tools/strategy_farm/farmctl.py
 M tools/strategy_farm/farmctl.py

$ stat tools/strategy_farm/farmctl.py
Modify: 2026-05-25 19:32:18 +0200   (= 2026-05-25T17:32Z)
```

SQLite probe (`D:/QM/strategy_farm/state/farm_state.sqlite`) at 2026-05-25T18:08Z:

```
== distinct phase values in work_items ==
Q02 done    1818
Q02 active    10
Q02 pending 1112
Q02 failed   115
Q03 pending  569       <-- previously 0

== tasks parents of Q03 work_items ==
backtest_q03  52     (all tagged "created_by": "p2_pass_promoter")
                    earliest created_at = 2026-05-25T17:27:13+00:00

== stranded Q02-PASS without Q03 sibling (by ea_id+symbol) ==
551    (previously 1493 per memory project_qm_q02_q03_pump_bug_2026-05-25)
```

## What the uncommitted patch does

`git diff tools/strategy_farm/farmctl.py` shows three changes:

1. **`_with_sqlite_write_retry` wrapper** (new helper, lines ~283–297) — wraps maintenance writes in an 8-attempt backoff loop on `sqlite3.OperationalError` "locked". Used to wrap the pump's dispatch maintenance.

2. **Pump §10c (p2_pass_promoter) relaxation** at lines ~6056–6098:
   - Removes the `setfile_path LIKE '%_ablation_%' OR ... '%_grid_%' OR ... '%_synth_%' OR ... '%_freq_%'` filter (base setfiles now eligible too).
   - `LIMIT 500` → `LIMIT 5000` and per-pump cap `10` → `250`.

3. **`backtest_q03` parent task auto-create** at the §10c "no parent" branch (replaces `continue`):
   ```python
   parent_id = create_task(
       conn, kind="backtest_q03", source_id=None, card_id=wi["ea_id"],
       payload={"ea_id": wi["ea_id"], "phase": "Q03", "created_by": "p2_pass_promoter"},
   )
   parent = conn.execute("SELECT id, status FROM tasks WHERE id=?", (parent_id,)).fetchone()
   ```

The original priority-90 patch sketch (memory `project_qm_q02_q03_pump_bug_2026-05-25`) proposed extending `next_map` (farmctl.py:3251), `next_phase_map` (farmctl.py:7882), and `cascade_phase_map` (farmctl.py:6152). **The live fix takes a different path** — it makes §10c self-sufficient by having it create the parent it needs. Functionally equivalent for the user-visible problem (Q03 work_items now being created from Q02 PASS). The three dict literals on `origin/main` are unchanged.

## What is needed to close

1. **Identify provenance.** No commit, no stash, not on any branch introduces `p2_pass_promoter`. File mtime ≈ 2026-05-25T17:32Z. Possibly Codex direct disk edit outside the orchestration loop; possibly OWNER on-host edit.
2. **Commit with explicit pathspec.** The working tree on `agents/board-advisor` has ~1547 dirty files (mostly EA recompiles + bulk setfile regen from unrelated workstreams). Use `git commit -- tools/strategy_farm/farmctl.py` to capture **only** the pump fix; do not stage anything else.
3. **OWNER decision** whether the original cascade-map extension is still wanted in addition (the §10c path is sufficient for now; the map extension would be a cleaner architecture but is no longer urgent).
4. **Once committed and merged to `origin/main`:** transition task `0bf5dc87-dec2-4617-b740-9efb5f1d487d` from `OPS_FIX_REQUIRED` → `PASSED` with the merge commit hash as the verdict citation.

## Other notes for OWNER

- Orchestration loop (`agents/claude-orchestration-{1,2,3}`) has flagged this task as "UNASSIGNED FOURTEENTH CYCLE" with the diagnosis "capability-mismatch" — that diagnosis is now moot (fix is already deployed).
- `farmctl health` still reports `p_pass_stagnation FAIL 0 P3+ PASS in 12h` and `p2_pass_no_p3=127` — these will not clear until Q03 work_items start completing and propagating downstream. Expected to begin draining within the next 1–2 pump cycles.
- The 551 Q02-PASS still without a Q03 sibling will be picked up at 250/cycle by the live patch; full drain ≈ 2–3 cycles.
- Stranded count is real evidence; do NOT manually `enqueue-backtest` Q03 in parallel, that risks duplicate parents.
