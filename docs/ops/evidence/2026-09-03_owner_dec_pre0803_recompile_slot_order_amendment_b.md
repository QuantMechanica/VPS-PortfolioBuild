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
- 06:03Z–06:15Z: the third Q07/Q08 slot took effect (12710 Q07 `fad536b4` claimed by T5 at 06:03Z). 10700 Q06
  `02df28c0` PASS 06:01Z; its Q07 rerun was refused twice by a ZOMBIE row: the Codex 'Q10 lineage wave2'
  rerun `3815515b` (2026-09-02 16:30Z) is pending, bound to the pre-0803 identity `0126116d`, unclaimable
  under the execution-binding filter, and counted by the duplicate guards. Governed path used:
  `work_item_supersedes.py record --apply` (backup, recorded_by claude, reason bound to this decision) — the
  Q02 guards already honoured the supersedes table, the Q03/generic `append_only_rerun_already_exists`
  (`c6dba4c092`) and `already_pending_or_active` (`80269fed36`) guards now do too. 10700 Q07 `21317bcc`
  enqueued 06:15Z (rerun of 3fdcc9af). Same class remains for the two pre-0803 Q10_NEWS pending rows
  (10700 `77bd97c2`, 12710 `678b8cac`) — handled when the chains reach Q09 (news gate service path).
- 06:30Z–06:45Z: 12710 Q07 `fad536b4` **PASS** (06:30Z) → Q08 `bfda1943` enqueued; 11910 Q07 `797f03ae`
  claimed by T5 06:31Z (third slot); 10700 Q07 `21317bcc` pending behind the cap. Amendment B tuple's last
  element now resolved through the v4 contract map (`4884fbbab5`, value unchanged).
- 07:25Z–07:40Z: 12710 Q08 `bfda1943` FAIL_SOFT (gate-scoped PASS under OWNER-DEC-DL082-EXT Option D, same
  disposition as the prior identity) → Q09 `e1f7a095` enqueued (rerun of 51a2cd5c). 11910 Q08 `e0237a77`
  claimed by T4 07:26Z; 10700 Q07 `21317bcc` claimed by T7 07:35Z after the 20085 EURUSD recovery run hit its
  216-min budget (INFRA_FAIL 07:28Z, fourth attempt). Next: at 12710 Q09 PASS the pre-0803 Q10_NEWS zombie
  `678b8cac` must be recorded as superseded before the news gate re-mints Q10_NEWS on the new identity.
- 07:48Z–07:56Z: **12710 Q09 `e1f7a095` PASS** — the chain is contiguous Q02→Q09 on the new identity
  `11474d4c…`. The only Q10_NEWS row (`678b8cac`, pre-0803 identity, held NEWS_RUNNER_SPAWN_SILENT_ABORT)
  was re-armed under `Q09_AWAITING_SEALED_PLAN` via `governed_work_item_hold.py apply
  --supersede-hold-code` (superseded=1, row stays unclaimable) so the news-gate service mints the
  replacement parent on the current binary — the same path that produced 11910's `a6dbacf5` earlier today.
  Awaiting the replacement row in the next pump cycles; then Q10_NEWS runs → CONFIG_LOCKED → Q11 → Q12 slot.
- 07:38Z: unrelated but on the same critical path: 13213/XAUUSD Q10_NEWS `6e415bb4` CONFIG_LOCKED after a
  6.4-h run on T3 → Q11 `7db06ca0` minted; its Q12 `2ea9cd64` already owns slot 1.
- 07:57Z–08:02Z: the news-gate service minted 12710's replacement Q10_NEWS parent `9a2e9380` (ex5
  `11474d4c…`) in the 07:51Z pump cycle; the zombie `678b8cac` is now done/SUPERSEDED; `9a2e9380` claimed by
  T10 07:57Z. 11910 Q08 `e0237a77` FAIL_SOFT (gate-scoped PASS) → Q09 `859b114d` enqueued (rerun of 2b2ec7d3).
- 08:07Z–08:14Z: **11910 Q09 `859b114d` PASS** (chain contiguous Q02→Q09 on `e18d477e…`). Q10_NEWS parent
  `bdae4b44` enqueued via the ordinary rerun form (`--append-only-rerun-of a6dbacf5`, the terminal
  REVIEW_REQUIRED parent of the pre-0803 identity; predecessor 859b114d); it carries
  q09_activation_state AWAITING_SEALED_PLAN + the Q09_AWAITING_SEALED_PLAN hold, i.e. the news-gate service
  seals/binds the run plan and activates it (RUNNABLE_BOUND) in a following pump cycle — the same lifecycle
  a6dbacf5 and 12710's 9a2e9380 went through. 13213/XAUUSD Q11 `7db06ca0` PASS 08:11Z (Q12 `2ea9cd64` owns
  slot 1; program 513+/1085 cells).
- 08:22Z–08:27Z: 11910 Q10_NEWS `bdae4b44` sealed/activated by the news-gate service (RUNNABLE_BOUND, hold
  released) and claimed by T1 08:22Z — two of the three chains now run the news gate on their new identity
  (12710 on T10 since 07:57Z). 10700 Q07 `21317bcc` PASS 08:22Z → Q08 `ce371d25` enqueued (rerun of fb35a79a).
  RAM 6.7 GB free with two 11 GB Q09/recovery testers (T7, T9) plus three news runs — above the 1.5 GB floor,
  claim guard active; no intervention.
- 08:36Z–08:45Z: 12710 Q10_NEWS `9a2e9380` (8-cell contract v3) ended **REVIEW_REQUIRED** with reason code
  `expanded_7x4_matrix_required`: material_effect=true (delta drawdown / net R / profit factor) — verified on the
  cell summaries: policy modes m2–m5 differ from control (m5: 16 trades / net −1,054 vs 23 / +3,153 in the first
  window), so the expansion is a legitimate adjudication, not an artefact (`max_affected_entries=0` only counts
  blocked entries). The news-expansions stage minted the expanded parent `58d84268`
  (force_expanded_news_matrix, 105 further cells) at 08:38Z; fleet cap for expanded parents = 2 (the other
  pending one is 11422/USDCAD from 2026-08-23). 11910 Q10_NEWS `bdae4b44` still running on T1; 10700 Q08
  `ce371d25` on T2.
- 08:50Z–08:55Z: 12710's expanded Q10_NEWS parent `58d84268` claimed by T8 (the expanded subcap of 2 is not
  binding today: the only other expanded parent, 11422/USDCAD, is held). Reload chunk 13 finished (9/10; T9
  follows via chunk 14 once its 20085 recovery run ends ~10:30Z).
- 08:57Z–09:08Z: 11910 Q10_NEWS `bdae4b44` (8 cells, 35 min on T1) ended REVIEW_REQUIRED /
  `expanded_7x4_matrix_required` (material_effect: Δnet R, ΔPF, sign-or-gate flips 5 of 5 → strong news
  sensitivity); the expansion parent `f7264187` was minted 08:58Z (priority_track). Both recompile chains that
  reached the news gate therefore need the 105-cell expansion; 12710's (`58d84268`) is running on T8.
- 09:33Z–09:50Z: 10700 Q08 `ce371d25` PASS (H1 walk-forward, 60 min) → Q09 `3030129c` enqueued (rerun of
  3e40593d). At its PASS the pre-0803 Q10_NEWS zombie `77bd97c2` gets the Q09_AWAITING_SEALED_PLAN re-arm.
  Expansions 12710 (T8) and 11910 (T1) still running.
- 10:08Z–10:18Z: **10700 Q09 `3030129c` PASS** — all three batch-1 pairs are now contiguous Q02→Q09 on their
  recompiled identity (11910 03:33Z→08:07Z, 12710 04:25Z→07:48Z, 10700 04:46Z→10:08Z). 10700's pre-0803
  Q10_NEWS zombie `77bd97c2` re-armed under Q09_AWAITING_SEALED_PLAN (superseded=1) for the news-gate
  replacement parent. The census claim pause 09:58Z–10:09Z was the worker RAM guard (free RAM ~6 GB with two
  11 GB testers), not a stall.
- 10:20Z–10:28Z: the news-gate service minted 10700's replacement Q10_NEWS parent `fe33550e` (RUNNABLE_BOUND,
  priority_track, supersedes 77bd97c2 which is now done/SUPERSEDED); claimable as soon as a news slot frees
  (3 of 4 news slots busy: 11910 + 12710 expansions, 11403 standard).
- 11:17Z: **12710 Q10_NEWS expansion `58d84268` CONFIG_LOCKED** (2.4 h, 105 cells on T8) → Q11 `a10aa1da`
  auto-minted and claimed. 12710 is the first batch-1 pair through the news gate on its new identity.
- 11:20Z–11:30Z: claim-order defect for the chains' news parents: 10700's replacement parent `fe33550e`
  (RUNNABLE_BOUND, priority_track) sat at position ~1,300 for an hour because the census sub-ranks precede
  `_phase_rank` and workers kept finding claimable frontier cells. `608cc5ec6b` (+ fixture `eabf4437bb`):
  a Q10_NEWS row that is an append-only rerun or a service-minted replacement parent
  (`supersedes_held_q09_work_item`), priority-tracked, takes the lineage-rerun key; long-run caps still apply
  at claim time. Idle-only reload chunk 15 (all workers) started 11:22Z.
- 11:24Z–11:40Z: the news-parent rank key worked on first contact — T8 claimed 10700's parent `fe33550e` two
  minutes after its reload (11:24Z). **12710 Q11 `a10aa1da` PASS 11:25Z** → Q12 program row `9384656c`
  (11:28Z). Applied §2 mechanics for the recompiled pair: `set_dl089_queue_order.py apply --queue-order-at
  2026-08-29T08:02:00+00:00` (rank 27 → 5, behind the four earliest slot owners; the eighth current owner is
  deboosted at the next service cycle and resumes later, its measured cells stay). Receipt
  scratchpad `queue_order_12710_apply.json`, backup by the tool. 11910/10700 get the same placement when
  their Q12 rows exist.
- 11:42Z–11:58Z: **11910 Q10_NEWS expansion `f7264187` CONFIG_LOCKED** (2.5 h) → Q11 `839984e5` (priority_track).
  12710's Q12 `9384656c` is deferred by the matrix service: 'expected one approved _opt sibling for
  QM5_12710/XTIUSD.DWX, found 0' — the recompiled pairs have no DL-089 measurement sibling yet (the census
  runs on the sibling EA, not on the parent). Sibling wave 3 commissioned: router task `262f7959`
  (Claude lane), Opus workflow `wg8u1drba` (one worktree per sibling, ids 41331–41333 unless the reservation
  tool dictates otherwise, adversarial verifier each); CEO does magic allocation, card copies, compile enqueue
  and release. Until the siblings compile, the three Q12 rows stay deferred regardless of their queue rank.
- 12:05Z–12:12Z: 11910's priority-tracked Q11 `839984e5` sat 20+ min behind frontier census cells (same class
  as the news parent). `4cd1d1f35a`: priority-tracked Q11 rows take the lineage-rerun key (phase resolved via
  the v4 contract map; the parametrized negative case moved to Q13). Reload chunk 16 (all workers) replaces
  chunk 15 (8/10 done) so every worker carries 608cc5ec6b + 4cd1d1f35a.
- 12:10Z–12:22Z: sibling wave 3 delivered and merged (`5e6f19a61a`): QM5_41331 (12710/XTIUSD), QM5_41332
  (11910/NZDUSD), QM5_41333 (10700/XAUUSD); magics allocated (`270019d078`, `129c6e887e`, `3e8cd06ec1`); compile
  rows 98bfe19a / fa3cff26 / c299634e released and priority-tracked. Evidence:
  docs/ops/evidence/2026-09-03_sibling_wave3_recompiled_pairs.md.
- 12:09Z–12:40Z: 11910 Q11 `839984e5` PASS 12:09Z → Q12 `b764a145` placed at queue rank 6 (behind 12710,
  `--queue-order-at 2026-08-29T08:03Z`). The three sibling compiles stayed pending because six workers sat in
  `ram_low_pause` (4 testers = 44 GB, 6.8 GB free) — a governed compile needs < 1 GB. `ef1c4dbbff`: under the
  RAM latch a worker may claim COMPILE_EA rows only (floor 3 GB), mirroring the census bypass; reload chunk 17
  (paused workers first) started 12:36Z. Reload chunk 16 (6/10) superseded.
- 12:38Z–12:45Z: the compile-only bypass worked on first contact (T1 logged `ram_low_compile_only` ×3 right
  after its reload): **41331 / 41332 / 41333 COMPILE_OK** 12:38Z–12:39Z (the two released August siblings 41175
  and 41177 compiled too). The matrix service seeded 41331's Q02 census prerequisite `c0cc02a5` at 12:38Z and T2
  claimed it immediately; 41332/41333 seeds follow with their Q12 rows. Router task 262f7959 → APPROVED.
- 12:43Z–12:55Z: sibling seeds 41331 `c0cc02a5` PASS 12:43Z and 41332 `417a6769` PASS 12:47Z → the matrix service
  materialized the DL-089 programs of **12710/XTIUSD** and **11910/NZDUSD** (1,085 cells each; 12710 already
  boosted with a 6-cell frontier window). 10700 Q10_NEWS `fe33550e` ended REVIEW_REQUIRED (expansion required,
  like the other two); the expansion parent `c0faeb48` was minted 12:43Z and claimed by T5 12:48Z.
  Guardian loop restarted 12:57Z (6-h cycle ended 12:43Z).
- 13:10Z: both recompiled programs are serviced by the matrix service (boost window 6 each): 12710 2/1,085 cells
  done, 11910 starting; 21507 at 542/1,085. 10700's expansion `c0faeb48` running on T5 since 12:48Z.
  Throughput brake of the day: the RAM latch (14/20 GB) again idles 4–6 workers at 12.5 GB free while the
  census cells need ~4 GB — Vorlage filed (census-cell bypass floor).
- 14:41Z–14:45Z: **Batch 2 executed under the Auffangregel** (Vorlage 02:13Z, no OWNER answer by 14:13Z; the
  wake-up fired late at 14:41Z): `farmctl enqueue-compile` rows 2f8fe7d9 (QM5_10815_tv-post-vwap, GDAXI) and
  bc865e0b (QM5_12580_fx-usd-exhaustion-reversal, AUDUSD); both released via `release_compile_wave.py
  --work-item-id --backup-reuse-max-age-minutes 0` (12580 needed a second attempt — first pass applied 0, transient)
  and marked priority_track. Next: COMPILE_OK → build gate → new-identity Q02 → chain_step.py → sibling wave 4.
  Census state: 12710 14/1,085 (1 active), 11910 boosted (6 frontier cells) but not yet claimed, 21507 543/1,085;
  the fleet recovered to 10 active claims at 24 GB free after the 13:30Z–14:30Z RAM latch.
- 15:15Z–15:22Z: root cause of the census crawl found — not the latch alone: with 17 GB free every census
  cell failed the per-item RAM check (17.2 − 4 GB reservation < 14 GB floor) and non-latched workers logged
  `no_pending_claimable`. Infra repair `49e7b029f4` (standing authorization, reversible): census cells keep
  8 GB after their reservation (claimable from 12 GB free); backtests keep 14/20, compiles the 3 GB bypass;
  97 worker tests green. Reload chunk 18 (idle workers first) started 15:20Z. T7 held a census cell
  (20266 program, `c25808a8`) for 107 min with a 0.3 GB tester and no run log — stuck launch; worker + tester
  restarted 15:19Z (the cell re-enters via the driver's INFRA rerun).
- 15:27Z: test-fixture repair `c71d9ecbc` (test_longrun_scheduling_policy pins `_free_ram_gb`; test_dl089_matrix_service
  sets DL089_PROGRAM_SLOTS=8 + pinned terminals); 41 passed.
- 15:33Z–15:39Z: **batch 2 executed** (Opus workflow wf_3082f98f-2a8, 4/4 verdicts ok). Parents QM5_10815/GDAXI and
  QM5_12580/AUDUSD repaired for the build gate (`a8badb90cb`, MAE hook only, same recipe as batch 1); DL-089 siblings
  QM5_41334 / QM5_41335 built (`35671df4b8`; 41335 reduced to a single-carrier slot table `b684a794b0` + `1d1f5c016a`
  because the governed allocator registers card symbols from slot 0 and has no slot-map declaration); magics
  413340000 (`f8ea22e549`) and 413350000 (`85515487d1`) allocated serially; four COMPILE_EA rows enqueued and released
  by id — 10815 `08aea615` COMPILE_OK 15:38Z, 12580 `2b49b806` COMPILE_OK 15:38Z, 41334 `85dafae7` COMPILE_OK,
  41335 `08440065` pending. New identities re-enter at Q02 via `seed-fresh-q02` (pre-binding sources; the rerun form
  refuses PASS targets): 10815 `bd12175c`, 12580 `d53328e2`, both priority-tracked (claim positions 2 and 3).
  Old-identity zombies to supersede when the chains arrive: 10815 Q10_NEWS `57d8bacd`; 12580 Q09 `a2431935` + Q10_NEWS `aece4bcc`.
- 15:40Z: five verified preparation packets committed (`54162ed052`): path-to-25 ETA model (structural ceiling 24 =
  5 + 19 Q11-contiguous; pair 25 needs a climber from the Q09 pool, modelled as 10700/XAUUSD; S0 dates 10→04.09,
  15→05/06.09, 20→07.09, 25→09.09, optimistic bias), V1(b) packet (only 10911 has a runnable governed command),
  vein-1 requeue packet (no farmctl path re-enters the 150 false INVALIDs → affordance needed), 20085 park packet
  (hold `0bc6a5bc` WS30 at the 21:35Z Auffangregel; let `19d3d8e5` run out), news-gate forensics (34 real expansions
  of 85 REVIEW rows; 38 cell_execution_failed = cheap reruns; proposals A GELB / B+C GRÜN / D ROT).
- 15:43Z: live check — 28 of 30 pending Q12 rows carry `Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING` incl. the running
  21507 program: the hold does not gate the census service; K=8 program slots do.
- 15:50Z: Opus workflows launched — runbook revision (wf_6be351fc-4b6: FTMO claim refuted, builder already does
  aggregate control), proposals B + C (wf_3d2098c6-6f4). 17 legacy unheld COMPILE_EA rows from 21.–24.08. (41097,
  11465, 9914, 13128 …) sit pending with 0 attempts and no release binding — queue-hygiene item, not on the 25-path.
- 15:52Z–16:07Z: tester peak-memory ledger + measured RAM admission merged worker-side (`77fc3266a6`, Opus wf_54b66153-8a7
  verified; 3-way apply onto the census-floor commit; 112 worker tests green); reload chunk 19 (six workers already
  reloaded by chunk 18) queued behind chunk 18. Runbook committed `c032dbb1a5` after the revision verdict (FTMO
  aggregate control corrected). Old-identity zombies superseded (`work_item_supersedes record --apply`): 10815 Q10_NEWS
  `57d8bacd`; 12580 Q09 `a2431935` + Q10_NEWS `aece4bcc` (all pre-binding, would bind the superseded binary).
  Host at 100 % CPU from parallel Opus test runs → agent/test processes set to Idle/BelowNormal (`prio_normalize.ps1`
  loop every 45 s until ~22:30Z); census 11 cells/10 min during the burst, RAM 14.9 GB free. Opus workflows running:
  B+C (wf_3d2098c6-6f4), vein-1 affordance + decay-test fix (wf_28c0e10b-c08), G1/G2/G8 (wf_8c3a9afe-b0f),
  G3 orthogonality standard (wf_18ea64f8-b1c).
- 16:07Z–16:20Z: RAM identified as the binding fleet constraint (51.9/63.1 GB used: 4 testers 32.6 GB, terminals 3.8,
  workers/pump 3.0, Opus agents ~3.5, RDP browsers ~3.3; six workers latched at 11.3 GB free) — OWNER Vorlage for a
  RAM upgrade filed; T3 20085 Q07 (11.5 GB) left to run out per the park packet. Merged after verified verdicts:
  decay-test fix `5ec57fdfdd` (16/16), vein-1 affordance `c77a8c9dc1` (`farmctl requeue-false-invalid-setfile`,
  +564 additive, 62 tests; canonical dry-run on 27d2a2ab = would_enqueue true; wave 1 stays the 04.09 04:00Z
  Auffangregel), G1/G2/G8 `58221e3401` (order template + minter, q15_fit_report, rehearsal: 6 defects, D3/D4
  structural), G5 Vorlage + hygiene audit + first fit report `4f02c7f1c5` (all 18 legacy COMPILE_EA rows already
  superseded → no action; G5 epoch sentence corrected after refutation). D1–D6 fix workflow launched
  (wf_10455ec8-70e). Fleet back to 10/10 active at 16:19Z (19.9 GB free), 12580 Q02 `d53328e2` running on T7.
- 16:23Z–16:35Z: T7 ran the 12580 Q02 (multi-symbol EA, 19.7 GB tester) next to 20085 (11.5 GB): five workers latched at
  9.4 GB free, census 3-4 cells/10 min — accepted (recompile priority; 20085 runs out ~17:31Z). 12580/AUDUSD Q02
  `d53328e2` PASS 16:27Z on the new identity → Q03 `a64d18d3` (exact rerun of 6ce2cb7c, priority_track inherited).
  News-gate proposals merged after verified verdicts: B `1210766f97` (7x4 expansion-child reaper budget 11080 → 900 min,
  93 tests), C `e72c4d62cc` (expansion children of a lineage parent rank 0; additive arm; readiness 23/23). Both take
  effect for the pump immediately (fresh process) and for workers at their idle-only reload (chunks 18/19).
  Throughput-lever workflow launched (wf_f3c42ecc-550: census-first RAM priority, claim-order cost, G5 consumer read).
- 16:45Z–16:58Z: G3 orthogonality standard for sparse D1 merged (`4189444b87` + `3406825c14`; Opus design panel
  wf_18ea64f8-b1c, verified ok, Tier-1 numbers recomputed exactly): the current correlation tool yields a usable
  value for 0/46 book-relevant pairs; adopted two-layer fail-closed standard (ZK-SBB certify-or-abstain + COS
  co-occupancy flag); V4 Vorlage updated to option (c). Router: 0 REVIEW tasks in any lane (16:40Z).
- 16:45Z–16:58Z: book-path defects merged after four verified verdicts (Opus wf_10455ec8-70e): D1/D2/D5/D6
  `4a4cb78355` (+ FTMO freeze refusal `e7f0ee2b13`, test `032454c904`), D3 roster generator + D4 stream-bundle
  assembler `68eba1e611`. D4 real run: only 11421/EURUSD has a physically present current-identity sealed stream;
  1537, 10706, 11422, 13054 need their Q08 baseline re-emitted on the current binary (seals are recorded in the Q08
  aggregates, the bytes are gone) → OWNER Vorlage (GELB, 4 heavy runs). Claim-path finding: 12580 Q03 `a64d18d3`
  (7-symbol FX basket) sits at claim position 1 but needs 48 GB commit headroom (MULTISYMBOL_COMMIT_MIN_FREE_GB,
  reservation 32 GB) — unreachable while 8 testers run; 10815 Q02 `bd12175c` at position 3 also unclaimed (cause not
  logged; RAM class suspected). Both stay priority-tracked; the census-first/claim-cost workflow may address it.
- 16:55Z–17:15Z: claim-path finding — 10815/GDAXI Q02 `bd12175c` carries RAM class single_index_tick (44 GB flat,
  SP500 Q02 measured 46.8 GB WS on 2026-08-15) → needs 58 GB free → unclaimable on the 63 GB host while anything
  runs; 112 pending index Q02 + 369 index Q04 share the class. Drain-window workflow launched (wf_051790b8-a85) —
  FAILED at worktree creation: **C: ran full (0.1 GB free)** from ~30 Opus workflow worktrees (each a full checkout)
  plus 13 rework-slot / 5 claude-orchestration worktrees (108 total). T_Live terminal alive (pid 19016 since 23.08.),
  journal last written 16:17Z (deal entry), no error entries. Cleanup: completed wf_* worktrees removed (detached
  passes wt_cleanup.sh / wt_cleanup2.sh; running workflows kept); 38 → 40 GB free by 17:12Z. The Q08 durable-export
  workflow (wf_82fd54d3-a9c) delivered its implementation but its verifier and the rerun packet failed on the same
  ENOSPC — nothing merged; both workflows to be resumed after cleanup. Implementer finding: aggregate.py already
  persists the durable stream at seal time (_persist_durable_sleeve_stream :748); the four missing files were
  deleted afterwards, so the added value is verify-and-record + append-only sibling guard + backfill CLI.
  CPU guard tripped T1/T7/T10 during the git removals → git/bash added to the Idle-priority loop.
- 17:25Z–17:37Z: throughput levers merged after three verified verdicts (Opus wf_f3c42ecc-550): census-first RAM
  priority + claim-order memo `4fe39056cc` (claim_atomic evaluated the ~12.7k-row ordering twice per attempt at
  ~0.9 s each — the CPU-guard feedback loop; memo hit ~0.2 ms, order proven identical; kill switches
  QM_CENSUS_FIRST_RAM_PRIORITY=0 / QM_CLAIM_ORDER_CACHE_TTL_MS=0), authenticated pointer read in
  verify_live_deployment_contract `06c3220131` (G5 residual). Reload chunk 20 (all ten, idle-only) replaces
  chunks 18/19; workflow worktrees removed (pass 3). Verifier flagged 8 pre-existing failing tests on the
  branch (rulepack snapshot-hash / seal-identity: test_opt_census_pruning, test_target_outcome_dossier,
  test_pipeline_books_dashboard_status, test_ftmo_book3_standalone_evaluator) — repair commissioned.
- 17:05Z: 10700/XAUUSD 7x4 expansion `c0faeb48` ended REVIEW_REQUIRED with the single reason cell_execution_failed —
  one cell's Q09 terminal-process scan (pwsh Get-CimInstance, timeout 30 s) timed out while the host sat at 100 %
  CPU (worktree removals + agent test runs). Infra, not strategy. The pump retries only stale-worktree expansions,
  so an exact append-only rerun was enqueued by hand at 17:39Z: `0c247960` (claimed immediately via the lineage key;
  it is an 8-cell run because enqueue-backtest cannot carry the expansion identity — flag commissioned,
  wf_1bef194a-0b8, together with CIM-scan hardening and the 8 pre-existing test failures).
- 17:31Z: 20085/XAUUSD Q07 `19d3d8e5` reaped INFRA_FAIL at its 418-min budget as the park packet predicted; the
  21:35Z Auffangregel (hold on WS30 `0bc6a5bc`) stands.
- 17:43Z: **Auffangregel executed (2 min ahead of 17:45Z; effect starts at worker reload):** same-program canary
  L=2 — machine env DL089_LANES_PER_PROGRAM=2, DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST=21507+12710+11910 programs;
  workers pick it up through reload chunk 20 (idle-only, running). Rollback: unset both variables + reload.
- 17:50Z: Q08 durable-stream verify/record + backfill CLI and the Q08 re-emission packet merged (`27625045c0`,
  Opus wf_82fd54d3-a9c resumed after the disk incident; both verdicts ok). Worktrees of finished workflows removed
  (passes 3/4); C: ~80 GB free.
- 18:05Z–18:15Z: T8 census cell `4c8d2ef4` (12710 program) stuck 85 min (tester 0.26 GB, 52 s CPU, no run log after
  tester.ini) → worker + tester + terminal killed, worker respawned via start_terminal_workers (guardian alive), cell
  back to pending. Merged after verified verdicts: drain window `0000407c2e` (+ index-tick audit: the 44 GB class rests
  on one SP500 measurement; host free RAM never exceeded 42.8 GB in 24 h; by design the window arms for 32 GB baskets
  but not for 44 GB index rows — follow-up floor commissioned wf_ac0211ba-fee), CIM-scan hardening `d5ec4ade50`,
  --force-expanded-news-matrix `73e28c2bd2`, .gitattributes -text pins `f52e88129a` (canonical checkout verified LF,
  authenticate_amendment OK; the 93 spurious test failures were worktree-only). Genuine regression found:
  ftmo_book3_standalone_evaluator EXPECTED_OFFICIAL_SOURCE_IDS out of sync with rulepack V2 since 0abbc24b02 (fix
  commissioned, same workflow). Reload chunk 20 7/10 (T1/T9/T4 busy), chunk 21 (drain window) queued behind it.
- 18:40Z–18:46Z: drained-fleet admission floor merged (`73e0119ccc`, Opus wf_ac0211ba-fee verified ok; 160 tests): the
  armed drain row is admitted at 4 GB post-reservation once no other tester runs, so 44 GB index rows (10815 Q02)
  become winnable at 48 GB free; reload chunk 22 queued behind 21/20. FTMO evaluator source ids/semantics synced
  (`5065dcda78`), but the 24 evaluator tests stay red: pin 0abbc24b02 (02.09.) bumped profile_version/as_of and
  rebased all sources to the economic-terms snapshot whose schema the evaluator does not accept → OWNER Vorlage
  (FTMO evidence chain). 12580/AUDUSD Q03 `a64d18d3` claimed 18:41Z on T3 through the normal gate (commit headroom
  cleared before the 20-min drain trigger); chain continues.
- 19:04Z: 12580/AUDUSD Q03 `a64d18d3` (new identity) FAIL run_smoke_fail:MIN_TRADES_NOT_MET — both model-4 runs over
  2018-07-02..2022-12-31 produced ZERO trades (net 0.00, DD 0.00) while the old-identity Q03 6ce2cb7c PASSed on
  2026-06-28 (evidence purged) and today's Q02 traded. Same window and symptom as the documented QM5_10025 zero-trade
  case (2026-09-02: INIT_OK, all partner histories synchronized, zero selection/signal markers). Read-only diagnosis
  workflow launched (wf_710ffab1-cea). The FAIL stands append-only; no rerun until an infra cause is proven fixed.
- 19:02Z: loop round — guardian_long still alive (5 procs), 10 workers, pump 19:02Z, containment enabled:false,
  C: 85.6 GB free, RAM 18-38 GB free, census 11 cells/10 min (3 lanes), 21507 562/1085, 12710 54, 11910 92.
- 19:10Z–19:20Z: news-gate proposal D analysis + foreign-worktree audit committed (`ee300a8f5c`, Opus wf_cee8cc14-938,
  both verified ok). D: the NONE-compliance value is a persistence label omitted by the two REVIEW dicts (all 54 rows
  executed DXZ/POLICY_ON, verdict impact 0); material_effect fires on real temporal-mode effects; affected_entries is
  unwired (0/15); the selector scores only the target column (32/32 locks DXZ) so the 29-cell expansion adds columns
  never selected -> option (e) lazy expansion for single-target deployments would lock all 43 open expanded rows at
  the 8-cell (ROT Vorlage filed, replaces the 15:55Z D Vorlage). Worktrees: all 21 under C:/QM/worktrees carry WIP,
  none reclaimable. Governor v2 build (G6, OWNER-gated activation) launched as Opus workflow wf_36c785e8-af5.
- 19:30Z: 12580/AUDUSD Q03 FAIL diagnosed as a HARNESS FALSE ZERO (Opus wf_710ffab1-cea, verified; `ab8aa8584d`):
  run_smoke.ps1 latched MetaTester's report shell (Deposit 0.00 / Symbols 0 / Trades 0, Bars 958, 119M ticks) before
  terminal64 flushed the final report; tester journal shows deals #2-#69 and 'Test passed in 0:10:25', EA logger 36
  ENTRY_ACCEPTED; Q02 of the same binary/window traded 47 times. FAIL row stands append-only (taxonomy strategy ->
  infra); rerun only after the harness gap is closed. Hardening + false-zero sweep since 08-15 launched
  (wf_2dc8f552-a32); governor v2 build running (wf_36c785e8-af5).
- 19:35Z: **V1(b) Auffangregel executed** exactly as the verified packet: append-only Q05 rerun 10911/GDAXI `57aad04d`
  (rerun of f4ac4d5c INFRA_FAIL, predecessor Q04 538405f6 PASS, ex5 5199e260 unchanged). Nothing else was governed
  to run for 1556/12969 (news gate) or 10403/11708 (program slots).
- 19:45Z–20:05Z: the Opus seats hit the weekly session limit (reset 20:00Z): governor v2 (wf_36c785e8-af5) delivered
  its design + adapter but the verifier died → NOT merged; the run_smoke hardening + false-zero sweep
  (wf_2dc8f552-a32) delivered nothing. Both resumed 20:05Z after the reset; a drain-window arming refinement was
  commissioned (wf_f29d8ff0-37c). A drain had armed at 19:48:54Z for e046b36b (11129 Q07, 44 GB index class) while two
  Q07 and two Q10_NEWS long runs held RAM at 16 GB free and most workers still lack the drain-floor code (chunk 22
  queued) - unwinnable within 30 min, census-only cost - closed by hand in drain_window.json (active=None, 6 h
  cooldown until 02:04Z). Fabric 20:03Z: 8 active (2 Q07, 2 news incl. 10700 expansion 152e8d29 on T4, 4 census),
  17 cells/10 min, 16 GB free, C: 82 GB, pump 20:03Z, guardian alive (4), chunk 20 9/10 (T1 last).
- 20:10Z: governor v2 (G6) DISABLED action adapter + design/activation-gate record merged (`7ecc1b7457`; verifier ok
  after the resume: no live-action path even with valid policy + activation artifact; 12 tests). ROT rest list for
  OWNER filed (monitor v1.10 deploy, scheduled dry-run task, executor component, policy/activation artifacts).
  Reload chunk 21 (drain window) started 20:09Z after chunk 20 finished 9/10 (T1 held the news run). Drain state
  active=None (cooldown to 02:04Z). Fabric: 7 active, 18 cells/10 min, 21 GB free, C: 82.6 GB, pump 20:08Z.
- 20:45Z: drain-window winnability rule merged (`52c784feb1`, Opus wf_f29d8ff0-37c verified ok, 170 tests): no arming
  while a long-run row (Q07+ incl. news) is active, releasable short-row RAM must cover the need, early abandon when a
  long run appears; throttled drain_window_not_winnable events. Reload chunk 23 queued behind 22 (21: 6/10 at 20:32Z).
- 21:10Z–21:20Z: run_smoke report-shell race closed (`99fa0a7995`, Opus wf_2dc8f552-a32 verified ok, 54 tests incl. a
  pwsh unit test; run_smoke.ps1 CRLF byte-exact): shell signature + bounded 180 s finalize grace + UTF-16 journal
  cross-check → transient infra class REPORT_CAPTURE_INCOMPLETE (farmctl / p2_baseline / _phase_utils). False-zero
  sweep since 08-15 (`bd3ef7ff81`): 133 candidates, exactly ONE false zero (12580 Q03), 18 genuine zeros, 96 genuine
  below-floor, 5 evidence purged. 12580/AUDUSD Q03 append-only rerun enqueued `9cac4667` (from Q02 d53328e2, rerun of
  a64d18d3, ex5 9541ef44 unchanged) — run_smoke starts fresh per run, so the fix applies immediately.
- 21:35Z: **Auffangregel executed** (Vorlage 09:35Z, no OWNER answer within 12 h): governed hold RECOVERY_BUDGET_EXHAUSTED
  applied on the only pending 20085 recovery row `0bc6a5bc` (WS30 Q07) with the packet's exact reason/release
  condition (plan → apply, backup taken, row non-claimable, verdict untouched); XAUUSD `19d3d8e5` had reaped
  INFRA_FAIL at 17:31Z, EURUSD has no pending row → the r1-recovery track is parked. Fabric 21:35Z: 5 active (two
  Q10_NEWS incl. the 10700 expansion, two Q07, one Q04), 10.9 GB free → census latched (10 cells/10 min), CPU 52 %,
  C: 88.7 GB, pump 21:33Z, guardian alive, T_Live journal 21:04Z. 12580 Q03 `9cac4667`, 10911 Q05 `57aad04d`,
  10815 Q02 `bd12175c` pending on RAM. Reload chunk 21 8/10 (T1/T4 hold the news runs).
- 21:57Z: NEAR-OOM — free RAM 1.86 GB (available 1,854 MB): five testers admitted within four minutes (21:48–21:52Z)
  on flat 8 GB reservations while their working sets grew to 15.0 GB (10978 Q07 USDJPY H4), 11.6 GB (1634 Q05 XAUUSD),
  8.2 + 8.2 GB (news 41219, 10700 expansion), 5.8 GB (11015 Q07) = ~49 GB + 10 GB baseline. Kill rule (< 1.5 GB) not
  reached; re-measured after 45 s: 7.1 GB (10978 finished 21:59Z), 21.7 GB by 22:02Z → HOLD, nothing killed. The
  tester ledger recorded the run (peak 15.35 GB vs 8 GB flat) and the expectations file now carries
  fx_major|H4|backtest n=5 max 15.3 GB → the measured reservation applies from here (max(flat, measured)); other
  heavy classes self-calibrate after three samples. Mechanism: reservations decay faster than tester working sets
  ramp (history load takes minutes), so a burst of admissions overcommits — the ledger closes this per class.
- 22:38Z: loop round — fabric at its best of the day (31 cells/10 min, 9 active, 21.7 GB free, C: 88 GB, pump 22:38Z,
  guardian alive, T_Live journal 22:01Z); reload chunk 21 done 9/10 (T4 holds the 10700 expansion), chunk 22 started
  22:36Z. Census 21507 574/1085, 11910 274, 12710 140. 12580 Q03 `9cac4667`, 10911 Q05 `57aad04d`, 10815 Q02
  `bd12175c` pending (heavy classes). Finding: the winnability rule's hard 'no long-run active' block would keep
  drains from ever arming on a fleet that always runs news/Q07 rows although 32 GB baskets are arithmetically
  winnable beside them → small refinement commissioned (wf_ee80ee12-00f: count long-run RAM as non-releasable,
  abandon only on NEW long runs).
- 23:00Z: drain arming arithmetic merged (`996ec49a64`, Opus wf_ee80ee12-00f verified ok; 77 drain/census-first
  tests): long-run rows count as non-releasable instead of blocking; abandon only on a NEW long-run id. Reload
  chunk 24 queued behind 23 (22 at 6/10). Drain cooldown ends 02:04Z; 12580 Q03 `9cac4667` (32 GB basket) is the
  first row that can now arm a winnable drain beside the news runs.
- 23:41Z–23:55Z: stale DL-089 lane lock removed — DL089_CLAIM_PRUNING.ffb5ca86… (program DL089_QM5_21507_XAUUSD…,
  arm buy_045) created 04:18Z by T10's lane preflight, owner pid 37680 dead, 19.4 h old, no reaper → that arm's
  cells were unclaimable (dl089_claim_pruning_lock_busy). Finding: census cell dispatch has NO program-priority
  term (post_census → frontier → idle_program → age), i.e. round-robin across the 8 admitted programs: 21507
  (575/1085, next counter pair) got ~29 cells in 8 h while 12710/11910 ran 70-76 cells/h; XAUUSD cells take 3.8 min
  median (no runtime issue). Queue-order tie-break commissioned (wf_4b2b9b09-d04). Census 23:41Z: 21507 575,
  11910 344, 12710 216; 21505/XAGUSD 778/1085 and 20048/XTIUSD 582 with 0 active cells (lane sharing). RAM 5-11 GB.
- 00:15Z (04.09.): census queue-order tie-break merged (`224c46282c`, Opus wf_4b2b9b09-d04 verified ok; 97 + 132
  tests): spare census lanes now follow the OWNER queue order after the idle-program fairness key; pump uses it
  immediately, workers via reload chunk 25 (queued behind 24; chunk 22 at 7/10, 23/24 waiting). Fabric: 5 active
  (two news incl. 10700 expansion at 292 min, Q07 11015, Q06 11179, Q04), 7.8 GB free → census lanes latched;
  census 21507 578, 21505 778, 11910 372, 12710 225.
- 00:40Z–00:55Z (04.09.): **slot order ranks 1–4 completed** (GRÜN priority change under the same OWNER decision):
  dl089_matrix_service._queue_order ranks programs by queue_order_at OR Q12 created_at, so the four programs nearest
  the counter carried no order and had lost their K=8 slots to 8–19 percent programs (PROGRAM_SLOT_WAIT:K=8 since
  ~13:00Z: 21505/XAGUSD 112 measured + 666 pruned, 307 remaining; 20048/XTIUSD 503 remaining). Applied via
  set_dl089_queue_order.py plan→apply: 21505 07:57, 20048 07:58, 21507 07:59, 20266 08:00 (all 2026-08-29, before
  12710 08:02 / 11910 08:03 / 10700 08:04); 13213 keeps its 08-22 order; 10706/11422 stay deferred (2099).
  Reload chain consolidated: chunks 23/24/25 stopped, chunk 26 (all ten, idle-only, all merged worker code) queued
  behind chunk 22 (8/10). Fabric 00:38Z: 25 cells/10 min, 8 active, 23.7 GB free, no stale locks; 10700 expansion
  at 315 min still running.
- 00:55Z–01:05Z (04.09.): OWNER decided briefing items 2–4 ("2-4: freigegeben, deiner Empfehlung folgend"). Receipt
  decisions/2026-09-04_owner_receipts_briefing_2_4.md (`e956ffff5e`); three decision-bound Claude tasks reserved
  (253f7e09 news-gate a+e, b9f7a280 book V2/V4/V6+epoch, a4fb4108 FTMO rulepack). Execution launched as verified
  Opus workflows: wf_7c3a5e11-c3d (label fix, single-target lock, affected_entries wiring, readjudication CLI),
  wf_04d206e1-add (V2 OWNER_RATIFIED stamp, V4 two-layer standard in portfolio_correlation, G5 command epoch 07-19),
  wf_9448cf1a-0fc (official-rules snapshot 2026-09-02 + evaluator/rulepack pins). Live pointer, freeze and book
  stay OWNER acts. Morning briefing delivered 00:50Z; census 50 cells/10 min after the slot-order fix.

## 02:07Z 2026-09-04 - slot order rank 7 applied

- QM5_10700/XAUUSD Q12 `40e69c26-1ddb-5728-99a1-02b08f83c284` -> `queue_order_at = 2026-08-29T08:04:00+00:00` (plan+apply `set_dl089_queue_order.py`, DL089_PROGRAM_SLOTS=8; scratch `queue_order_r7_plan.json` / `queue_order_r7_apply.json`). Lineage: recompile -> fresh Q02 -> ... -> Q10_NEWS expansion `152e8d29` CONFIG_LOCKED 00:58Z -> Q11 PASS `e4097945` -> Q12 minted 01:28Z. Sibling QM5_41333 Q02 `bcac7790` PASS 01:29Z.
- Ranks 1-7 are now all written; the slot order is complete.

## 03:22Z 2026-09-04 - drain window closed, 44 GB holds

- Drain window armed 02:33:26Z for QM5_11129 Q07 `e046b36b` (reservation 44 GB, floor 14) was not winnable (free 19.6 GB + releasable tester working sets 25.5 GB < 48 GB) and held the fleet at 0 cells/10 min. Closed manually 02:52Z (`active=null`, cooldown until 04:21Z; before-copy in scratch `drain_window_before_0252Z.json`).
- Holds `RAM_WINDOW_44GB` (active=1, release_on_restart=0) placed on `e046b36b` (QM5_11129 Q07) and `bd12175c` (QM5_10815 Q02). Rollback: `farmctl release-hold`.
- Throughput recovered to 44-60 cells/10 min by 03:00Z after the claim-spacing phase of the nine workers reloaded by chunk 26.

## 04:14Z 2026-09-04 - Auffangregel executions 04:00Z

- Vein-1 wave 1: 16 FX rows of the first 30 packet rows requeued append-only (Q02 successors c3b82ffc, e0b5b369, 901d3f05, 525a75e4, 0d614c0a, 727fd995, 75b113ab, 2c7d0845, e5998de2, e3a60097, b31bd6bc, 90f77b53, 83ac79f0, 9a0ced77, c246db5e, 138e5d99); 14 index rows deferred (single_index_tick 44 GB class, unclaimable). Result file: scratch `vein1_wave1_result.json`.
- News-Gate A: RAM-gated expansion subcap 2->3 merged as 88be67be5b (122 tests green); idle-only worker reload chunk 27 started 04:12Z.
- Q08 stream reruns: due 05:00Z; commands extracted to scratch `q08_rerun_cmds.txt`.

## 05:01Z 2026-09-04 - counter 6/25, Q08 stream reruns (Auffangregel 05:00Z)

- QM5_21505/XAGUSD terminal: Q12 `540eadc0` NO_FILTER_CHANGE 04:29Z -> Q13 NO_PARAMETER_CHANGE 04:39Z -> Q14 KEEP_INCUMBENT 04:49Z; `book_build_guard --status --venue both` qualified_pairs = 6.
- Q08 sealed-stream reruns enqueued from `docs/ops/evidence/2026-09-03_q08_stream_reemission_packet.md` section 4 after re-running the section 5 pre-flight (all four PASS): `f62fe6b3` (QM5_1537/XAGUSD, rerun of 262514ac), `a2e1aba6` (QM5_10706/GBPUSD, rerun of 7855588a), `2bd0f95c` (QM5_11422/USDCAD, rerun of d3907c1a), `21dd6839` (QM5_13054/XTIUSD, rerun of d62d792e). Scratch: `q08_rerun_result.json`.

## 05:41Z 2026-09-04 - Q08 seals reproduced, sixth-pair rerun

- Reruns f62fe6b3 (QM5_1537) and a2e1aba6 (QM5_10706) finished PASS; re-emitted `portfolio_stream.content_sha256` equals the recorded seals byte-for-byte. `assemble_stream_bundle.py --out <scratch>/stream_bundle_0540`: bound 3 / refused 3.
- QM5_21505/XAGUSD (terminal 04:49Z) had the same missing-bytes gap; enqueued `15c1ec7b` (Q08, from Q07 `b837549a`, rerun of `9c51f7eb`, expected ex5 395c4747...) as an extension of the same Auffangregel class after the identical pre-flight.

## 06:09Z 2026-09-04 - counter 7/25, drain long-run refusal

- QM5_20048/XTIUSD terminal: Q12 `5a6d1b1c` NO_FILTER_CHANGE 05:48Z -> Q13 NO_PARAMETER_CHANGE 05:58Z -> Q14 KEEP_INCUMBENT 06:08Z; `book_build_guard --status --venue both` qualified_pairs = 7.
- Drain fix 5e8e5c9a2a (open drain refuses NEW long-run claims on the claim path); hold `DRAIN_DEFER_LONGRUN_BURST` on QM5_12580 Q03 `9cac4667` until the three pending Q08 reruns finish; worker reload chunk 28 started 06:08Z.

## 06:20Z 2026-09-04 - Codex model tiers merged with the tier layer disabled

- Merge b8c62c975a (wf_76cb7101-72e rounds 1-3, verified; round-3 residuals are tier-layer only). Machine env `QM_CODEX_MODEL_TIERS=0` set via `[Environment]::SetEnvironmentVariable(..., 'Machine')`; fresh-process probe: `codex_spawn_contract` flags [] / ledger not recorded, `command_for` argv identical to the pre-patch form. Router-side decision-bound pinning and payload capability union are active unconditionally.
- Round 4 (D8-D12) resumed on wf_76cb7101-72e as a delta against HEAD; the tier layer is switched on only after round 4 merges and OWNER states the Codex plan tier.

## 06:47Z 2026-09-04 - bundle 6/7, seventh-pair rerun, worker restart

- Q08 reruns 2bd0f95c (11422), 21dd6839 (13054), 15c1ec7b (21505) done/PASS; bundle dry-run bound 6 / refused 1 (QM5_20048/XTIUSD, seal a792e263...). Enqueued `a43559cd` (Q08 rerun of `3ee5c53c` from Q07 `bf54ff43`, expected ex5 1312391a...) after the identical pre-flight.
- 06:20Z free RAM 5.0 GB (two 11.5 GB Q08 runs + Q05/Q06/news); latch held; reload chunk 28 stopped after T4/T10 respawn was refused by the starter's headroom gate; both restarted 06:23Z via `start_terminal_workers.py --dedupe`; chunk 29 (T2/T3/T5/T7) started 06:45Z at 22 GB free.

## 07:00Z 2026-09-04 - Codex model tiers round 4 merged, observe mode live

- Merge a769c2f5b8 (round 4, D8-D12); machine env `QM_CODEX_MODEL_TIERS` removed 06:56Z; fresh-process probe with `QM_CODEX_MODEL_LEDGER_PATH` on scratch: tiers enabled, observe mode, 3 dispatches recorded, argv unchanged, live ledger untouched.
- Residual enforce-mode findings tracked as router task `453b8edf` (precondition for `window_enforcement_mode=enforce`, after the OWNER names the Codex plan tier).
