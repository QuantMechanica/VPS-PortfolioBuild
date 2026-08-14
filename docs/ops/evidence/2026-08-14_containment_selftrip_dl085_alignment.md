# 2026-08-14 — Containment self-trip: benign gate defers re-engaged fleet containment (DL-085 semantics alignment)

## Symptom (OWNER report ~12:30Z)

"Es läuft wieder kein Backtest." Fleet state: 0 terminal64 processes, 10/10
worker daemons alive, 1027 pending / 1 active work item, containment mode
`enabled:true` (`reason: runtime_stop_condition:isolation_gate`, recorded
2026-08-14T11:18:26Z, `source: automatic_stop_condition`). All workers
spinning on `custom_history_lease_busy` (containment ⇒ mandatory global
lease ⇒ factory serialized 1-wide; each claim burns minutes in gate audits).

Throughput evidence: 9 work items finished 09:00Z–12:25Z (vs. hundreds/day at
10-wide). DB active row `c997529a` (QM5_12849 XTIUSD Q08, T5) progressing.

## Root cause — three over-eager containment triggers vs. ratified DL-085

DL-085 (decisions/2026-08-14_self_healing_archive_gate.md, ratified, commit
4b43760ee) states: manifest gaps repair from the verified master tree;
**containment remains for master loss/mismatch only**. The runtime kept three
pre-DL-085 trigger sites that escalate benign, self-healing outcomes to
fleet-wide emergency:

1. **`_custom_history_gate` (terminal_worker.py:1119)** — engaged
   `engage_emergency_mode` on ANY non-PASS gate status, including audits whose
   findings were only torn family link counts (`ARCHIVE_LINK_COUNT_TOO_LOW`)
   and master-repairable gaps (`MANIFEST_ARCHIVE_FILE_MISSING`,
   `TERMINAL_MANIFEST_INCOMPLETE`).
2. **Run-result stop-condition text scan (terminal_worker.py:4224)** — the
   administrative defer result (`custom_history_gate_deferred`, claim
   released, attempt unchanged) carries
   `"reason": "CUSTOM_HISTORY_ISOLATION_FAIL_CLOSED"`; the casefolded
   substring scan matched the gate's own token `custom_history_isolation_fail_closed`
   → `runtime_stop_condition:isolation_gate`. **This is the 11:18:26Z trip**:
   T6 log line 12430 shows the defer (findings: 4× link-count + missing +
   incomplete) emitted at the same second as two successful master repairs
   (receipts `custom_history_repairs.jsonl` 11:18:26Z, EURAUD/2022 +
   EURCHF/2020 → T2, `REPAIRED_VERIFIED`). The gate healed the content and
   the defer's own reason string then stopped the fleet.
3. **`_privatize_custom_history_claim` except-path (terminal_worker.py:1203)**
   — engaged emergency for ANY copy-on-claim exception, including transient
   sharing violations (PermissionError) while other terminals' MT5 processes
   hold archives open — same class as the already-ratified MemoryError
   transient fix (commit 4f39be7b5).

Convergence proof that the defers were benign: every terminal logged fresh
`PASS_ISOLATED` audits after the trip (T6 line 12442, 12 lines after its
12430 defer); T5 claimed with lease token + audit sha at 12:25Z. Family
topology verified healthy: `fsutil hardlink list` EURCHF.DWX/2020.hcc = 9
links (8 terminal members + 1 preserved rollback-tree link; T2 + T9
standalone private inodes by design after master-copy repair).

Why the morning release didn't hold: containment released 09:26Z re-tripped
at 11:18Z through trigger (2) — with these triggers resident, ANY benign
defer re-trips, so every release is undone within hours. (Same mechanism as
the 08:06:56Z re-trip 3 minutes after the earlier release.)

## Fix (this commit) — align runtime with DL-085

`tools/strategy_farm/terminal_worker.py`:

- New `CUSTOM_HISTORY_BENIGN_FINDING_CODES` = {ARCHIVE_LINK_COUNT_TOO_LOW} ∪
  `custom_history_master.REPAIRABLE_FINDING_CODES`; new
  `CUSTOM_HISTORY_GATE_DEFER_ACTIONS` (the three administrative defer actions).
- `_custom_history_gate` engages emergency only via
  `_custom_history_gate_fail_is_emergency`: master repair status
  ERROR/PARTIAL (master cannot vouch) **or** any finding outside the benign
  classes (cross-terminal alias, ACL, protected-root). Benign-only fails
  defer the claim attempt as before — fail-closed locally, no fleet stop.
- `_custom_history_stop_condition` returns None for administrative defer
  results (their reason string is the gate's own token, not run evidence).
  Real run results are still scanned (error [32] / history sync / archive
  drift / missing real-ticks marker all still stop the fleet).
- `_privatize_custom_history_claim` engages emergency only for non-transient
  exceptions (`_is_transient_gate_io_error` classification, mirroring the
  gate's transient-IO path). Transient copy errors defer the attempt only.

Unchanged fail-closed behavior: non-transient gate exceptions still contain;
gate defers still release the claim without burning attempts; the gate never
admits a terminal whose audit did not PASS.

## Test evidence

`tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py`
rewritten/extended: benign-fail defers without containment; master repair
PARTIAL/ERROR contains; non-benign finding contains; defer results don't trip
the stop-condition scan while real error-32 run results still do; transient
copy-on-claim errors defer while non-transient ones contain.

Runs: 26 passed (isolation + variant-A suites); 147 passed, 4 subtests
(copy_on_claim, master, smoke_admission, mt5_history_isolation, worker
adoption/atomic_claim/lock_storm/identity/q_phase_stall/staged_ex5).

## Recovery sequence (this incident)

1. Commit fix + tests + this evidence + DL-086 decision doc.
2. `Factory_OFF.ps1` (PS5.1, ceremony; workers must restart to load the fix —
   no self-reload).
3. `custom_history_migration.py release-containment` during OFF quiet lease,
   owner receipt = `owner_window_receipt_standing_unlimited.json` (DL-086).
4. Mint runtime-activation decision, commit decision + sidecar.
5. `Factory_ON.ps1 -CanonicalRuntimeHost -NoPause` (PS5.1).
6. Verify: containment `enabled:false`, ≥2 concurrent claims, run_results
   flowing, no emergency re-engagement on subsequent benign defers.

Ceremony outcomes are appended below after execution.

## Ceremony record (appended)

- 13:57:01Z containment released (standing pair DL-086:
  `archive_manifest_owner_approved_standing.json` +
  `owner_window_receipt_standing_unlimited.json`, dual audits 3+4). Stale T5
  lease reaped fail-closed (owner pid 11276 dead; `.stale` sidecar archived);
  orphaned claim c997529a reset to pending.
- ON attempt 1 (RTA-2026-08-14-DEFERFIX): post-start health gate PASSED,
  aborted at restart-hold release — `database is locked` (>30s writer).
  Flag → OFF_RECOVERY_REQUIRED per runbook.
- OFF recovery ×2 blocked by a SYSTEM-context managed Codex review exec
  (`job_open_failed error 5`, the known 2026-08-12 class; lease-capped
  60 min). Exec finished on its own; third OFF run QUIESCENT 14:23Z.
- ON attempt 2 (RTA-2026-08-14-DEFERFIX2): hold plan COMMITTED, aborted at
  post-commit evidence — WAL FULL checkpoint starved by moving reader/writer
  churn (log 57→64, checkpointed 54→55 across 36×2.5s). Root: with
  containment now released, ten workers cycle gate+claim every 2s against the
  held mutation lock (yesterday's ceremonies ran under lease-serialized
  quiet, hiding this). Fix: dedicated 20–30s backoff for
  `factory_mutation_lock_busy` declines (logging kept, 60s-throttled) +
  checkpoint envelope 36→72 attempts.
- ON attempt 3 (RTA-2026-08-14-DEFERFIX3): `database is locked` at the
  release again (~:10 past the hour, same as attempt 1 at :14 — an hourly
  ea_metrics-scale writer outlasts the 30s busy timeout; attempt 2 released
  clean mid-hour at ~:42). Fix: bounded lock-retry around the release
  transaction, 8×(30s busy + 25s sleep) — provably safe (rollback before
  re-raise + append-only nonce-consumption guard) (b8930c05f).
- ON attempt 4 (RTA-2026-08-14-DEFERFIX4): release COMMITTED via retry;
  post-commit evidence converged to 43/44 frames exactly as the 72×2.5s
  envelope expired (a reader pinned frame 24 for ~3 min, then released).
  Fix: envelope 72→240 attempts / 10 min (137551183). Reader identity still
  open — same class as the 2026-08-12 WAL-reader-pin note.
- Recurring OFF-drain blocker between attempts: the Codex orchestration
  task runs directly as SYSTEM, so its exec job objects are SYSTEM-owned
  while the pacer (reaper) relaunches into the console session as qm-admin
  → `job_open_failed error 5`. Worked around via a transient one-shot
  SYSTEM pacer task, then via bounded waits for the 60-min lease caps.
  **Follow-up: align spawner/reaper identities (route the orchestration
  action through run_in_console_session.ps1 like the pacer, or run the
  pacer as SYSTEM).**

## Residual risk / follow-ups

- The archive eater's root cause (shared family inodes × exclusive MT5 opens)
  is mitigated, not eliminated; organic repair rate post-09:55Z resume was
  ~7 files/83min under load. DL-085 self-heal absorbs this; Codex follow-up
  tasks (leg-blocking, identity-separation, sweep-exclusion,
  priv-crash-safety, pump-cap) address the source.
- `custom_history_repairs_24h` health FAIL (57>10) is dominated by the 49
  one-time mass-restore receipts of 09:10Z; organic rate is below threshold.
  Expect the FAIL to clear as the 24h window rolls past 2026-08-15T09:10Z.
- Codex max-effort review `review-dl085-master-tree-package-20260814` still
  owes its verdict; this change is in scope for that review.
