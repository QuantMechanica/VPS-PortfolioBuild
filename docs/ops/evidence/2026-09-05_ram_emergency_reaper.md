# RAM emergency reaper + per-EA memory expectations + idle-loop MemoryError hardening

Date: 2026-09-05

Branch: `agents/board-advisor`

Task: `924c36df` (decision-bound Claude lane; OWNER-visible)

Outcome: `IMPLEMENTED; TESTS GREEN; APPEND-ONLY` — code + tests only. No gate
threshold, verdict, T_Live, or containment change. Backtests are never
throttled by any change here; the reaper only reclaims an already-runaway
tester after the host is already in a fail-state the OS would otherwise resolve
by killing idle workers.

All source/line references below are to
`tools/strategy_farm/terminal_worker.py` at the committed state of this branch.

---

## 1. The incident (2026-09-04, ~08:00–08:46Z)

Reconstructed read-only from `D:/QM/strategy_farm/logs/terminal_worker_T*.log`.

- **08:01:32Z** — T9 claimed work item
  `bd18ccaa-e68e-4420-a854-34b6772e4339` = **QM5_10395 / EURJPY.DWX Q05**
  (`terminal_worker_T9.log`, `event=claimed`, `claim_write_lock_ms=5.18`). The
  child terminal64 tree started ~08:02:05Z.
- **~08:04:52Z** — T10 `commit_headroom_low_pause` recorded the runaway in its
  `commit_reservation_detail`: item `bd18ccaa`, `ea_id QM5_10395`,
  `reservation_class "ordinary"`, `expected_peak_gb 8.0`, **`measured_gb 22.16`**,
  `reservation_gb 0.0` (the decaying reservation had fully faded while the job
  was still growing toward the reported ~27 GB working set).
- **collapse** — free RAM fell across the fleet: T1 `ram_low_pause` samples show
  `free_ram_gb` of `4.8 → 4.3 → 4.2 → … → 0.6 → 0.4` GB (min 0.4 GB observed;
  the incident brief cites 0.6 GB). `ram_low_pause` correctly deferred **new**
  claims but has no mechanism to reclaim the already-running 22–27 GB tester.
- **workers killed outright** — no `worker_exit` line precedes any restart in
  `terminal_worker_T9.log` (`grep -c worker_exit` = 0). The orderly-exit tracer
  (`_install_exit_tracer`, emits `worker_exit`) never fired, proving the workers
  were TerminateProcess'd by the OS under memory pressure, not lost to an
  uncaught Python exception. T1/T3/T10 resumed ~08:25Z (down ~16 min); T9
  resumed ~08:46Z (down ~44 min), recovering the claim only via
  `release_stale_claims_for_terminal` on restart (`released_stale_claims` for
  `bd18ccaa`), i.e. by luck of the restart, not by any controlled action.

The DB row afterwards: `status=pending, verdict=NULL, claimed_by=NULL,
prior_failure=worker_restart_released_stale_claim` — recovered, but attributed
to a stale-claim sweep rather than a diagnosed memory event, and with the 27 GB
peak **never recorded anywhere**, so admission would repeat the mistake.

### Two independent defects

1. **No reaper.** The RAM guard loop (`run_loop`, the `while not _STOP:` body)
   samples free RAM once per idle pass and, on a trip, either compile-bypasses
   or prints `ram_low_pause` and `continue`s. It pauses NEW claims; it cannot
   act on a busy peer's runaway tester. A worker actively running a tester is
   blocked inside `_run_claimed_item`/`_monitor_run` and never re-enters the
   guard, so any reaper must be a cross-terminal action taken by an **idle**
   worker.
2. **The peak is never learned.** `_write_tester_memory_ledger` is called only
   at the END of `_monitor_run` (log-bomb / timeout / finished). A killed run
   writes no ledger row, so QM5_10395's ledger max stayed ~4.4 GB and the
   admission gate would keep reserving 8 GB.

---

## 2. Deliverable (1): RAM emergency reaper

New constants (`terminal_worker.py`, RAM section): `RAM_EMERGENCY_FREE_GB=2.0`,
`RAM_EMERGENCY_CONSEC_SAMPLES=2`, `RAM_EMERGENCY_WS_RESERVATION_MULTIPLE=2.0`,
`RAM_EMERGENCY_COOLDOWN_SECONDS=90.0`, `RAM_EMERGENCY_LOCK_STALE_SECONDS=60.0`,
`RAM_EMERGENCY_LOG_THROTTLE_SECONDS=300.0`, env kill switch
`QM_DISABLE_RAM_EMERGENCY_REAP=1`, state-dir override
`QM_RAM_EMERGENCY_STATE_DIR`, and `_LIVE_TERMINAL_PATH_MARKER="T_LIVE"`.
Per-worker counter `_RAM_EMERGENCY_STATE`.

Call site: one line added at the top of the guard loop, right after
`free_ram = _free_ram_gb()` — `_maybe_ram_emergency_reap(root, terminal,
free_ram)`. It runs every idle pass so the consecutive-sample counter is exact,
and is near-zero cost while free RAM is healthy.

Control flow:

- **`_maybe_ram_emergency_reap`** — kill switch check; resets the counter and
  returns when `free_ram >= RAM_EMERGENCY_FREE_GB` or when disabled; otherwise
  increments the consecutive counter and, only once it reaches
  `RAM_EMERGENCY_CONSEC_SAMPLES` (2 passes of ~20–30 s ≈ 40–60 s of sustained
  <2.0 GB free), calls `_run_ram_emergency_reap` and resets the counter (a
  second victim must re-confirm the threshold).
- **`_run_ram_emergency_reap`** — wall-clock cool-down check
  (`_ram_emergency_in_cooldown`), then a cross-worker file lease
  (`_ram_emergency_reap_lock`, atomic `O_CREAT|O_EXCL`, stale-broken after
  `RAM_EMERGENCY_LOCK_STALE_SECONDS`) so **only one of the ten workers acts per
  window**; cool-down re-checked inside the lock. Enumerates factory testers,
  resolves each to its active work item, filters, ranks, kills, records, and
  requeues. The state-file lease (not the SQLite mutation lock) was chosen so
  the ~PowerShell kill can run without holding any DB write lock; the only
  SQLite write is the short `_defer_ram_emergency_reap` via `_with_sqlite_retry`.

### Path anchoring (T_Live can never be selected)

`_factory_terminal_from_image_path` returns `T1`..`T12` only when the image
path's IMMEDIATE parent directory is `Tn` with `n∈1..12` and the exe is
`terminal64.exe`; it rejects any path containing the `T_LIVE` marker first.
`C:/QM/mt5/T_Live/terminal64.exe` has parent `T_Live` → structurally excluded.
The anchor matches farmctl's `Get-CimInstance … -match '\\(T(?:[1-9]|1[0-2]))\\'`
regex exactly. The chosen victim is re-checked with the same anchor and an
explicit `assert _LIVE_TERMINAL_PATH_MARKER not in image_path.upper()` before
any kill.

`_enumerate_factory_testers` reuses the existing `_process_private_snapshot`
(Toolhelp32 + psapi) working-set/image cache, adds full image paths via
`QueryFullProcessImageNameW` (`_query_full_process_image_path`) and creation
time via `GetProcessTimes` (`_process_creation_time`), and sums the subtree
working set (terminal64 + descendants), which is the figure that ballooned to
27 GB (the terminal64 process itself is ~2 GB). Fail-open `[]`.

### Selection

Among running factory testers, a candidate must: (a) resolve to an active work
item (`_active_work_items_by_terminal`, keyed by `claimed_by`); (b) NOT be a
`COMPILE_EA` run; (c) have subtree working set **> 2× its reservation**, where
the reservation is the live admission reservation from
`_ram_reservation_for_candidate` (ordinary=8 → threshold 16 GB; the 27/22 GB
incident clears it; an index-tick 44 → threshold 88 GB is untouched; once the
per-EA expectation learns 27 GB the reservation becomes 27 and the threshold 54,
so a correctly-reserved heavy EA is no longer reaped — self-correcting with
deliverable 2). The **newest** qualifying tester wins (largest `GetProcessTimes`
creation FILETIME); ties break on larger working set, then higher pid. A tester
with no resolvable work item is never reaped.

### Kill, ledger, requeue (append-only)

1. `farmctl._stop_pid_tree(victim_pid)` — the existing pid-scoped subtree kill
   (safe from a non-owning worker; same mechanism as the timeout kill).
2. `_record_ram_emergency_ledger` synthesizes one
   `qm.tester_memory_ledger/v1` row from the victim work item + measured working
   set, `outcome="ram_emergency_reap"`, so the per-EA key (deliverable 2) learns
   the true peak — the cross-deliverable dependency the scout flagged.
3. `_defer_ram_emergency_reap` mirrors `_defer_runner_death`: `status='pending',
   verdict=NULL, claimed_by=NULL` (re-runnable) under
   `WHERE id=? AND status='active' AND claimed_by=?` so an existing verdict is
   never overwritten; the reason (`prior_failure='ram_emergency_reap'`, the full
   `ram_emergency_reap` facts dict with `taxonomy='infra'`, and a
   `ram_emergency_reap_count`) is appended to the payload. Because the kill
   precedes the requeue, the terminal is already free when the row goes pending;
   if the victim's own worker is still alive it independently requeues via
   `_defer_runner_death_or_hold` (both idempotent under the same WHERE clause).
4. Structured event `ram_emergency_reap` logs the full arithmetic: free-RAM
   samples, threshold, victim terminal/pid/image path/item/ea/symbol/phase,
   ram_class, reservation, multiple, kill threshold, observed working set,
   candidate count, and killed/ledger/requeued outcomes.

### Idempotency under 10 workers

Cool-down file (`ram_emergency_reap_state.json`, wall-clock `last_reap_epoch`)
plus the atomic lock file (`ram_emergency_reap.lock`) mean exactly one worker
reaps per ≥90 s window; the others observe cool-down or fail to acquire the lock
and do nothing. Wall-clock (not `monotonic`) is used deliberately so the
cool-down is comparable across processes.

---

## 3. Deliverable (2): per-EA tester memory expectations

`_compile_tester_memory_expectations` now emits, alongside each asset-class key
`symbol_class|timeframe|run_kind`, a per-EA key
`ea:ea_id|timeframe|run_kind` (`_tester_memory_ea_lookup_key` /
`_tester_memory_ea_key_from_row`) whenever the row carries EA identity. The `ea:`
namespace keeps the two families disjoint in the flat `keys` map; the
expectations schema is bumped to `qm.tester_memory_expectations/v2` (the reader
is schema-agnostic, so v1 files keep working). The ledger itself is unchanged
and append-only.

`_measured_ram_expectation_gb(symbol_class, timeframe, run_kind, *, ea_id=None)`
applies the precedence exactly as specified via `_tester_memory_key_max_gb`:
the class value keeps its `TESTER_MEMORY_MIN_SAMPLES` (3) floor; the per-EA
value needs only `n>=1` and WINS when its recorded max exceeds the class value
(or when there is no class value). `_ram_reservation_for_candidate` passes the
item's `ea_id`. Net effect: after one reaped 27 GB run is captured in the
ledger, QM5_10395/EURJPY|H4|backtest reserves 27 GB on the next admission
instead of 8 (`_resolve_ram_reservation_gb` still gates on >
`TESTER_MEMORY_HEAVY_GB`, and 27 > 10). Multisymbol and OPT_CENSUS rows keep
their flat class (the resolver's existing guards).

---

## 4. Deliverable (3): idle-loop MemoryError hardening

The `while not _STOP:` body of `run_loop` is wrapped in `try: … except
MemoryError:` (verified whitespace-only re-indent + wrapper via `git diff -w`).
On a MemoryError in the idle/guard/claim section the worker logs once per
`RAM_EMERGENCY_LOG_THROTTLE_SECONDS` (`_log_idle_memoryerror`,
`event=idle_loop_memoryerror`), sleeps `RAM_GUARD_SLEEP_SECONDS + jitter`, and
`continue`s instead of propagating to `raise SystemExit(main())`. The existing
`except Exception` around `_run_claimed_item` still converts a MemoryError DURING
a run into a per-item INFRA_FAIL, so the new handler only covers the idle path.
The guardian respawn path (`start_terminal_workers.py`) is unchanged and not
duplicated — this change only stops the worker dying so the guardian has nothing
to respawn.

---

## 5. Tests

Command:

```
python -m pytest \
  tools/strategy_farm/tests/test_terminal_worker_ram_emergency_reaper.py \
  tools/strategy_farm/tests/test_tester_memory_per_ea_expectations.py \
  tools/strategy_farm/tests/test_tester_memory_admission.py \
  tools/strategy_farm/tests/test_tester_memory_ledger.py \
  tools/strategy_farm/tests/test_terminal_worker_ram_compile_bypass.py \
  tools/strategy_farm/tests/test_terminal_worker_census_first_ram_priority.py \
  tools/strategy_farm/tests/test_terminal_worker_sqlite_busy_defer.py \
  tools/strategy_farm/tests/test_longrun_scheduling_policy.py -q
```

New tests:

- `test_terminal_worker_ram_emergency_reaper.py` (13): path anchor accept/reject
  incl. T_Live; newest-victim selection + re-runnable requeue + append-only
  marker + synthesized ledger row; COMPILE_EA never reaped; live-path refused
  even if mislabelled; under-threshold skip; no-work-item skip; wall-clock
  cool-down blocks a second reap; cross-worker lock serializes; consecutive-
  sample gate; RAM-recovery resets the counter; kill switch; idle-MemoryError
  logger throttle; **`run_loop` survives an injected idle MemoryError** (returns
  cleanly, does not propagate).
- `test_tester_memory_per_ea_expectations.py` (9): namespaced key; per-EA key
  only when identity present; aggregation emits both families; v1 back-compat;
  precedence (per-EA wins when it exceeds the class, ignored otherwise, used
  when the class is absent, disabled by env); end-to-end 27 GB reservation via
  the resolver.

Full targeted suite (`-k "terminal_worker or tester_memory or
longrun_scheduling"`): **325 passed, 4 subtests passed** (280 pre-existing + 22
new reaper/per-EA + longrun), 0 failures.

---

## 6. Risks / rollback

- Kill switch `QM_DISABLE_RAM_EMERGENCY_REAP=1` disables the reaper entirely (the
  counter resets and the loop behaves exactly as before). The per-EA override
  rides the existing `QM_TESTER_MEMORY_ADMISSION=0` rollback. Removing the loop
  wrapper restores the prior MemoryError-propagates behaviour.
- The reaper acts only after two consecutive <2.0 GB free-RAM samples — far
  below the 14/20 GB claim latch — so it fires only in the genuine
  OS-would-kill-workers regime, never during normal operation.
- Fail-open throughout: enumeration, ledger write, cool-down/lock, and DB read
  all swallow errors and decline to act rather than risk a wrong kill.
- The victim path is asserted against the factory anchor twice and the `T_LIVE`
  marker explicitly before any kill; `C:/QM/mt5/T_Live` is never a candidate.

Recommended next step: after merge, one live idle pass will rebuild the v2
expectations file from the existing ledger; the first genuine balloon that is
reaped will seed the per-EA key and the reservation self-corrects on the next
admission of that EA.
