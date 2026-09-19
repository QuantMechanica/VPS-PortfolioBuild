# Ticket 23ccce7a reconciliation status — 2026-09-19 ~10:37Z (Claude)

Scope per router task `23ccce7a-ed43-4afe-b9c7-dd4880719c48`: reconcile the 13 stale
`COMPILE_EA_WORKER_ROLLOUT_PENDING` predecessors and release the 7
`Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` rows via a governed path, no verdict/evidence
mutation. Net result: **both sub-items are blocked by structural preconditions that are
outside GRÜN autonomy to resolve directly**; findings and a scoped follow-up are recorded
below. No hold, verdict, or work-item state was changed by this session.

## 1. COMPILE_EA rollout holds — 9 ready, 4 still blocked

Fresh read-only `reconcile_compile_rollout_holds.py` run at 10:37Z reproduces the same
split the 09:06Z dry-run found (`compile_rollout_reconcile_dryrun_1037z.json`):

- **9 rows** `ROLLOUT_PREDECESSOR_CURRENT_SUCCESSOR_EXISTS` → ready for
  `SUPERSEDE_AND_CLOSE_PREDECESSOR_HOLD`.
- **4 rows** `ROLLOUT_PREDECESSOR_NO_CURRENT_SUCCESSOR` (QM5_41179, QM5_41189 ×2,
  QM5_41142).

`apply_reconciliation()` refuses **atomically** while `needs_successor_count>0`
(`reconcile_compile_rollout_holds.py:240-250`), so the 9 ready rows cannot be closed
until the 4 blocked rows are resolved — there is no partial-apply mode.

### Root cause of the 4 blocked rows (new finding)

Each of the 4 predecessor rows already consumed the router's single-use
`ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY`
(`router_ops_issue:e9944090-1e0f-4dea-af90-e74f8079d1c8`, `compile_work_items.py:777`)
**once before** — supersede edges exist in `work_item_supersedes` dated 2026-09-02
(QM5_41142) and 2026-09-13 (QM5_41179, QM5_41189), each pointing at a real governed
compile successor (`compile_rollout_needs_successor_source_drift.json`):

| EA | predecessor | successor | successor result | successor sha == current disk sha? |
|---|---|---|---|---|
| QM5_41179 | 9ced0252 (2026-08-27) | 3f0de0a8 (2026-09-13T21:01:40Z) | COMPILE_FAIL | **no** |
| QM5_41189 | e5505264 (2026-08-27) | 81687a5b (2026-09-13T21:01:40Z) | pending, never compiled | **no** |
| QM5_41189 | 81687a5b (itself also held) | — | — | **no** (no successor at all yet) |
| QM5_41142 | 07a09214 (2026-09-02) | 9adcc3f5 (2026-09-02T18:47:16Z) | COMPILE_OK | **no** |

Every existing successor is itself stale: the EA source on disk has been edited again
**after** each governed compile attempt. Git history explains why — these are not
uncontrolled edits:

- `QM5_41179` / `QM5_41189`: last touched by commit `14d548c87a`
  ("fix(ea): EA_FRAMEWORK_INPUT_PINNED template defect repaired in 11 uncompiled
  winsweep EAs", 2026-09-13 23:35:49Z, Fable) — landed **2.5 h after** the 21:01:40Z
  compile attempts above, so those attempts ran against the pre-fix source.
- `QM5_41142`: last touched by commit `d0433c1c1d` ("build(gate): symbol-literal debt
  repaired at the natural rebuild (OWNER 2026-09-13)") — same pattern, a later governed
  fix landed after the 09-02 successor compiled.

Confirmed directly: re-running
`enqueue-compile QM5_41179_xtixng-mcoxstuart-rv --source-repair-authority
router_ops_issue:e9944090-1e0f-4dea-af90-e74f8079d1c8` refuses with
`SOURCE_REPAIR_PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY` (no state changed — refusal, not
an enqueue). The authority is single-use per predecessor by design (its own docstring:
"Initial enqueue is authorized only while the same EA still has an active … predecessor
bound to a different source hash"); it is not meant to chase a source that keeps moving,
and re-triggering it would defeat that anti-flap guard. This is the tool working
correctly, not a defect.

**Disposition:** not GRÜN-closeable in this pass. Fixing it requires per-EA code-lane
judgment (confirm the two landed defect-repair commits are complete/correct for these 3
EAs, then get one current-source compile to a terminal verdict — either a plain
`enqueue-compile` once the stale pending work items are closed, or a new
`compile_fail_repair_authorities.v1.json` entry if a compile still fails, following the
already-established QM5_41475/QM5_41477 pattern). Opened as a scoped Codex ticket
(`code`+`ops` capability) rather than attempted here, since it needs a real compile
attempt and source judgment, not ops bookkeeping.

## 2. Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING — 7 rows, not releasable via the named path

`maintenance_control.py release-on-restart` (dry-run, default-safe) returns
`expected_work_item_ids: []` / `release_count: 0`
(`q12_release_on_restart_dryrun_1037z.json`). Reading `release_restart_holds()`
(`maintenance_control.py:1474-1547`): the command only ever releases the exact
`authorized_work_item_ids` baked into one **pinned, hash-verified canonical OWNER
decision commit** (`CANONICAL_OWNER_DECISION_COMMIT = ecbd911628…`,
`_validate_canonical_restart_owner_decision`). That pinned decision's authorized set is
empty — it does not name any of the 7 `QM5_10706`/`QM5_11422`/`QM5_11421`/`QM5_13013`/
`QM5_10911`×3 Q12 rows. There is no way to add them without either (a) a new
OWNER-ratified restart-holds decision plus a matching code change to re-pin
`maintenance_control.py`'s constants to it, or (b) bypassing the manifest check, which
the acceptance criteria explicitly forbids ("never via ad-hoc SQL") and which would also
defeat the hash-bound design of this tool.

**Disposition:** correctly release-on-restart is not currently wired for these 7 rows.
This is a ROT-adjacent gap (new OWNER decision + code pin), not something GRÜN
autonomy can close. Flagging to OWNER via the decision queue rather than forcing a
release.

## Verification performed (read-only / additive only)

- `reconcile_compile_rollout_holds.py` (no `--apply`) — read-only.
- `farmctl.py enqueue-compile QM5_41179_xtixng-mcoxstuart-rv --source-repair-authority …`
  — refused before any DB write (verified via `work_item_supersedes`/`work_item_holds`
  row counts unchanged before/after).
- `maintenance_control.py release-on-restart` (no `--apply`) — read-only.
- `git log`/`git show` on the 3 EA source files — read-only.
- No `work_items`, `work_item_holds`, or `work_item_supersedes` row was inserted or
  updated by this session.

## Files

`compile_rollout_reconcile_dryrun_1037z.{json,csv}`,
`compile_rollout_needs_successor_source_drift.json`,
`q12_release_on_restart_dryrun_1037z.json`.

## Follow-up ticket opened

`agent_router.py enqueue ops_issue` → Codex, `code`+`ops` capability: resolve the 3 EAs'
current-source compile status (see acceptance above), then re-run
`reconcile_compile_rollout_holds.py --apply` for the (re-verified) SUPERSEDE_AND_CLOSE
wave. Q12 release-on-restart gap surfaced to OWNER decision queue (not a new ticket — it
needs an OWNER decision, not more code).
