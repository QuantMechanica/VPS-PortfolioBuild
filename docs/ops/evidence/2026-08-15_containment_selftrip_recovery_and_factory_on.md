# 2026-08-15 — Containment self-trip recovery, factory ON, backtests resumed

Author: Claude (remote-control session, OWNER directive: "Bring die Fabrik und
damit die Backtests wieder zum Laufen")

## Incident (2026-08-14 evening, all times UTC)

- Fleet ran 10-wide; physical RAM was exhausted (1.08 GiB free of 63.12 GiB at
  21:58:56Z per `docs/research/FX_COINTEGRATION_FRONTIER_RESOURCE_CEILING_STOP_2026-08-14_215856Z.md`;
  `MemoryError()` events in T1/T2/T6/T7/T8/T9 worker gates,
  `terminal_worker_T3.log.err` died on raw `MemoryError`).
- **21:49:45Z — containment self-trip.** T8 and T9 ran the custom-history gate
  concurrently against the same 4 missing-archive findings
  (GBPAUD 2022, GBPCAD 2019/2020 → T5; EURNZD 2020 → T7). T9 won every copy
  (receipts `custom_history_repairs.jsonl` 21:49:40Z, all `REPAIRED_VERIFIED`);
  T8 saw 3× `ALREADY_PRESENT_VERIFIED` + 1 race failure →
  `master_repair.status=PARTIAL` (`terminal_worker_T8.log` line 11146) →
  `_custom_history_gate_fail_is_emergency` → fleet containment engaged
  (`custom_history_isolation_gate_failure`, `automatic_stop_condition`).
  The master tree vouched throughout; no integrity fact was in question.
- **21:56:53Z — Factory_OFF died early** (flag stuck at `OFF_REQUESTED`,
  no `task_enabled_before`), itself a casualty of the RAM exhaustion. Worker
  daemons T1/T2/T6/T7/T8/T9 died 21:56:07Z; T3/T4/T10 survived as stale
  pre-fix daemons.
- **21:56:42Z — classifier fix committed** (`a366cf6dc`): all-transient repair
  failures now aggregate to `PARTIAL_TRANSIENT_IO`/`ERROR_TRANSIENT_IO`,
  which defer the claim instead of engaging containment
  (`custom_history_gate.py` repair-status aggregation).

## Recovery (2026-08-15, all times UTC)

1. 06:37:04Z `Factory_OFF.ps1 -NoPause` (PS 5.1) completed the interrupted OFF
   via the designed `isEmergencyRequestState` path (v2 + `OFF_REQUESTED` + no
   saved task map → fresh capture; the 21 quiescence tasks still matched the
   OWNER-approved map because the crashed OFF never reached them). Evidence:
   `D:\QM\reports\maintenance\factory_off\mnt046_factory_off_quiescence_20260815T063704Z_1600.json`.
2. 06:41:39Z runtime-activation decision
   `RTA-2026-08-15-CONTAINMENT-SELFTRIP-RECOVERY` minted
   (decision_sha256 `16f63f83…`, flag_sha256 `d2e5fc7c…`), committed `c2dc7b0b6`.
3. 06:4x Z `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause` (PS 5.1):
   flag removed, tasks restored, 10/10 worker daemons up. Post-start health
   gate checks tasks/daemons/session only, so the still-engaged containment
   could not abort the ceremony (claims defer administratively).
4. First scheduled pump cycle timed out the dead-claimed hung row
   (QM5_1537 GDAXI.DWX Q02, claimed_by T3, age 522m > 130m) → zero active
   rows (release precondition).
5. 06:58:17Z containment released via
   `release_containment_standing.py selftrip_repair_race_partial_ram_exhaustion_classifier_fix_a366cf6dc`
   under DL-086 standing authorization
   (`owner_window_receipt_standing_unlimited.json` +
   `archive_manifest_owner_approved_standing.json`, manifest_sha256
   `fe0dd0fd…`). Mode receipt: `enabled:false`, mode_sha256 `28a20f8e…`.
   The lease-flicker retry loop absorbed one transient worker-gate lease.

Recovery-order note for future incidents of this shape: farmctl `pump`/`repair`
are FACTORY_OFF-blocked, and the containment release requires zero active
rows — so a dead-claimed active row can only be cleared **after** ON.
The working order is: OFF-complete → mint → ON (claims defer under
containment, which is harmless) → pump clears stale actives → standing
release → claims flow.

## Disclosure — accidental receipt overwrite (self-inflicted, corrected)

Claude invoked `open_recovery_window_and_release.py --help` and
`finish_containment_release.py --help` expecting argparse usage output.
Neither script uses argparse; the first treats `argv[1]` as the OWNER
countersignature and immediately re-wrote
`owner_window_receipt_t8_restore.json` with `signature: "--help"` (and
`attach-owner-approval` re-derived the t8 manifest embedding it). The
release step then stopped fail-closed on quiescence, so the fabricated
receipt was never consumed by a release. Both corrupted artifacts are
renamed `*.INVALID_*20260815*` in
`D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\`;
the actual release used only the DL-086 standing pair. The original t8
receipt content (window closed 2026-08-14T08:03Z) is unrecoverable but was
already historically expired and superseded by DL-086.

## Simplification (OWNER mandate: reduce over-engineering)

- `release_containment_standing.py` copied into the repo
  (`tools/strategy_farm/`) as the one canonical release entry point —
  reusable, no per-incident window, no signature, only `--reason` varies.
- RECOMMENDED (blocked for Claude by the permission classifier, needs OWNER):
  delete the superseded one-offs
  `tools/strategy_farm/open_recovery_window_and_release.py` and
  `tools/strategy_farm/finish_containment_release.py`. Both are hardwired to
  the closed 08-13 t8 ceremony, and their bare-`argv` signature handling is
  exactly the fabrication hazard demonstrated above.
- PROPOSAL (not implemented; changes fail-closed semantics — OWNER call):
  exempt `farmctl repair` from the FACTORY_OFF block. It is the designed
  recovery tool ("idempotent; safe to run any time") yet unusable in the OFF
  window where stale-active cleanup is needed; today that cost one extra
  ON-before-release ordering constraint.

## Act 2 — first ON aborted at the evidence lottery; fixed and re-run

The 06:42Z Factory_ON passed its post-start health gate (46 tasks,
10 workers) and then FAILED CLOSED at 07:32Z in the restart-hold
post-commit evidence step: `checkpoint_wal` (FULL, 240×2.5s) never saw
busy==0 under moving reader churn, and `Invoke-FailClosedRollback` re-asserted
`OFF_RECOVERY_REQUIRED` (task map preserved) while retaining the mutation
lock. Two root causes, both fixed in `a4bbf2a9e`:

1. **Pump/health zero-trade detectors swept all 74,365 historical Q02/P2
   rows with per-row evidence-file disk reads.** On the cold post-recovery
   cache the 06:52Z pump held its DB write transaction for 40+ minutes
   inside `_detect_zerotrade_dead_eas` (py-spy stack evidence), starving
   the agent router (`database is locked`, 4 consecutive 0x1 runs) — the
   exact latch the ON envelope was waiting for. Two `farmctl health` runs
   crawled the same sweep read-only, providing the reader churn that
   defeated the checkpoint. Both scans are now bounded to 14 days
   (2,545 rows).
2. **`checkpoint_wal` raised fail-closed on busy exhaustion** although the
   released-holds transaction is WAL-durable regardless; third ceremony
   lost to this step (R8, R10 2026-08-12, today). It now returns a warning
   carrying the pin-vs-churn progression and the envelope is 12×2.5s.

Retry ceremony: Factory_OFF 08:02:14Z (MNT-046
`mnt046_factory_off_quiescence_20260815T080214Z_16848.json`, stale
mutation lock reaped by the drain helper), decision
`RTA-2026-08-15-CHECKPOINT-BESTEFFORT-RETRY` (commit `f3fab77cd`),
Factory_ON exit 0 at ~08:20Z with `post_commit_evidence.status=PASS` and
the checkpoint recorded as warning — the fix observed working in
production on first contact.

## Outcome (08:33Z)

- 10/10 terminals hold active claims (Q02/Q04/Q08 mix, including the
  QM5_1537 family from last night and the QM5_1257 GBPUSD/USDJPY
  cointegration fallback on T8).
- terminal64 + metatester64 testers running on T1/T5/T9; remaining slots in
  copy-on-claim spin-up. Pending queue draining (1025 → 1015).
- Containment `enabled:false`, RAM 53.7 GiB free.

## Act 3 — claim-time backtest orchestration (OWNER directive, same day)

OWNER observed the restart pattern "many MT5s start, then collapse to ~2"
and asked for staggered worker starts, same-symbol diversion, and
resource-gated waiting ("bis die Situation sich nachhaltig verbessert hat").
Root evidence for the collapse: single testers ballooning (46.8 GiB working
set on T6, QM5_1537 SP500.DWX Q02, 12:15 local) starving the rest of the
fleet into MemoryError/INFRA_FAIL churn.

Design answer: no separate orchestrator component — the atomic claim gate in
`terminal_worker.claim_atomic` (BEGIN IMMEDIATE) already is the
deterministic orchestrator (symbol cap, (ea,symbol) dedupe, multisymbol
serialization, commit-headroom admission). Extended it in `6dcb202df`:

- Fleet-wide claim stagger: max one successful claim per 60s
  (`claim_class_ledger` read + claim commit in one transaction).
- RAM hysteresis: trip <6 GiB free, resume only >=12 GiB.
- CPU admission: GetSystemTimes delta over the loop cadence; trip >97%
  sustained, resume <=90%. Deliberate OWNER tradeoff vs maximal slot count.
- `CLAIM_SYMBOL_ACTIVE_CAP` 4 -> 3 (the fourth same-symbol claim diverts).

Codex lane (revived by the 08:20Z ON) concurrently fixed the stall watchdog:
a valid-report latch now gets 1200s bounded post-process grace (300s flat
grace had released QM5_1257 between report 08:39Z and summary 08:46Z —
duplicate retry). Claude-reviewed and committed `3f9aac730`; its unfinished
QM5_1257 half-life sign-fix rework was preserved as
`codex_outbox/QM5_1257_halflife_sign_fix_20260815_partial.patch` and the
source restored (stale-binary/phantom-build hygiene).

Ceremony: OFF 10:20:49Z (MNT-046 `...102049Z_2320.json`) → decision
`RTA-2026-08-15-CLAIM-ORCHESTRATION` (`b3a76f2b6`) → ON exit 0 ~10:30Z.

**Ramp verification (10:41Z):** post-ON claims at 10:35:07 / 10:36:52 /
10:38:46 / 10:40:44 — ~2 min apart instead of a thundering herd, on four
distinct symbols (XAGUSD, WS30, XAU_XAG basket, GDAXI). Suite evidence:
156 tests green (atomic-claim, dispatch-serialization, WSA-claim,
calendar-gate, adoption, maintenance-control) + new `test_claim_spacing.py`;
`tests/conftest.py` zeroes the stagger for queue-semantics tests.

## Act 4 — sparse-contract field regression, terminal healing, restart

The activated sparse contract (act 3) caused a total production stall:
**100% of post-activation runs returned BARS_ZERO** despite verified
restores (receipt 108/108 restored `PASS_PRIVATIZED`; files on disk).
Controlled experiments in the OFF window isolated the layer:

- Runs A-C (T3/GBPUSD direct terminal64 invocations): invalidating the
  per-symbol `.hc` bar caches, `ticks.dat`, agent bases, and tester cache
  all left "0 ticks, 0 bars / 42 bytes of tick data".
- Run D: even T3's never-pruned first-claim symbol (XAGUSD) was dead —
  the prune poisons terminal-level data visibility beyond restored files.
- Run E (control, untouched T9): healthy — 1171 bars, 214.3M real ticks.
- Key mechanism: **MT5's `ticks.dat` is an import-time tick catalog the
  terminal does NOT regenerate from `.tkc` archives** (deleted → recreated
  empty). Restore-the-files alone can never recover tick visibility.

A plain code rollback was insufficient: terminals were already physically
pruned, and the pre-sparse gate would have healed them via per-terminal
private master copies (~80GB × 7 > D: free). The emergency OFF stopped the
first post-rollback ON before any claim ran.

**Healing (executed ~17:03 local):** untouched T9 (T5/T10 also intact)
served as source: 26,758 hardlinks restored the missing manifest archives
into T1-T4/T6-T8 (0 bytes, family topology = the pre-sparse Variant-A
layout), T9's 37 per-symbol `ticks.dat` catalogs copied to each, stale
`.hc` caches dropped for rebuild. Claim-privatized files kept. Verification
on healed T3: 260 bars / 46.6M ticks (1-year window) vs 0/0 before.
Script: session scratchpad `heal_pruned_terminals.py`; receipts in this
doc's counts.

Restart: decision `RTA-2026-08-15-HEAL-PRUNED-TERMINALS`, ON exit 0
(~17:15 local). Sparse task 71eba21c reset to OPS_FIX_REQUIRED with the
catalog-lifecycle requirement and a MANDATORY real-terminal acceptance run
before any future activation.

**Process lesson (mine):** I activated on 196 green unit tests and made
the acceptance observational-after instead of the pre-activation
real-terminal run the design called for. Unit tests cannot see MT5
terminal internals; ceremony-gated activations of Custom-history behavior
get a live acceptance run first, every time.

## Act 5 — QM5_1537 family-stop after disk-burn orphan (evening, ~20:00-20:20Z)

Context: Codex delivered both QM5_1537 rescue analyses (tasks 5b827de5 +
6aa33aa5); Claude review closed both APPROVED at ~19:47Z. Root cause on
record: every host symbol of the 37-symbol basket triggers full foreign
tick-corpus synchronization (`CopyClose` on tick-backed `.DWX` symbols) —
~137GB agent workspace, host-independent. FX hosts are additionally proven
no-signal by the lower-bound rank replay (rank never better than 4; adding
symbols cannot improve ordinal rank). Implementation task `a96ddcdd`
(bound monthly sleeve calendar) enqueued and IN_PROGRESS at Codex.

Observation (20:00-20:10Z): NZDJPY run_03 on T4 was rebuilding the tick
corpus at ~1GB/min; D: fell 71.5 -> 41.9GB free (ENOSPC in ~40min — the
same window that killed runs 1-2 and tripped containment at 18:47Z). The
watchdog had requeued row `143f71c2` to pending at 20:07Z (silent
tick-sync phase reads as a stall), so the T4 tester pair was an **orphan**
burning disk for an unclaimed row that was immediately re-claimable.

Actions (evidence-first, in order):

1. **Family-stop (reversible):** all 28 pending `QM5_1537` rows deferred via
   `launch_not_before_utc=2026-08-25T00:00:00Z`, reason
   `qm5_1537_family_stop_await_a96ddcdd_calendar_rework_20260815_footprint_137gb`.
   Verdicts untouched; post-rework the family requalifies via
   `seed-fresh-q02` with the new ex5 sha regardless. This also extends the
   four heavy rows whose earlier deferral would have lifted 08-16T08:00Z
   straight back into the footprint trap.
2. **Orphan kill (path-anchored):** T4 `terminal64.exe` + `metatester64.exe`
   (command lines verified `D:\QM\mt5\T4\*`); T_Live, FTMO, T3 untouched.
3. **Reclaim:** `QM_StrategyFarm_TesterCachePurge` triggered; D: free
   41.9 -> 203.2GB.

Rationale for not letting run_03 finish: the run could not complete on the
available disk (corpus already ~137GB, D: 41.9GB free, burn ongoing), its
predicted outcome (genuine 0 trades) was already mathematically established
by the approved analysis, and another ENOSPC window would have endangered
the healthy T3 metals-basket run plus re-tripped containment through the
resident workers' pre-fix classifier (ENOSPC whitelist loads only at the
next ceremony). The earlier "first FX data point" value assessment was made
before the no-signal proof existed; the informative runs for this family
are XNGUSD/XTIUSD/XAGUSD (post-rework), not FX hosts.

Remaining after Act 5: T3 QM5_20206 XAU/XAG basket is the only active
claim; zero-active window (release + ENOSPC-fix ceremony) arrives when it
completes.

## Open risks

- **RAM exhaustion is the recurring ambient cause** (2 events in ~30h:
  pre-reboot pump death 08-14 morning; this incident 08-14 evening). The
  classifier fix removes the containment *symptom*; the memory pressure
  itself is unaddressed. Watch `mt5_worker_saturation` vs RAM headroom under
  full 10-wide + XAU-4 load.
- **Archive eater still active**: 114 master-repairs/24h (health FAIL,
  threshold 10). DL-085 master coverage holds (all repairs verified), but the
  loss rate needs the dual-forensics follow-up before it exceeds master
  coverage.
- Codex build lane silent (auth_age 62h, needs OWNER `codex login`) — build
  throughput only, backtests unaffected.
