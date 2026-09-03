# OWNER decision 2026-09-03 — pre-0803 recompile wave, DL-089 slot order, Amendment B

Recorded by Claude (CEO loop) at 02:12Z. Chat receipt (OWNER, 2026-09-03 ~02:08Z, German):

> „Da alles (Recompile-Welle Pre-0803 (+3 Paare möglich), Slot-Reihenfolge (2 von 8
> Zensus-Slots messen Zweitpässe bereits zählender Paare), Amendment B (Lineage-Reruns
> hinter ~1.300 priorisierten Zellen)), vor allem die Recompiles, können wir heute bereits
> angehen und dementsprechend priorisieren!"

Decision id: `OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903`. All three items were
Sunday-package Vorlagen in `docs/ops/OPEN_ITEMS_STATUS.md` (addenda 01:00Z–01:55Z); the OWNER
pulled them forward and ranked the recompiles first. Nothing here touches T_Live, AutoTrading,
gate thresholds, verdicts or the live book.

## 1. Recompile wave PRE-0803 (priority 1)

Class: `.ex5` binaries compiled before commit `f0102fbcf` (2026-08-03, `QM_NewsFilter.mqh`
provenance inputs `qm_news_calendar_bundle_id` / `_expected_sha256` /
`_common_relative_path`) fail every Q10_NEWS cell with
`MT5 report effective input qm_news_calendar_bundle_id mismatch`
(proven live 2026-09-03 00:33Z on QM5_11910 replacement `a6dbacf5`; class documented in
`2026-08-24_qm5_9936_news_provenance_include_revision.md`).

Approved scope (the "+3 Paare" of the Vorlage): **QM5_11910/NZDUSD, QM5_10700/XAUUSD,
QM5_12710/XTIUSD** (all `.ex5` 2026-07-24, chains contiguous through Q09, only Q10 missing).

Same class, found by the 02:10Z scan of the 64 pairs without a CONFIG_LOCKED Q10 (ex5 mtime
< 2026-08-03): QM5_10815/GDAXI (07-26, contiguous Q09), QM5_12580/AUDUSD (07-14, contiguous
Q08), QM5_13036/GDAXI (08-02, class INVALID), QM5_9510/XAUUSD (07-07, class INVALID),
QM5_12357/GDAXI (07-11, chain broken at Q03). 10815 and 12580 are proposed as batch 2
(same recipe, no extra decision needed beyond this note); 13036/9510/12357 stay out until
their INVALID/MISSING chain state is reviewed.

Mechanics (23.08. identity rule): a rebuilt EX5 is a **new identity from Q02**; the old rows
stay as evidence (append-only). Path: `compile_work_items.force_rebuild_allowlist` gains a
third OWNER-bound allowlist (`PRE0803_NEWS_PROVENANCE_FORCE_REBUILD`, owner reference
`OWNER_DECISION_2026-09-03_PRE0803_NEWS_PROVENANCE_RECOMPILE`, waivable reasons unchanged:
`EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`, `BOUND_SETFILE_HASH_EXISTS`) →
`farmctl enqueue-compile <label>` → `release_compile_wave.py --apply` → resident-worker
compile → COMPILE_OK → fresh Q02 for the new identity (`enqueue-backtest --ea … --phase Q02`
with the new `--expected-current-ex5-sha256`, no `--target-symbol`) → cascade Q03…Q10.
The 9936 precedent (`300c007a`, 2026-08-24) failed exactly at `CANDIDATE_RECHECK_REFUSED`
because no allowlist covered it — that is what the allowlist fixes.

Cost: one full Q02–Q10 chain per pair (~1–2 factory days each at current pace, interleaved
with the census); benefit up to +3 pairs (batch 1) / +5 (with batch 2).

## 2. DL-089 program slot order (priority 2)

K = 8 program slots. Two are occupied by second-pass programs of pairs that already count
(QM5_10706/GBPUSD `1a92b33e`, QM5_11422/USDCAD `f9e1f7fc`), while Q11-contiguous pairs
whose only missing gate is Q12 wait (`PROGRAM_SLOT_WAIT:K=8`: 20048, 21505, 12855, 9641,
12849; 21507/11881/20266/10513/10145 are in slots). Decision: order the governed program
queue by "adds a pair to the counter first" — Q11-contiguous pairs before second passes.
Mechanics: `dl089_matrix_service._queue_order` sorts by `payload.queue_order_at` (fallback
`created_at`); a governed tool sets `queue_order_at` on exact Q12 row ids (backup,
`BEGIN IMMEDIATE`, events row, dry-run/apply) — queue-order only, no status/verdict change;
cells already measured for 10706/11422 stay and resume when a slot frees.

## 3. Amendment B — lineage reruns before priority-tracked census cells (priority 3)

Under OWNER-DEC-TOPDOWN-PRIORITY-20260828 the claim order is universe_expansion →
recovery → priority_track → gate rank (census = 0) → …; a priority-tracked exact Q07/Q08
rerun therefore ranks behind ~1,300 priority-tracked census cells (41161/41097) and waited
6–7 h (QM5_11910 Q07 rerun) while it is the critical path to a Q10 lock. Decision: add a
rank key immediately after `_recovery_rank`: exact append-only lineage reruns
(`payload.append_only_rerun = 1`, `priority_track = true`, phase Q03–Q09) rank ahead of
all other priority-tracked rows. Sibling Q02 prerequisite seeds (Option A, rank −1 inside
the gate key) are unaffected. Blast radius: claim order only; verified by
`tools/strategy_farm/tests/test_opt_census_dispatch.py`.

## Execution log

- 02:12Z decision recorded; implementation of 1–3 commissioned to Opus agents in isolated
  worktrees with adversarial verification (workflow `pre0803-slot-amendb`), CEO merges.
- Follow-ups are appended below as they complete.
- 02:44Z–02:47Z (CEO): all three implementations merged after adversarial verification:
  allowlist `fcc1a439d8` (72 tests), Amendment B `ea1bbb5e86` (40 tests; key placed AFTER
  `_priority_track_rank`, see the amendment evidence doc), slot-order tool `55ca6e950a` (16 tests).
  Precision on §1: the waivable set is the existing `FORCE_REBUILD_WAIVABLE_REASONS` (four
  reasons, unchanged), not only the three named above. The allowlist gate is a presence check
  of the owner reference and `QM5_<id>` in THIS document; removing an id from this document
  revokes it.
- 02:44Z: batch 1 enqueued — `farmctl enqueue-compile` rows 9df0f1ad (QM5_11910),
  f1acbae1 (QM5_10700), b8a3b1f5 (QM5_12710); rollout holds released via
  `release_compile_wave.py --apply` (backup farm_state_before_compile_wave_20260903T024435Z);
  rows marked `priority_track` (claim positions 31–33 at 02:50Z). Batch 2 (10815, 12580) is
  allowlisted but NOT enqueued: proposed to the OWNER 02:13Z, Auffangregel (12 h) applies.
- 02:46Z: slot order applied — `set_dl089_queue_order.py apply --defer` set
  `queue_order_at = 2099-01-01T00:00:00+00:00` on 1a92b33e (QM5_10706/GBPUSD) and f9e1f7fc
  (QM5_11422/USDCAD); backup farm_state_before_dl089_queue_order_20260903T024553Z, events
  `dl089_queue_order_set`. Precision on §2: the 2099 sentinel is not "resume when a slot frees"
  — it defers both rows behind every current AND future governed row until they are
  explicitly re-ordered (`--queue-order-at`), which is the intended reading for the 25-pair
  target (both pairs already count). Governed order after apply: 13213, 1537, 21507, 11881,
  20266, 10145, 10513, 20048 (enters), …
- Open verifier notes (non-blocking): `list` mode of the slot tool models slot ownership
  without the service's deferral/no-sibling filters; its unit tests use a trigger-less schema.
- 02:49Z–03:10Z (batch 1, second wave): the first compiles PASSED the compiler but FAILED the
  current build gate (`build_gate_hardening.py`): `EA_Q08_MAE_HOOK_MISSING` (all three — an
  explicit `QM_FrameworkTrackOpenPositionMae();` as the first OnTick statement is now mandatory,
  the kill-switch fallback no longer counts) and `EA_TRADE_REQUEST_UNINITIALIZED` (11910 only,
  bare `QM_EntryRequest req` → `ZeroMemory(req)`). 12710's first row was refused at the compile-
  time recheck (`CANDIDATE_RECHECK_REFUSED`, `force_rebuild_authorized=false`) because that
  worker still held the pre-allowlist `compile_work_items` module in memory — resident workers
  import it once; the staggered all-terminal reload (started 03:06Z, one worker per ~150 s)
  refreshes the module and also activates Amendment B. Corset repairs (7 insertions, 0 deletions,
  gate PASS for all three) implemented by an Opus agent in a worktree, adversarially verified,
  merged as `5afa209e41`. `--repair-successor-of` was not usable (requires a build-task binding:
  `BUILD_TASK_BINDING_NOT_REQUESTED`), so fresh force-rebuild rows were enqueued: 57101a83
  (11910), dfb92b8a (10700), 47cd9a37 (12710); holds released with backup reuse disabled
  (`--backup-reuse-max-age-minutes 0`, see 03:05Z note), priority_track set.
- 03:05Z: backup-reuse identity (615608abd0, live for `release_compile_wave`) proven FAIL-OPEN by
  the adversarial verifier of task 4ce6ec32 (WAL overwritten in place after checkpoint restarts →
  row-count-neutral UPDATEs invisible). Mitigation: machine env
  `QM_COMPILE_WAVE_BACKUP_REUSE_MAX_AGE_MINUTES=0` (fresh backups); the shared-module refactor is
  in a revision stage (WAL header salts/frame count + max(updated_at)/events rowid), not merged.
- 03:15Z: sibling chains held — the pump cascade (regular Q03 promotion + `pump_q04_early_probe`)
  mints Q03/Q04 rows for DL-089 measurement siblings although their cards state 'No live or
  pipeline verdict is authorized'; 17 pending rows (41301–41307, 41321–41324) parked under
  `SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD`; cascade filter commissioned (Opus, `wb9k5vses`).
- 03:25Z: QM5_11910 second compile `57101a83` **COMPILE_OK** (compiler PASS + build gate PASS), new
  identity ex5 `e18d477e…`. 03:30Z: fresh Q02 `71d1ad66` enqueued for the new identity on the
  NZDUSD lineage (append-only successor of the prior-identity Q02 `5af21957`, binary sha recorded;
  `--owner-decision` must NOT be passed to `enqueue-backtest` — it switches the command into the
  universe-expansion path). It ranked 1,333 behind the priority-tracked census cells, so Amendment B's
  phase span was extended to Q02 (`be721b7612`, same OWNER priority 'Recompiles zuerst'); position 1
  afterwards, claimed by T2 at 03:33Z. 10700/12710 second compiles pending (workers busy / CPU pause).
- 03:37Z: staggered worker reload pass 2 running (pass 1 done 03:29Z) so every worker imports the
  allowlist module, Amendment B incl. Q02 and the rerun-visibility fix `a1cc06688b`.
- 03:49Z: QM5_11910 new-identity Q02 `71d1ad66` **PASS** (T2); cascade rows on the new identity
  expected from the following pump cycles.
- 03:53Z: QM5_10700 second compile `dfb92b8a` **COMPILE_OK** (new ex5 `5fbf2ba0…`). The new-identity
  Q02 could NOT be enqueued: the exact-rerun path refuses `q02_rerun_source_evidence_missing` (both
  prior XAUUSD Q02 rows, 6205ba82 PASS 2026-06-27 / fac4b180, lost their evidence to report
  retention) and the universe-expansion path refuses `ea_symbol_already_tested`. No governed path
  exists today to restart an already-tested pair on a new identity without retained old evidence →
  explicit `enqueue-backtest --new-identity-restart <OWNER decision>` commissioned (Opus workflow
  `wlv9tw55z`, fail-closed: PASS-family source, changed ex5 sha, payload discloses the restart).
  12710's second compile `47cd9a37` still pending (workers CPU/RAM-paused).
- 04:05Z: QM5_12710 second compile `47cd9a37` **COMPILE_OK** (new ex5 `11474d4c…`) — batch 1 fully
  recompiled (11910 `e18d477e…`, 10700 `5fbf2ba0…`, 12710 `11474d4c…`). New-identity Q02 for 10700 and
  12710 waits for the `--new-identity-restart` path (`wlv9tw55z`); 11910's chain beyond Q02 is blocked
  by the DL-074 cascade rule (any next-phase row for (ea, symbol, setfile) blocks promotion) and its
  old Q03–Q06 evidence is purged → the restart flag must be generalised to Q03–Q09 (clone the old
  phase-row config onto the new ex5 without old evidence); commissioned after the Q02 form lands.
- 04:12Z: worker reload coverage after the seal fix `b8cd532137` (03:52Z): T1–T6, T8 restarted after it;
  T7/T9/T10 still hold the pre-fix module → idle-only staggered reload of T7/T9/T10 started 04:15Z.
  1537/XAGUSD attempt-2 rerun `b878d9ba` active on T2 (restarted 04:02Z, has the fix) since 04:08Z.
- 04:25Z–04:30Z: `--new-identity-restart` (workflow `wlv9tw55z`) implemented but **refuted by the
  adversarial verifier and NOT merged** (diff parked as scratchpad `parked_new_identity_restart_flag.patch`):
  P1 the flag unblocks none of the three pairs — 12710's Q02 `ecd82fa8` evidence is retained (compressed
  `summary.json.gz`, accepted by `_retained_evidence_path`), 11910's too; 10700's source `6205ba82` is a
  pre-execution-binding row (no ex5/mq5/setfile shas) that the existing `farmctl seed-fresh-q02` serves;
  P2 the changed-identity guard is vacuous for rows without a recorded ex5 identity; P3 the escape is an
  unscoped free-text OWNER id (ROT-adjacent vs the pinned-constant idiom); P4 test contamination (below).
  Premise correction recorded: the earlier 'no governed path exists' statement (03:53Z) was wrong for both
  pairs; the real gap (bound source whose report aged out) is not in today's wave.
- 04:25Z: QM5_12710 new-identity Q02 `f1378383` enqueued via the ordinary exact-rerun form (source
  `ecd82fa8`, ex5 `11474d4c…`), claimed by T6 at 04:25Z. QM5_10700 new-identity Q02 `71fddb4a` created via
  `farmctl seed-fresh-q02` (old row `6205ba82`, ex5 `5fbf2ba0…`, setfile `a684dad2…`), marked priority_track.
  Its payload carries `fresh_q02_seed` instead of `append_only_rerun`, so Amendment B did not cover it
  (claim position 11,125) → `a8abdd16a8`: a governed fresh seed (bound to `requalification_old_work_item_id`,
  priority-tracked, Q02) ranks as a lineage rerun (position 4 after the change; 13 dispatch tests green).
- 04:29Z: QM5_11910 Q03 `fa66883f` enqueued on the new identity (predecessor = the new-identity Q02
  `71d1ad66`, `--append-only-rerun-of` the prior-identity Q03 `6a2d8480`) — the Q03 rerun form needs the
  Q02 PASS predecessor as `--from-work-item-id`; no generalisation of any restart flag is required. The
  chain is driven one phase per round (Q03 → Q04 … Q09, each an exact rerun of the prior-identity row with
  the new ex5 sha); Amendment B ranks each step at the head. Claim position 2.
- 04:30Z: verifier P4 confirmed in the MAIN checkout: `framework/calibrations/VPS_SLIPPAGE_LATENCY_
  CALIBRATION_V2.json` carried a 19-line `auto_stub` for the synthetic test symbol
  `QM5_9993_GBPJPY_AUDJPY_COINTEGRATION_D1` (stub_created_at 2026-09-02T11:52Z, written by
  `test_farmctl_cascade.py` through `P5_CALIBRATION_JSON`, a module constant bound to the real repo root;
  the path is on the pump auto-commit list). Reverted in main and in the agent worktree; fix commissioned as
  router task `1258a0c5` (ops_issue, Opus lane). All-worker staggered reload (chunk 9) started 04:28Z for the
  claim-order change.
- 04:33Z–04:46Z: QM5_11910 Q03 `fa66883f` **PASS**, QM5_12710 Q03 `55b7d71f` **PASS** (Q02 `f1378383` PASS
  04:28Z), QM5_10700 Q02 `71fddb4a` **PASS** (seed-fresh path). 04:55Z next steps enqueued as exact reruns of
  the prior-identity rows with the new-identity PASS as predecessor (scratchpad `chain_step.py`):
  11910 Q04 `cdf56ffe` (rerun of 3b783833), 12710 Q04 `c2297ba2` (rerun of cf751465), 10700 Q03 `f625c325`
  (rerun of 8f1d3116); all inherit priority_track and rank at the claim head under Amendment B.
- 04:48Z: worker reload chunk 9 finished (T1, T4, T5, T6, T8, T10 reloaded; T2/T3/T7/T9 busy) → chunk 10
  for the remaining four started 04:54Z. Verifier note on `farmctl.P5_CALIBRATION_JSON` commissioned as
  router task `1258a0c5` (IN_PROGRESS, Opus lane; launch paced behind the running revision workflows).
- 05:05Z–05:17Z: 11910 Q04 `cdf56ffe` PASS, 12710 Q04 `c2297ba2` PASS, 10700 Q03 `f625c325` PASS → next
  steps enqueued (`chain_step2.py`): 11910 Q05 `063eec00`, 12710 Q05 `84125a3a`, 10700 Q04 `4d8e9c24`.
- 05:24Z: 12710 Q05 `84125a3a` PASS → Q06 `9da6362d` enqueued. 11910 Q05 `063eec00` (T1) and 10700 Q04
  `4d8e9c24` (T6) running.
- 05:30Z–05:35Z: 11910 Q05 `063eec00` PASS → Q06 `dbb6fc97` (T1); 12710 Q06 `9da6362d` PASS → Q07
  `fad536b4`; 10700 Q04 `4d8e9c24` PASS → Q05 `c44015fa`.
- 05:34Z–05:42Z: 11910 Q06 `dbb6fc97` PASS → Q07 `797f03ae` (`--append-only-rerun-of` must name the NEWEST
  row of the prior-identity lineage — the 07-24 original `966fdb3a` was refused with
  `append_only_rerun_already_exists` because the 09-02 rerun `f3689f77` exists); 12710 Q07 `fad536b4` and
  10700 Q05 `c44015fa` pending at the claim head.
- 05:50Z–05:58Z: 10700 Q05 `c44015fa` PASS → Q06 `02df28c0`. The Q07 reruns of 12710 (`fad536b4`) and 11910
  (`797f03ae`) sat at claim positions 2–3 unclaimed: the 2026-08-24 long-run scheduling policy caps
  concurrent Q07/Q08 at 2 fleet-wide and both slots are held by QM5_20085 H4 recovery regenerations
  (T9 since 03:32Z, budget 418 min; T7 since 03:52Z, budget 216 min; three prior INFRA_FAIL attempts on
  INCOMPLETE_RUNS/TIMEOUT). Selection-only change `1c94f049bf`: an Amendment B row (append-only lineage
  rerun + priority_track, not quarantined) may take ONE Q07/Q08 slot above the cap (2 → 3); ordinary
  rows keep 2, news caps unchanged. Idle-only reload chunk 12 (T1/T4/T5/T6/T8/T10) started 05:55Z;
  chunk 11 covers T2/T3/T7/T9 when they go idle.
