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

---

## 7. Follow-up 2026-09-05: runner-tree kill

Outcome: `IMPLEMENTED; TESTS GREEN; APPEND-ONLY`. Same scope discipline as
sections 1-6 -- worker code + tests only, no gate threshold, verdict, T_Live or
containment change.

### 7.1 The recurrence, and what it proved

The reaper shipped in `11683160a7` (committed **2026-09-04T23:49:52Z**) between
the two manual reaps described below, and has **never fired in production**:
`D:/QM/strategy_farm/state/ram_emergency_reap_state.json` does not exist as of
this write, so no automated reap has been recorded. Everything below is the
CEO's manual reap of the same balloon class, which is exactly what the automated
reaper would have done -- and it is the manual run that exposed the scope defect.

All lines below are read-only from `D:/QM/strategy_farm/logs/` and from a
read-only (`mode=ro`) query of `farm_state.sqlite`; line numbers are as read on
2026-09-05 (the journals are append-only).

| Time (UTC) | Observation | Evidence |
| --- | --- | --- |
| 23:33:36Z | T2 claims `a0b332eb-c646-4911-88e1-53a9a9cc3246` = **Q05 QM5_11165_weiss-rsi-ma / EURJPY.DWX**, reservation 8.0 GB `ordinary` | `terminal_worker_T2.log:3746-3747` |
| 23:34:07Z | Phase runner spawned, **pid 21564**: `C:\Python311\python.exe C:\QM\repo\framework\scripts\q05_stress_medium.py --ea QM5_11165_weiss-rsi-ma --report-root D:\QM\reports\work_items\a0b332eb-... --symbol EURJPY.DWX --terminal T2 --timeout-sec 6900` | `work_item_a0b332eb-...log:2`; `terminal_worker_T2.log:3748` (`next_child_process_created`, `pid: 21564` = the payload `$.pid`) |
| ~23:45Z | The T2 `metatester64` grows to **20.8 GB** in ~2.5 min against the 8 GB reservation; the `terminal64` processes themselves hold ~0.2 GB each -- the consumer is always the metatester agent | `docs/ops/OPEN_ITEMS_STATUS.md` addendum 23:51Z (`000dc5ddca`) |
| 23:46:33Z-23:48:2xZ | Fleet near-OOM trough: free RAM **1.0 GB** (T1), **0.9 GB** (T4), **0.9 GB** (T8) | `terminal_worker_T1.log:7016-7019` (bracketed by `23:46:33Z` and `23:48:15Z`), `T4.log:5414-5415` (-> `23:48:20Z`), `T8.log:6336-6337` (-> `23:48:14Z`) |
| **23:48:39Z** | **Manual reap #1** -- `_stop_pid_tree` on the **terminal64** pid: victim `T2 terminal64 pid 10776 + metatester64 pid 2268`, `working_set_gb 20.8`, host free **2.3 -> 18.2 GB**; row requeued without verdict | payload `$.ram_emergency_reap_manual` on `a0b332eb` (read-only DB query) |
| 23:48:39Z-~23:52Z | **The runner survived.** pid 21564 was never in the kill scope, so it re-spawned the tester in place inside four minutes; the balloon re-inflated to ~11 GB and the host fell back to ~1.6 GB free | CEO observation; corroborated by the runner lifetime below |
| ~23:52Z | **Manual reap #2** -- terminal64 subtree again, same scope, same outcome | CEO observation |
| **23:54:11Z** | The runner finally dies. T2 logs `current_child_exit` with **`tester_runtime_seconds: 1204.0`** -- 23:34:07Z + 1204 s = 23:54:11Z, i.e. the tracked child lived across **both** terminal-only kills -- then `run_result action=runner_death_requeued reason=runner_process_died_without_summary status=pending verdict=null` | `terminal_worker_T2.log:3749-3750` |
| 23:54:11Z+ | Host recovers only now: T2 `ram_low_pause free_ram_gb 7.6`; the last sub-2 GB samples (T9 **1.3 GB**, T10 **1.9 GB**) immediately precede events at `23:54:43Z` / `23:54:33Z` | `terminal_worker_T2.log:3751`, `T9.log:5449-5450`, `T10.log:5684` |
| 23:54:2xZ / 23:57:27Z | T2 `worker_start pid 21308` (chunk-40 reload), next cell claimed `32213e79` -- throughput resumes | `terminal_worker_T2.log:3752, 3767-3769` |

Row state after the incident (read-only): `status=pending, verdict=NULL,
claimed_by=NULL, updated_at=2026-09-04T23:54:11+00:00`,
`prior_failure=runner_process_died_without_summary`, with the manual marker
`ram_emergency_reap_manual` intact. Re-runnable, no verdict written.

**The load-bearing fact is `tester_runtime_seconds: 1204.0`.** The prestage
controller tracks the child it spawned -- the phase runner, `spawn["pid"]`, the
same value written to the payload as `$.pid`. Its measured lifetime spans
23:34:07Z to 23:54:11Z and therefore brackets both manual terminal64 kills. Had
either kill ended the run, `current_child_exit` would have fired at 23:48:39Z.

### 7.2 Why the terminal-only scope was wrong

The balloon is not one process, it is a chain, and the reaper was cutting it in
the middle:

```
terminal_worker.py  (worker; never a kill target)
  └─ python q05_stress_medium.py …            <- payload $.pid  (RESTARTS the tester)
       └─ pwsh run_smoke.ps1
            └─ terminal64.exe                 <- old kill root (~0.2 GB)
                 └─ metatester64.exe          <- the actual RAM consumer (20.8 GB)
```

Killing the `terminal64` subtree frees the memory for as long as it takes the
runner to launch the next tester -- measured here at under four minutes -- and
then the host is back in the same fail-state, now with the cool-down spent. A
second, quieter consequence: the row is requeued `pending` while its runner is
still alive and spawning testers, so any terminal that claims it in that window
runs it concurrently with the orphan.

### 7.3 Design

`_run_ram_emergency_reap` now resolves a **kill root** after the victim is chosen
and the T_Live assertion has passed, and kills that tree instead of the
terminal64 pid. Widening from `terminal_tree` to `runner_tree` requires positive
proof; every failed check keeps the previous, narrower behaviour.

New in `tools/strategy_farm/terminal_worker.py`:

- **`_pid_is_descendant(process_snapshot, ancestor_pid, pid)`** -- walks the
  children-by-parent-pid map already produced by `_process_private_snapshot`
  (no new probe, no subprocess). Bounded at 4096 visited nodes so a cyclic or
  rebased ppid map cannot loop. Fail-closed on an unusable snapshot, a
  non-integer pid, or `ancestor == pid`.
- **`_terminal_worker_pids(root, active)`** -- the refusal set of pids known to
  be `terminal_worker.py` processes, from three subprocess-free sources:
  `os.getpid()`, the `claimed_by_worker_pid` each live claim records in its
  payload, and `<root>/state/worker_pids.json` (the map
  `start_terminal_workers.py` maintains). This guard is load-bearing rather than
  cosmetic: the terminal64 is a descendant of **its own worker** too, so a stale
  or wrong `$.pid` would otherwise satisfy the ancestry proof and take a worker
  down.
- **`_resolve_ram_reap_kill_root(victim, worker_pids, process_snapshot=None)`**
  -- the decision. Widen only when *all* hold:
  1. `$.pid` present, `> 0`, and not the terminal64 pid itself;
  2. not this reaper process, and not in the `terminal_worker.py` refusal set;
  3. the runner pid is alive in the live process snapshot;
  4. the terminal64 pid is a **descendant** of the runner pid -- the one check
     that *proves* ownership instead of trusting a payload field;
  5. the runner image path resolves (`_query_full_process_image_path`) and does
     **not** contain the `T_LIVE` marker. An unresolvable image is refused, not
     assumed benign.

  `farmctl._stop_pid_tree` snapshots the tree and stops it leaves-first, so
  rooting at the runner takes pwsh + terminal64 + metatester64 with it in the
  right order; no separate terminal sweep is needed.

Recorded in `facts` (and therefore in the structured `ram_emergency_reap` event
and in the requeued row's payload): `kill_root_pid`, `kill_scope`
(`"runner_tree"` | `"terminal_tree"`), `runner_pid`, `runner_is_ancestor`,
plus `runner_image_path` and `runner_scope_refused_reason` for diagnosis
(`runner_pid_missing`, `runner_pid_is_victim_terminal`, `runner_pid_is_reaper`,
`runner_pid_is_terminal_worker`, `runner_not_alive`,
`runner_not_ancestor_of_victim`, `runner_image_unresolvable`,
`runner_image_live_terminal`). `killed` keeps its meaning: the result of the one
`_stop_pid_tree` call, now on the kill root.

**Requeue audit (deliverable 2).** `_defer_ram_emergency_reap` was checked and
needs **no change**: its `SELECT`/`UPDATE` are anchored on
`(id, status='active', claimed_by=<victim terminal>)` and never on
`json_extract(payload_json,'$.pid')`, so widening the kill root does not touch
the match. It still writes `status='pending', verdict=NULL, claimed_by=NULL`,
appends `prior_failure`/`ram_emergency_reap`/`ram_emergency_reap_count`, and
clears the stale runtime payload (`_STALE_RUNTIME_PAYLOAD_KEYS` includes `pid`,
so the dead runner pid does not survive into the re-run). Only the docstring was
extended to record that the clause is claim-anchored, not pid-anchored. Every
new test asserts the requeue explicitly (deliverable 3d).

### 7.4 Tests

```
python -X utf8 -m pytest \
  tools/strategy_farm/tests/test_terminal_worker_ram_emergency_reaper.py \
  tools/strategy_farm/tests/test_tester_memory_per_ea_expectations.py \
  tools/strategy_farm/tests/test_terminal_worker_adoption.py \
  tools/strategy_farm/tests/test_terminal_worker_drain_window.py \
  -q -p no:cacheprovider
```

**109 passed** (98 pre-existing + 11 new), 0 failures.
`test_terminal_worker_ram_emergency_reaper.py` alone: **24 passed** (13 + 11).

The new cases reconstruct the chain
`worker 7000 -> runner 21564 -> pwsh 4100 -> terminal64 900 -> metatester 950`
with `_process_private_snapshot` and `_query_full_process_image_path` stubbed:

- `test_pid_is_descendant_walks_the_runner_chain` -- multi-hop true, upward
  false, self false, unrelated false, cyclic map terminates, fail-closed inputs.
- (a) `test_kills_runner_tree_when_runner_owns_the_victim` -- `kill_scope
  runner_tree`, `kill_root_pid` = runner, `runner_is_ancestor True`, exactly one
  `_stop_pid_tree` call rooted at the runner; scope also persisted into the
  requeued payload.
- (b) `test_falls_back_to_terminal_tree_when_runner_is_not_an_ancestor` (stale
  `$.pid` on another branch), `test_falls_back_when_runner_pid_is_dead`,
  `test_falls_back_when_payload_pid_is_missing` -- all keep `terminal_tree` and
  kill the terminal64 pid, with the refusal reason recorded.
- (c) `test_refuses_runner_scope_when_payload_pid_is_the_claiming_worker`,
  `..._for_a_worker_in_the_worker_pid_map`,
  `..._when_payload_pid_is_the_reaper_itself`,
  `..._when_runner_image_is_the_live_terminal` (ancestry holds, T_Live image
  refuses the scope anyway), `..._when_runner_image_is_unresolvable`.
- (d) every one of the above asserts the row came back
  `pending / verdict NULL / claimed_by NULL` with `prior_failure` and
  `ram_emergency_reap_count == 1`.
- `test_terminal_worker_pids_union_of_self_claims_and_pid_map` -- the refusal
  set unions all three sources and is fail-open per source.

### 7.5 Risks / rollback

- **Blast radius is strictly larger by one process type** (the phase runner), and
  only on positive proof. Every refusal path reproduces the exact 11683160a7
  behaviour, so the worst case of the new code is the old code.
- The `T_LIVE` marker is now checked in **two** places: on the victim
  terminal64 (unchanged) and on the runner image before widening. A T_Live path
  can be neither victim nor kill root.
- A worker can never be the kill root: `os.getpid()`, the claim's
  `claimed_by_worker_pid`, and `worker_pids.json` are all refusals, checked
  *before* the ancestry proof runs.
- Rollback is the same kill switch as section 6, `QM_DISABLE_RAM_EMERGENCY_REAP=1`,
  which disables the reaper entirely. A narrower rollback (scope only) is a
  one-line change: pass `victim["pid"]` to `_stop_pid_tree` instead of
  `kill_plan["kill_root_pid"]`.
- Unchanged limits carried over from section 6: the reaper still runs only in the
  **idle** guard loop, so with all ten terminals computing, nobody reaps. A
  monitor-side backstop remains the follow-up idea.

### 7.6 Open questions

1. The manual requeue at 23:48:39Z released the row while its runner was still
   alive; the worker nonetheless reported `claim_released: true` at 23:54:11Z.
   Whether the row was re-claimed in between or the second release was a no-op is
   not decidable from the journals. The runner-tree scope removes the window
   either way, but the double-execution hazard of "requeue while the runner
   lives" deserves its own check on the manual path.
2. `runner_image_unresolvable` is deliberately fail-closed. If
   `QueryFullProcessImageNameW` ever fails for a peer worker's runner in
   production, the reaper silently degrades to the old scope; the refusal reason
   is in the event, so this is observable -- but it has not yet been exercised
   live (no automated reap has occurred at all).

---

## 8. Phase RAM floor (2026-09-05)

Outcome: `IMPLEMENTED; TESTS GREEN; APPEND-ONLY`. Admission-side reservation
only. No gate threshold, contract criterion, verdict, trade stream, candidate
pool, containment scope, or T_Live surface is touched; backtests are not
throttled. Sections 1-7 above stay valid -- the reaper is unchanged and is
deliberately excluded from the floor (8.5).

### 8.1 Why the measured path could not cover this

Section 3 gives Q05/Q06/Q07 rows a measured reservation once the ledger has one:
the asset-class key needs `n >= TESTER_MEMORY_MIN_SAMPLES` (3) and the per-EA key
needs at least one COMPLETED run. Both conditions fail exactly where the host is
at risk:

- a run that balloons and is killed never writes a ledger row (the reaper now
  synthesizes one, but as of this patch it has never fired -- 7.6);
- the workload-scaled gates have single-digit sample counts per
  `symbol_class|timeframe|run_kind` key, so the class key rarely reaches n=3.

Three Q05 JPY-cross runs therefore reserved the flat 8 GB `ordinary` commit class
and then took 20-27 GB of the 63 GB host shared with T_Live:

| when (UTC) | EA | symbol | phase | peak | reserved | free RAM |
|---|---|---|---|---|---|---|
| 2026-09-04 08:09Z | QM5_10395 | EURJPY.DWX | Q05 | 27.0 GB | 8 GB | < 4 GB (min 0.4 GB, S1) |
| 2026-09-04 23:45Z | QM5_11165 | EURJPY.DWX | Q05 | 20.8 GB | 8 GB | < 4 GB (1.6 GB, S7.1) |
| 2026-09-05 01:32Z | QM5_10691 | GBPJPY.DWX | Q05 | 23.0 GB | 8 GB | < 4 GB |

None of the three is in the ledger. They are cited from the incident record, not
from `tester_memory_ledger.jsonl`.

### 8.2 Ledger derivation (read-only)

Source: `D:/QM/reports/state/tester_memory_ledger.jsonl`
(schema `qm.tester_memory_ledger/v1`, 2265 rows, read 2026-09-05).

Rule, per `(phase, symbol_class)`:
`floor = max( PHASE_RAM_FLOOR_MIN_GB , roundup2( max( p95(peak_subtree_working_set_gb) , ceil(largest COMPLETED run) ) ) )`
where `roundup2` rounds up to the next 2 GB and `PHASE_RAM_FLOOR_MIN_GB = 12.0`.

| phase | class | n | max GB | p95 GB | max completed GB | ceil | max(p95, ceil) | -> next 2 GB | **floor** |
|---|---|---|---|---|---|---|---|---|---|
| Q05 | energy | 1 | 4.48 | 4.48 | 4.48 | 5 | 5.00 | 6 | **12** (min) |
| Q05 | fx_cross | 1 | 18.48 | 18.48 | 18.48 | 19 | 19.00 | 20 | **24** (incidents) |
| Q05 | fx_major | 6 | 15.52 | 15.51 | 15.52 | 16 | 16.00 | 16 | **16** |
| Q05 | metal | 5 | 12.01 | 11.99 | 12.01 | 13 | 13.00 | 14 | **14** |
| Q06 | energy | 1 | 4.47 | 4.47 | 4.47 | 5 | 5.00 | 6 | **12** (min) |
| Q06 | fx_major | 4 | 15.51 | 15.50 | 15.51 | 16 | 16.00 | 16 | **16** |
| Q06 | metal | 4 | 12.00 | 11.99 | 12.00 | 12 | 12.00 | 12 | **12** |
| Q07 | fx_major | 15 | 15.54 | 15.40 | 15.54 | 16 | 16.00 | 16 | **16** |
| Q07 | metal | 12 | 12.02 | 11.97 | 11.92 | 12 | 12.00 | 12 | **12** |

Two entries are not a straight read of that table and are called out as such:

- **(Q05, fx_cross) = 24 GB.** The ledger's single completed Q05 fx_cross run
  (QM5_10295 / CHFJPY.DWX D1, 2026-09-04 21:39Z) peaked at 18.48 GB, which would
  derive 20 GB. The three balloons in 8.1 peaked at 20.8 / 23.0 / 27.0 GB and are
  absent from the ledger. 24 GB clears the middle two; the 27 GB outlier is
  covered by its per-EA measured expectation once a row for it exists (8.4).
- **(Q06, fx_cross) and (Q07, fx_cross) = 20 GB.** No rows exist at all. The
  value is carried from the completed Q05 fx_cross run, justified by the ledger's
  own Q05/Q06 pairs for the same EA differing by <= 0.1 GB
  (QM5_11179 15.52/15.51, QM5_10978 15.35/15.35, QM5_10928 11.94/11.93), i.e. the
  same full-history workload is re-run at each workload-scaled gate.

Classes with no rows in a phase (`fx_exotic` everywhere, `energy` in Q07,
`other` everywhere) take the 12 GB minimum. `other` is included because it is the
fallback bucket a not-yet-classified symbol lands in, and a floor can only ever
raise a reservation.

### 8.3 The table as shipped

`tools/strategy_farm/terminal_worker.py`, `PHASE_RAM_FLOOR_GB`:

| symbol_class | Q05 | Q06 | Q07 |
|---|---|---|---|
| fx_cross | 24 | 20 | 20 |
| fx_major | 16 | 16 | 16 |
| metal | 14 | 12 | 12 |
| energy | 12 | 12 | 12 |
| fx_exotic | 12 | 12 | 12 |
| other | 12 | 12 | 12 |

Deliberately absent, so the flat class is kept unchanged: `index` (already the
44 GB `single_index_tick` class -- a floor could only lower it, which `max()`
forbids), `basket2` / `basket3_9` / `basket10+` (their own multisymbol commit
classes), every phase other than Q05-Q07 (`OPT_CENSUS` cells measure 1-4 GB and
keep the dedicated 4 GB class; `COMPILE_EA`; Q02-Q04, whose measured peaks are
0.9-8.1 GB).

Properties pinned by test: every value is an even GB multiple, `>= 12` and
`<= 44`; `fx_cross >= fx_major >= metal` within each phase; and per class the
sequence Q05 >= Q06 >= Q07 is monotone non-increasing.

### 8.4 Where it is applied

`_ram_reservation_detail_for_candidate` (the new full resolver;
`_ram_reservation_for_candidate` is now a thin wrapper over it, keeping the
`(ram_class, gb)` return shape and the single seam every existing call site and
test fake uses) resolves

```
reservation = max( flat commit class , measured expectation (unchanged rule) , phase floor )
```

via the pure `_resolve_ram_reservation(...) -> (gb, source)`. `max()` throughout,
so no rule can ever lower a reservation. The measured rule is untouched: it still
only applies to single-symbol rows whose measured peak exceeds
`TESTER_MEMORY_HEAVY_GB`. A measured expectation ABOVE the floor wins (the 27 GB
QM5_10395 per-EA key beats the 24 GB floor); the floor is the reservation only
while nothing has been measured yet.

`source` is a facts-only label (`flat` / `measured` / `phase_floor`) recorded
beside `reservation_gb` in the skip, drain and reaper facts
(`skipped_ram_class`, `skipped_census_lane_protection`,
`_drain_candidate_from_row`, the reaper candidate). It is never read by a
decision. On an exact tie between a measured expectation and the floor the label
says `phase_floor`, because the floor alone would have produced that number.

### 8.5 Admission consequence -- which existing checks now see the larger number

Confirmed by reading every call site of `_ram_reservation_for_candidate`:

1. **Post-reservation RAM floor** (claim loop, `post_reservation_free_gb <
   _ram_floor_for_class(ram_class)`, `RAM_MIN_FREE_GB = 14`). A Q05 fx_cross row
   now needs `24 + 14 = 38 GB` free instead of `8 + 14 = 22 GB`; Q0x fx_major
   `16 + 14 = 30 GB`; a 12 GB floor `26 GB`. The 14/20 GB latch itself is a
   global hysteresis and is unchanged.
2. **CENSUS-FIRST heavy deferral** (`ram_reservation_gb >= HEAVY_RUN_RAM_GB`,
   10 GB). Every floored row is now heavy where an unmeasured Q05/Q06/Q07 row was
   not. While census cells are claimable, such a row is deferred unless free RAM
   minus its reservation clears `_census_first_protected_band_gb()` = 16 GB, i.e.
   a 24 GB Q05 fx_cross needs **40 GB free**. This is the strictest new
   constraint and the intended serialization.
3. **Long-run RAM ceiling** (`_drain_active_ram_facts` -> `long_run_ram_gb`,
   `lr_floor = max(reservation, DRAIN_LONG_RUN_FLOOR_GB=8)`). An unmeasured
   active Q07 row now counts 12-20 GB instead of 8 GB. This feeds two consumers:
   `_drain_candidate_is_winnable`'s `long_run_ceiling` refusal, and
   `longrun_scheduling_policy.LONG_RUN_RAM_CAP_GB = 26.0` -- **two** active Q07
   fx_major long runs (2 x 16 = 32) now reach the cap and refuse a third long run
   of any class, where three unmeasured rows previously summed to 24 < 26.
4. **Releasable short RAM** (`_drain_active_ram_facts`,
   `min(reservation, measured)`). Active Q05/Q06 rows now contribute up to their
   true measured working set rather than being capped at 8 GB, so a drain is more
   often judged winnable -- correct, that RAM really is released.
5. **Drain arming** (`_drain_row_is_qualifying`,
   `DRAIN_WINDOW_MIN_RESERVATION_GB = 24`). A 24 GB Q05 fx_cross row now exactly
   meets the arming minimum, so a **priority-tracked** Q05 fx_cross row can open
   a drain window for the first time (`24 + 4 = 28 <= 63.1 - 10`). Bounded by the
   existing `payload.priority_track is True` precondition; ordinary rows cannot
   arm.
6. **Drained-fleet armed-row floor** (`DRAIN_ARMED_ROW_FLOOR_GB = 4`): the armed
   Q05 fx_cross row clears at `24 + 4 = 28 GB` free.

Explicitly **not** changed:

- **The RAM emergency reaper (sections 1-7).** Its threshold is
  `reservation * RAM_EMERGENCY_WS_RESERVATION_MULTIPLE (2.0)`. Feeding it the
  floor would raise the Q05 fx_cross kill threshold from 16 GB to **48 GB** on a
  63 GB host -- disarming the reaper on precisely the incident class that
  motivated it (the three balloons peaked at 20.8-27.0 GB and would all have
  survived). The reaper therefore reads the new floor-free
  `_ram_reap_reference_reservation_gb` = `max(flat, measured)`, i.e. its
  behaviour is byte-for-byte the pre-patch behaviour. The floor is an admission
  safety margin; the reaper judges the overrun. The candidate facts record both
  numbers (`reservation_gb` = reap reference, `admission_reservation_gb`).
- **The tester-memory ledger.** `_record_tester_memory` still writes the FLAT
  class `reservation_gb`, so the schema and the aggregation that feeds section 3
  are untouched.
- **`_ram_latch_opt_census_bypass_available`**, which only enumerates pending
  OPT_CENSUS rows -- excluded from the floor, so unchanged.
- Q02-Q04, COMPILE_EA, multisymbol/basket and index rows, per 8.3.

### 8.6 Tests

New: `tools/strategy_farm/tests/test_terminal_worker_phase_ram_floor.py`
(32 tests) -- table shape (bounded, even multiples, monotone across phases,
`fx_cross >= fx_major >= metal`, index/baskets absent, Q02-Q04/OPT_CENSUS/
COMPILE_EA absent), lookup (normalization, unknown keys, both rollbacks), the
pure resolver (floor raises flat; measured above floor wins; floor never lowers a
heavier class; multisymbol/census ignore it; the 3-positional pre-patch call
still resolves unchanged), candidate end-to-end for every floored and excluded
class, and the source label including its fail-open.

Updated fixtures (behaviour change, not a repair):
`test_terminal_worker_drain_window.py` -- four cases encoded the pre-patch 8 GB
estimate for an unmeasured Q07 long run. `long_run_ram_gb` for Q07/EURUSD is now
16 GB and for Q07/XAUUSD 12 GB; the two `_drain_run_postprocess` arithmetic cases
move `host_total_gb` 84 -> 100 so the long-run ceiling is not the binding
constraint and each test still exercises the branch it was written for. One
assertion that a measured 11.5 GB beats the floor now uses 14.0 GB (11.5 sits
under the new 12 GB floor), with the sub-floor case kept as an added assertion.

```
python -X utf8 -m pytest   tools/strategy_farm/tests/test_terminal_worker_phase_ram_floor.py   tools/strategy_farm/tests/test_tester_memory_admission.py   tools/strategy_farm/tests/test_tester_memory_per_ea_expectations.py   tools/strategy_farm/tests/test_terminal_worker_ram_emergency_reaper.py   tools/strategy_farm/tests/test_terminal_worker_drain_window.py   tools/strategy_farm/tests/test_terminal_worker_census_first_ram_priority.py   tools/strategy_farm/tests/test_longrun_scheduling_policy.py   -q -p no:cacheprovider
=> 196 passed
```

Adjacent suites that assert directly on reservations, run as a regression check:
`test_terminal_worker_atomic_claim.py`, `test_tester_memory_ledger.py`,
`test_terminal_worker_ram_compile_bypass.py` => 102 passed, unchanged.

### 8.7 Live resolution check (read-only)

Unit tests use synthetic rows.  To confirm the classification and the exclusions
against REAL payload shapes, every distinct `(phase, symbol_class, multisymbol)`
combination present in `D:/QM/strategy_farm/state/farm_state.sqlite`
(`work_items`, read-only `mode=ro`, all statuses) was resolved through the
patched `_ram_reservation_detail_for_candidate` and through the reaper's
floor-free `_ram_reap_reference_reservation_gb`.  47 combinations resolved;
abridged:

| phase | class | multi | example row | ram_class | GB | source | reap ref |
|---|---|---|---|---|---|---|---|
| Q02 | fx_cross | no | QM5_1099 / AUDCAD.DWX | ordinary | 8.0 | flat | 8.0 |
| Q02 | index | no | QM5_10020 / NDX.DWX | single_index_tick | 44.0 | flat | 44.0 |
| Q03 | fx_cross | no | QM5_10048 / GBPJPY.DWX | ordinary | 8.0 | flat | 8.0 |
| Q04 | fx_cross | no | QM5_10048 / GBPJPY.DWX | ordinary | 18.5 | measured | 18.5 |
| Q04 | metal | no | QM5_10038 / XAUUSD.DWX | ordinary | 11.9 | measured | 11.9 |
| **Q05** | **fx_cross** | no | QM5_10569 / EURJPY.DWX | ordinary | **24.0** | **phase_floor** | 8.0 |
| Q05 | fx_major | no | QM5_10558 / EURUSD.DWX | ordinary | 16.0 | phase_floor | 8.0 |
| Q05 | energy | no | QM5_10300 / XTIUSD.DWX | ordinary | 12.0 | phase_floor | 8.0 |
| Q05 | metal | no | QM5_10069 / XAUUSD.DWX | ordinary | 15.5 | measured | 15.5 |
| Q05 | index | no | QM5_10115 / GDAXI.DWX | single_index_tick | 44.0 | flat | 44.0 |
| Q05 | basket3_9 | yes | QM5_12712 cointegration | multi_leg_fx_basket | 32.0 | flat | 32.0 |
| Q06 | fx_cross | no | QM5_10569 / EURJPY.DWX | ordinary | 20.0 | phase_floor | 8.0 |
| Q07 | fx_cross | no | QM5_10569 / EURJPY.DWX | ordinary | 20.0 | phase_floor | 8.0 |
| Q07 | fx_major | no | QM5_11421 / EURUSD.DWX | ordinary | 16.0 | phase_floor | 14.3 |
| Q07 | metal | no | QM5_10069 / XAUUSD.DWX | ordinary | 15.5 | measured | 15.5 |
| OPT_CENSUS | fx_major | no | QM5_41097 / USDJPY.DWX | opt_census_cell | 4.0 | flat | 4.0 |
| COMPILE_EA | other | no | QM5_1009 | ordinary | 8.0 | flat | 8.0 |

What this confirms beyond the unit tests:

- Q02/Q03, OPT_CENSUS, COMPILE_EA, index and every basket class resolve to their
  pre-patch numbers with `source=flat`, on real payloads.
- **Q04 is not floored but the measured rule still fires there** (QM5_10048
  GBPJPY at 18.5 GB, QM5_10038 XAUUSD at 11.9 GB) -- the exclusion removes the
  a-priori floor from Q02-Q04, it does not disable the measured path.
- **A measured expectation above the floor wins on live rows**: Q05/Q06/Q07
  XAUUSD (QM5_10069) resolves to the measured 15.5 GB, above the 12-14 GB metal
  floor, and Q07 QM5_11421 keeps a 14.3 GB reap reference under a 16 GB
  admission reservation.
- The reap reference column stays at the pre-patch value for every floored row,
  which is the property 8.5 depends on.

Incidental, pre-existing and untouched: the same basket EA can carry a different
multisymbol commit class in different phases (QM5_12781 resolves
`heavy_or_unknown_multisymbol` 44 GB at Q06 but `two_leg_fx_pair` 8 GB at Q07),
because `_multisymbol_commit_class` reads the row's payload.  Not caused by this
patch and not addressed here; noted for a later look.

### 8.8 Risks / rollback

**Rollback: empty the table** -- `PHASE_RAM_FLOOR_GB = {}` -- or set
`QM_PHASE_RAM_FLOOR=0`, then idle-reload the workers. Either restores the exact
pre-patch reservations; both are covered by a test. Nothing else has to be
reverted, because the floor is a `max()` term and nothing reads it.

Risk: **throughput cost on the floored classes.** A 24 GB Q05 fx_cross needs
40 GB free while census cells are claimable (8.5 item 2), which on a 63 GB host
shared with T_Live effectively serializes those rows against the census. That is
the intended trade against three host-endangering incidents in 18 hours, but if
Q05 fx_cross throughput collapses the graduated lever is to lower
`PHASE_RAM_FLOOR_GB["Q05"]["fx_cross"]` to the ledger-derived 20 GB before
reaching for the kill switch.

### 8.9 Open questions

1. `(Q06, fx_cross)` and `(Q07, fx_cross)` = 20 GB are carried from a single
   completed Q05 run, not measured in those phases. The first completed Q06/Q07
   fx_cross rows should be checked against 20 GB and the table re-derived.
2. The three balloons are cited from the incident record, not from the ledger.
   Once the reaper fires and synthesizes a row (7.6: it never has), the per-EA
   expectation should overtake the floor for QM5_10395 at 27 GB, and the derived
   `(Q05, fx_cross)` value should be re-checked against real data.
3. A priority-tracked Q05 fx_cross row can now arm a drain window (8.5 item 5).
   That is arithmetically sound but has never been exercised; the first such
   arming should be watched.
4. `PHASE_RAM_FLOOR_MIN_GB = 12` is applied to classes with no rows at all
   (`fx_exotic`, `other`). It can only raise a reservation, but it is an
   assumption, not a measurement.
