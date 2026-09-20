# QM5_41155 uncommitted source drift — review (task 7ab3e9d3-e70a-4d13-a792-86b6fe035024)

## Author lane — identified

Not an unattributed edit. The preserved `working_tree.patch` is the direct output of a
governed, tracked build/rework task run by **Codex** under the `qm-build-ea-from-card`
skill, in "CODEX REVIEW FAIL REWORK MODE":

- `tasks` table row `e8e61fe1-2589-4f97-adb7-7de16892f9e4` (kind=`build_ea`, card_id=`QM5_41155`, **status still `pending`**).
- Responding to `codex_review` task `9458b037-f47f-426f-a4d1-0962cdad8cd1` (verdict FAIL,
  reviewed 2026-08-29T23:02Z), finding: *"File-scope `g_last_exit_completed_bar` and raw
  `iTime` D1 timestamp checks reimplement exit new-bar gating at lines 58 and 459-462; use
  the framework calendar/new-bar helpers."*
- Rework prompt constraint: "Prefer the smallest source change that satisfies the review
  finding" — do not create a new EA id/dir, keep existing setfiles unless the fix requires
  regen.
- Log evidence: `D:\QM\strategy_farm\logs\codex_build_e8e61fe1-2589-4f97-adb7-7de16892f9e4.live.attempt_1.log`
  (first attempt, wrote `.mq5` at ~2026-09-20T09:02-09:05Z — this is the drift Fable found
  and reverted) and `...live.log` (second attempt, `build_dispatch.pid=7600`,
  `started_at=2026-09-20T15:36:05Z`).

The reason this looked unattributed: `build_ea`/rework tasks live in the dispatcher's
`tasks` table, not `agent_tasks` (the router state machine health checks and prior audits
query). No misconduct — just a blind spot in that audit's table choice.

## Judged against the card

Card `QM5_41155_gbpjpy-carry-unwind-crisis-momentum.md` (G0 APPROVED, source
BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008) specifies entry/exit/stop mechanically; the
exit leg is "N completed D1 bars held, or completed close above the 20-bar channel
midpoint." The refactor only changes *how* the once-per-completed-bar gate is implemented
(framework-corset compliance), not the card's economics:

- Removes `g_last_exit_completed_bar` + raw `iTime` gating (the cited violation) —
  **correct fix**, directly responsive to the review finding, matches the pattern already
  committed in sibling EA `QM5_41140_nzdjpy-carry-unwind-crisis-momentum.mq5:473`
  (`QM_IsNewCalendarPeriod(PERIOD_D1, _Symbol)`).
- Side effect: dropped the `signal_time` parameter from `Strategy_ChannelMidpoint` and
  weakened `rates[0].time != signal_time` to `rates[0].time <= 0` — a minor, unreviewed
  loss of a bar-freshness consistency check that every sibling in this family retains
  (`QM5_41140` keeps `signal_time` and the full equality check). Not economically
  significant (CopyRates shift=1 already returns the latest completed bar), but it is scope
  creep beyond "smallest change for the cited finding" and should be called out to Codex if
  a future rework attempt is scoped again.

**Neither attempt ever reached `build_check` PASS.** Both attempt 1 (09:05Z) and attempt 2
(15:41Z, see below) compiled clean (`compile_one.result=PASS errors=0`) but failed
`build_check` on `EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX` (hardcoded GBPJPY/AUDJPY/NZDJPY/
CADJPY/EURJPY symbol literals) — a **pre-existing** defect unrelated to the cited exit-gate
finding, and out of scope for a rework prompt that says "smallest change that satisfies the
review finding." The rework can never converge without a separately-scoped fix for the
symbol-literal issue.

## Live recurrence found during this review (new finding, not in the original evidence)

The canonical checkout was dirty **again** at review time — a second, different rework
attempt, not a repeat of the first:

- `tasks.e8e61fe1-2589-4f97-adb7-7de16892f9e4.payload_json.build_dispatch`:
  `agent=codex, pid=7600, started_at=2026-09-20T15:36:05Z, build_generation=1,
  attempt_count=2, lease_id=32224c42f74e4279b53d0b62481fc8ca`.
- Same 4 files dirty (`.mq5`, `.ex5`, 2 `.set` files). Diff preserved at
  `recurrence2_working_tree.patch` in this directory before restoring.
- **Different implementation** than attempt 1: instead of calling the framework helper
  `QM_IsNewCalendarPeriod`, attempt 2 hand-rolls the same pattern one layer down
  (`static int processed_exit_key` + `QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0)`) — which
  reproduces almost exactly the "per-EA calendar reimplementation" anti-pattern the
  original review finding objected to. This variant would likely fail `framework_corset`
  review again.
- Result: `build_check_passed=false`, same `EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX`
  failure as attempt 1 — confirms this is a **structural non-convergence loop**, not two
  independent incidents.
- `tasks` row status is still `pending` after both failed attempts — nothing marks this
  `build_ea` task done/blocked, so it is eligible to be redispatched again and will very
  likely reproduce a third dirty working tree and re-trip `repo_dirty_build_guard`
  (the first occurrence blocked it for 6h / 86 pending builds per the original README).

Root cause: the rework flow (a) scopes its fix strictly to the cited review finding, but
(b) `build_check` re-runs the full strict gate set including unrelated pre-existing
violations, so the task can structurally never reach PASS; and (c) nothing reverts the
working tree in the canonical checkout when a rework attempt's `build_check` fails, so a
failed attempt leaves dirty source sitting in `C:/QM/repo` until someone notices.

## Disposition

- **Original preserved patch (`working_tree.patch`): DISCARDED.** Reason: never reached a
  governed `build_check` PASS; superseded by a materially different second attempt from the
  live build/rework task before this review completed. Re-applying it via an agents/*
  worktree + source-repair authority would just recreate a stale, already-superseded
  variant — no value, and it still wouldn't compile-clean past `build_check`.
- **No source-repair / compile / release_compile_wave action taken.** Per this task's own
  constraint ("never edit EA source in the canonical checkout outside a governed build") and
  the Hard Rules, I did not attempt to fix `Strategy_ChannelMidpoint`'s framework-corset
  violation myself — that is Codex's governed build lane (`qm-build-ea-from-card` /
  `codex_review_fail_rework`), currently mid-loop.
- **Restored the canonical checkout to committed HEAD** for the 4 files dirtied by the
  live second attempt (`git checkout --`, exact pathspecs, no commit needed — content now
  matches HEAD exactly), mirroring Fable's already-established disposition for the first
  occurrence. This is a reversible, non-verdict-touching infra action
  (GRÜN: "operate existing tools with unchanged criteria" / repo hygiene), not a source
  edit — nothing authored was added or removed, the tree was returned to last-known-good.
  Evidence of the pre-restore state preserved in `recurrence2_working_tree.patch`.
- **This will recur.** The `build_ea` task (`e8e61fe1-2589-4f97-adb7-7de16892f9e4`) is
  still `status=pending` in the dispatcher `tasks` table and nothing stops a third
  dispatch. Recommend (not executed here — touches build-tooling scope, not this task's
  mandate):
  1. Give `EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX` for QM5_41155 its own scoped fix (or an
     explicit waiver) so the rework prompt can actually converge, or block redispatch of a
     rework whose cited finding it can never satisfy end-to-end.
  2. Have the build dispatcher `git checkout --` the EA's tracked files on a `build_check`
     FAIL exit, so a non-converging rework loop stops repeatedly dirtying the canonical
     checkout and tripping `repo_dirty_build_guard`.

## Evidence

- `docs/ops/evidence/2026-09-20_qm5_41155_uncommitted_source_drift/working_tree.patch` (original, attempt 1)
- `docs/ops/evidence/2026-09-20_qm5_41155_uncommitted_source_drift/task_7ab3e9d3-e70a-4d13-a792-86b6fe035024/recurrence2_working_tree.patch` (attempt 2, this review)
- `D:\QM\strategy_farm\logs\codex_build_e8e61fe1-2589-4f97-adb7-7de16892f9e4.live.attempt_1.log`
- `D:\QM\strategy_farm\logs\codex_build_e8e61fe1-2589-4f97-adb7-7de16892f9e4.live.log`
- `D:\QM\strategy_farm\artifacts\builds\e8e61fe1-2589-4f97-adb7-7de16892f9e4.json`
- `D:\QM\strategy_farm\artifacts\verdicts\codex_review_9458b037-f47f-426f-a4d1-0962cdad8cd1.json`
- `framework/EAs/QM5_41140_nzdjpy-carry-unwind-crisis-momentum/QM5_41140_nzdjpy-carry-unwind-crisis-momentum.mq5:473` (sibling reference pattern)
- `farm_state.sqlite: tasks` rows `e8e61fe1-...` and `9458b037-...`
