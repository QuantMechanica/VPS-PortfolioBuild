# Process Registry

## Factory Setup Standards

- MT5 factory terminals `T1`-`T5` must include an install-root `portable.txt` marker file (empty file) to prevent AppData split-brain when launched without explicit `/portable`.

## Concurrent-Write Discipline / Worktree Isolation

Canonical decision: [DL-028](../decisions/DL-028_per_agent_worktree_isolation.md). Narrative source of record: [`lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md`](../lessons-learned/2026-04-27_pc1-00_live_incident_qua-167.md).

- Agents writing to `framework/`, `infra/`, or any other path under concurrent multi-agent write contention run from `C:\QM\worktrees\<agent-key>\` on branch `agents/<agent-key>`, **not** from the shared `C:\QM\repo\` root.
- All `git add` / `git commit` / `git push` on `C:\QM\repo\` go through `infra/scripts/Invoke-GitWithMutex.ps1` (Windows named mutex serializes across worktrees).
- Stale `index.lock` files older than 20 min are surfaced by scheduled task `QM_GitIndexLockMonitor_10min` (every 10 min); see `infra/monitoring/Invoke-GitIndexLockMonitor.ps1`.
- Worktree creation/repair is idempotent via `infra/scripts/Ensure-AgentWorktree.ps1`.
- Race detection: if an agent observes mid-edit on-disk drift, it **safety-stops** and posts an issue comment offering merge / use-existing / overwrite options (Stop-digging Hard Rule).

Out of scope for this rule: `T6_Live` (governed by DL-025 + `CLAUDE.md` § Hard Boundaries) and `paperclip-prompts/*.md` (OWNER-managed; agent prompts are Git-canonical). Exceptions to the worktree rule require a successor DL-NNN.

## Strategy Research Workflow

Canonical spec: [13-strategy-research.md](13-strategy-research.md). Parent directive: QUA-236 (OWNER 2026-04-27).

- Source → Strategy → Pipeline issue tree is binding. One parent per resource (`SRC<NN> — <citation>`); one sub-issue per strategy (`SRC<NN>_S<n> — <slug>`). First sub `todo`, rest `blocked`. Next sub unblocks only when the prior closes with a ready-or-killed verdict (P1 → P8 + Quality-Tech sign-off).
- One source actively worked at a time; one strategy from that source actively worked at a time. No parallel-source extraction.
- Strategy Cards live at `strategy-seeds/cards/<slug>_card.md` (slug allocated at extraction time; `ea_id` allocated at APPROVED → IN_BUILD). Card schema: `strategy-seeds/cards/_TEMPLATE.md` with mandatory fields `source_citations: []`, `strategy_type_flags: []`, and a `framework_alignment` section.
- Strategy-type vocabulary is mined from V4 (`strategy-seeds/strategy_type_flags.md` under QUA-244). No new flags invented in V5.
- Same-source enhancement via in-pipeline learning = `_v2` of same card (new row in § 13 Pipeline History). Different-source enhancement = new sub-issue under the new source's parent, new card. The test is *where the insight came from*.

## EA Enhancement Loop (`_v<n>` versioning)

Canonical spec: [14-ea-enhancement-loop.md](14-ea-enhancement-loop.md). Parent directive: QUA-236; authored under QUA-245.

- Trigger list is **closed**: (a) zero-trades backtest report = automatic send-back to Development; (b) "must re-test from P1" failures — input-rule change, parameter-set change beyond declared sweep bounds, news-mode change. Any other rebuild candidate escalates to CEO + CTO before `_v<n>` is created.
- Sweep selections within P3 bounds, re-runs at the same gate, and multi-seed variance checks are **not** enhancements — they continue under the existing version row.
- File versioning: EA build gains `_v2`, `_v3`, ... suffix (e.g. `QM5_NNNN_<slug>_v2.mq5`); `slug` and `ea_id` are stable across versions; magic-number rows do not change.
- `_v<n>` is treated as a NEW EA for backtesting: it re-runs P1 → P8 from scratch, no metric carry-forward from `_v<n-1>`.
- Card stays canonical at `strategy-seeds/cards/<slug>_card.md` (no `_v2` card files). Each version appends a `### v<n>` block to the card's § 13 Pipeline History, headed with the trigger.
- Only one version live at a time — `_v<n>` supersedes `_v<n-1>` at L7 → L8 promotion.

## Pipeline-Operator Load Balancing (T1-T5)

Canonical spec: [15-pipeline-op-load-balancing.md](15-pipeline-op-load-balancing.md). Parent directive: QUA-236; authored under QUA-246.

- Allocation policy: **least-loaded round-robin with symbol-affinity tie-break** across `T1`-`T5`. One active scanner per terminal max. `T6` is out of write scope.
- De-dup contract is binding: tuple `(ea_id, version, symbol, phase, sub_gate_config)` is **never** executed twice. Registry table at `D:\QM\reports\state\factory_run_dedup_v1.csv` with lock file at `factory_run_dedup_v1.lock`. Any rerun must change the `sub_gate_config` digest (e.g. CTO-approved `retry_tag`) producing a new tuple.
- Queue ledger (append-only): `D:\QM\reports\state\factory_run_queue_v1.jsonl`; dispatch state snapshot: `factory_dispatch_state_v1.json`. Flow: enqueue → preflight de-dup → claim → start → ack; failed/no-report/aborted states close the tuple (no silent re-queue under same tuple).
- Per-run evidence root: `D:\QM\reports\factory_runs\<ea_id>\<version>\<phase>\<symbol>\<run_key>\` with `dispatch.json`, `runner_stdout.log`, `runner_stderr.log`, `pid_snapshot.json`, `report_manifest.json`, `ack.json`.
- Disk policy: `>80 GB` free for normal operation; `<60 GB` is immediate CEO escalation. `NO_REPORT > 30%` per cohort is immediate CEO escalation.
- Filesystem-truth reconciliation runs before any stall/dead-EA claim; tracker JSON is advisory.
- Post-restart verification gate (state file readable, PIDs match live, T2/T3 script paths aligned, owner-overrides validated from file) must pass before resuming heartbeat work.
