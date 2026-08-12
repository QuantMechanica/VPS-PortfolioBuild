# Rebind Window Execution Record — 2026-08-11/12 (Task #22 close-out)

Operator: Claude. Authority: OWNER standing unlimited preparation
(`docs/ops/evidence/2026-08-11_factory_preparation_owner_decision_standing_unlimited.json`,
commit ecbd91162, OWNER-executed) + OWNER "Go, alles freigegeben" (interactive
session 2026-08-11 evening) ratifying the batch scope.

## Window timeline (UTC)

| Time | Step | Result |
|---|---|---|
| 21:31–21:36 | Factory_OFF #1 | FACTORY QUIESCENT; evidence `D:\QM\reports\maintenance\factory_off\mnt046_factory_off_quiescence_20260811T213553Z_20188.json` |
| 21:37 | Corpse sweep + tree clean | 2 dead run_smoke reservations (T1/T8) pruned live by the new holder-PID liveness; factory artifacts absorbed (commit aa3ba5a92); tree clean incl. untracked |
| 21:38:35 | **Mint R8** (first mint under the standing prep) | `FACTORY_REBIND_20260812_OCCUPANCY_LIVENESS_QUIET_ZONE`, decision sha256 8bb7c25a…, HEAD aa3ba5a92; artifacts commit 793faf529 |
| 21:41–21:52 | **Quiescent FULL archive-integrity audit** | **PASS_ISOLATED, 0 findings**, audit_sha256 `58ade27c0dbee7b18d0bbb407c8b1e233996c1efd9dd8b553ea604c4f6a6b4b8`, output `D:\QM\strategy_farm\artifacts\ops\rebind_20260812\quiescent_full_audit_pre_on.json` |
| ~21:45–21:52 | Factory_ON #1 under R8 | Health gate PASSED (46 tasks, 10 workers); **FAILED CLOSED at restart-hold evidence**: `wal_checkpoint(TRUNCATE)` remained busy (log=2, checkpointed=0); rollback asserted OFF_RECOVERY_REQUIRED, mutation lock retained |
| 21:53 | Root cause + fix | TRUNCATE demands a WAL-reader-free instant; ten polling workers never yield one. Fix: FULL mode (all frames copied at busy==0 — exactly the hash contract) + bounded retry 12×2.5s, persistent busy still fail-closed. Commit 14947f400, 38/38 maintenance tests green |
| 21:55–21:56 | Factory_OFF #2 (recovery re-run) | FACTORY QUIESCENT; flag back to schema-v2 OFF, 21-task map (sha ccfb1611…) preserved; evidence `…20260811T215531Z_15940.json` |
| 21:56:59 | **Mint R9** | `FACTORY_REBIND_20260812_R9_WAL_EVIDENCE_FIX`, decision sha256 8b61bfd7…, HEAD 14947f400; artifacts commit 6141ddc25 |
| ~21:59–22:0x | **Factory_ON #2 under R9** | **FACTORY STARTED 10/10**, nonce ba99d632… burned, released=[] (zero-hold plan), WAL evidence step passed with FULL+retry. T_Live/FTMO untouched throughout |
| 22:0x | Post-ON verification | Quiet-zone tasks (3 orchestration lanes + CodexFleetPacer + AgyGovernor) enabled only after the gate — all Ready; claim-breadth monitor armed |

## Changes shipped in this window (all OWNER-ratified 2026-08-11)

1. **Recovery occupancy escape** (`farmctl.recovery_claim_allowed`,
   `CLAIM_RECOVERY_OCCUPANCY_MIN_ACTIVE=5`): the 1-in-5 recovery cap binds only
   while at least half the cohort holds active claims; below the floor recovery
   takes the idle slot. Closes the 2026-08-11 trickle regime (906 recovery rows
   pending, 2–3/10 busy for seven hours). Commit 9b7d2e8c4.
2. **Reservation holder-PID liveness** (`farmctl.terminal_reservations`):
   PID-encoded holders (`run_smoke:<pid>:<token>`) probed via kernel32 (no
   subprocess); dead holder ⇒ reservation fails open like TTL expiry. Closes
   the reservation-corpse class (3 recurrences on 2026-08-11). Proven live in
   this window (T1/T8 corpses pruned on first read). Commit 9b7d2e8c4.
3. **AI-orchestration quiet zone** (`Factory_ON.ps1`): orchestration lanes and
   pacers enabled only after the post-start health gate (router-freeze class
   R5/R6); the wait gate expects them disabled via a during-gate map,
   pre-release revalidation uses the final map. Commit 9b7d2e8c4.
4. **PSModulePath self-heal** in Factory_OFF/ON (2026-08-10 poisoned-env trap).
   Commit 9b7d2e8c4.
5. **WAL checkpoint FULL + bounded retry** in the restart-hold evidence path
   (new class discovered by R8 this window). Commit 14947f400.

## Variant-A isolation migration: close-out state

- Soak evaluation: `docs/ops/evidence/2026-08-11_ramp10_soak_evaluation.md`
  (573 runs, zero isolation incidents, occupancy shortfall attributed to
  dispatch policy — now amended).
- Quiescent FULL audit: PASS_ISOLATED / 0 findings (above) — the archives are
  content-verified intact after the entire ramp-10 soak.
- **Retention decision (recorded here): the rollback tree is KEPT.** Deleting
  the rollback hardlink families would change every archive's link count and
  invalidate the signed manifest's `link_count_at_build` invariants — removal
  requires an engineered manifest re-sign step (new manifest, gate
  re-expectations, fresh quiescent audit), not a cleanup delete. That step is
  deliberately deferred; disk pressure does not force it (tester_cache_purge
  governs D: headroom independently).
- Main integration (runbook step 15, executed 2026-08-12 morning): true merge
  via the cto_main worktree. Local main had silently diverged — 106 commits
  (orchestration-lane doc records, Q09 rounds) existed only on the stale local
  branch, 94 of them patch-equivalent to board-advisor, 12 unique in wording
  but with canonicalized file counterparts. Double merge: `ab946a44a` (sync
  stale local main with origin/main, 12 conflicts resolved to canonical
  archive versions) then `d02f3f349` (agents/board-advisor 7c113be2c in,
  2 add/add doc conflicts, both strict-prefix cases resolved to the
  board-advisor superset). **Verification: `git diff agents/board-advisor` on
  the merged main is empty — byte-identical tree**; standing-prep JSON bytes
  re-verified against the pinned sha256 (9d77f78f…) post-checkout. Push of
  main is classifier-gated → OWNER-`!` command handed over.
- **Forensic find in cto_main (pre-merge)**: uncommitted working-tree
  modifications dated 2026-07-28 21:36 had `_stop_pid`/`_stop_pid_tree` in
  farmctl.py stubbed to `return False` (process-kill neutered) plus a stale
  magic-registry SHA and `_reap_stuck_codex_procs` edits — never committed,
  origin unknown (falls into the codex-mnt-review-20260728 window). Preserved
  as stash `27f631637` in cto_main and as diff artifact
  `D:\QM\strategy_farm\artifacts\ops\rebind_20260812\cto_main_uncommitted_mods_20260812.diff`
  (sha256 e12e2b5fe06b02f26e4ff4e0c64d641f1d5077b3fa0d401cd0f7a88f2187bed7).
  Excluded from the merge; production farmctl (board-advisor) unaffected.

## Open follow-ups

- Same-class `wal_checkpoint(TRUNCATE)` copies in
  `isolated_work_item_runner.py` and `reconcile_terminal_work_items.py` have
  never fired but share the reader-lottery hazard — align them with the
  FULL+retry pattern in a normal change window.
- Router-freeze double-forensics (Claude + Codex SOL-MAX) remains open; the
  quiet zone removes the known trigger surface but not the root cause.
- Pre-existing pytest 5-file-combo flake
  (`test_apply_is_hash_bound_atomic_and_idempotent`) — Codex review packet.
