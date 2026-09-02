# Claude Orchestration Cycle — 2026-09-02 ~10:25Z

Single-pass orchestration cycle (scheduled task, worktree `agents/claude-orchestration-3`).
All control-plane commands executed against the canonical checkout `C:/QM/repo`.

## 1. Router state

- `agent_router.py status`: claude enabled, `max_parallel=3`, **running 0**.
  codex running 2/5, gemini running 1/2, owner lane disabled (0).
- `agent_router.py list-tasks --agent claude --state IN_PROGRESS` → `[]`.

**No claude work was assigned at the start of this cycle.** *(Superseded later in
the same cycle — see §6.)* No routing commands (`run` / `route-many` /
`route-once` / `replenish`) were issued at any point.

## 2. QM5_10260 queue state (cieslak-fomc-cycle-idx)

Queried `D:/QM/strategy_farm/state/farm_state.sqlite` read-only
(`work_items where ea_id='QM5_10260'`).

| status  | count | last updated_at |
|---------|-------|-----------------|
| done    | 286   | 2026-07-25T23:53:34Z |
| failed  | 1     | 2026-06-30T18:43:03Z |
| pending | 1     | 2026-09-02T10:12:57Z |

Open item:

- `a0a0128f-a245-4fab-959f-c4941585dd62` — kind `backtest`, phase **Q04**,
  symbol `NDX.DWX`, status `pending`, `attempt_count=0`, `claimed_by=NULL`,
  created/updated `2026-09-02T10:12:57Z`.
- Setfile: `C:\QM\repo\framework\EAs\QM5_10260_cieslak-fomc-cycle-idx\sets\QM5_10260_cieslak-fomc-cycle-idx_NDX.DWX_M30_backtest_ablation_00.set`
- Payload: `append_only_rerun=true`, `append_only_rerun_of_work_item=0c706d18-2a56-4b01-abd3-5770740db00f`
  (the 2026-07-25 Q04 `INFRA_FAIL`), `promoted_from_phase=Q03`,
  `promotion_source=farmctl_enqueue_backtest_ea`.
- `custom_history_archive_admission`: status `ACTIVE`, 98 selected archive rows,
  `activation_sha256=61c8c72c…`, `manifest_sha256=fe0dd0fd…`.
- `work_item_holds` for this item: **none**.

Assessment: correctly enqueued append-only Q04 rerun, no hold, waiting on a
terminal claim. Nothing to fix on the item itself.

## 3. Finding — `farmctl.py health` invocations wedge and stack

`farmctl.py health` was launched at the start of this cycle and produced
**zero bytes of stdout in 10 minutes**; it was terminated as cycle cleanup.
Process inspection showed it was not alone:

| PID   | started (local, UTC+2) | age at scan | user CPU | child procs |
|-------|------------------------|-------------|----------|-------------|
| 4808  | 12:00:06 | 25.2 min | 3.1 s | none |
| 5528  | 12:00:43 | 24.6 min | 2.8 s | none |
| 30744 | 12:15:16 | 10.0 min | 3.2 s | none |
| 32776 | 12:15:19 | 10.0 min | 2.8 s | none |
| 25096 | 12:15:18 | 10.0 min | 3.1 s | none — this cycle's, terminated |

Five concurrent `farmctl health` processes; ~3 CPU-seconds each over 10–25
minutes of wall clock, no child processes, no output. They are **blocked, not
computing**, and each scheduled trigger adds another.

Ruled out by code read: `health.py` does *not* acquire the global mutation lock
— `chk_factory_mutation_lock()` calls `inspect_factory_mutation_lock()`, which
is a read-only snapshot ("Alarm on a stale global mutation lock without mutating
farm state", `tools/strategy_farm/health.py:981`). The block is elsewhere
(SQLite reader waiting on a writer, or a filesystem scan) — **not diagnosed
further in this cycle**.

Correlated worker evidence (`D:/QM/strategy_farm/logs/terminal_worker_T*.log`):

```
{"at_utc":"2026-09-02T10:20:16.843+00:00","claimed":false,"reason":"sqlite_locked","terminal":"T1"}
{"event":"sqlite_locked","terminal":"T1","action":"claim_backoff"}
{"at_utc":"2026-09-02T10:20:39.821+00:00","claimed":false,"reason":"sqlite_locked","terminal":"T5"}
{"event":"sqlite_locked","terminal":"T5","action":"claim_backoff"}
```

This matches the known class in
`project_qm_thundering_herd_worker_restart_2026-08-29`: on a
`sqlite_busy`-style series, pause the **control plane** — never throttle
backtests. Four wedged health processes are exactly such control-plane load.

## 4. Not an incident — stale mutation lock is self-healing

`D:/QM/strategy_farm/state/FACTORY_MUTATION.lock` was present with a **dead**
owner PID:

```json
{"created_at":"2026-09-02T10:20:39.846255+00:00","nonce":"fd133c06942f4840a39c78c80c6e69b2",
 "owner":"terminal_worker.claim_atomic:T6","pid":32364}
```

`Get-Process -Id 32364` → not running. This is **not** a wedge:
`factory_mutation_lock.py` implements an identity-safe stale reaper with
`DEFAULT_STALE_REAP_SECONDS = 120.0`, and it has fired repeatedly today
(`D:/QM/reports/state/mutation_lock_reaps.jsonl`):

- 07:00:07Z — reaped `retry_qm5_41285_unbound_compile.apply` pid 14740, age 288 s, `owner_pid_dead`
- 09:36:25Z — reaped `release_work_item_hold:bfc98851…` pid 30784, age 463 s, `owner_pid_dead`
- 09:46:43Z — reaped `DL089_CLAIM_PRUNING…` pid 8540, age 1588 s, `owner_pid_dead`

The current lock will be reaped by the next mutation attempt. Worth noting only
as a **rate** observation: three dead-PID lock reaps in ~3 hours.

## 5. Throughput / saturation snapshot

- `FACTORY_OFF.flag`: absent → factory ON.
- Custom-history containment: **released** —
  `D:/QM/strategy_farm/state/custom_history_containment_mode.json` has
  `"enabled": false`, `reason "ceo_release_after_copy_on_claim_trip4_20260902"`,
  recorded `2026-09-02T07:44:34Z`.
- `farmctl mt5-slots` @ 10:21:17Z: `terminal64_running_count=3`, of which only
  **one** is a pipeline run — T4 on `5be9c29a…` (QM5_11125, Q09, WS30.DWX).
  The other two are `T_Live` and the FTMO terminal (neither is a backtest).
  Terminal workers registered: T1–T7.
- Terminal reservation: T4 held by `run_smoke:38516:…`,
  reason `run_smoke_custom_history_admission`, until `2026-09-02T12:49:27Z`.
- Work items: done 65,143 · failed 49,047 · **pending 8,006** · active 1.
- Pending by phase (top): OPT_CENSUS 5,356 · Q04 1,486 · Q02 754 · Q03 137 ·
  Q09_NEWS 55 · COMPILE_EA 44 · Q05 36 · Q07 31 · Q10_NEWS 29 · Q12 24 · Q09 23 · Q08 16.
- Completions (`done`+`failed`): **36 in the last 60 min**, 214 in the last 6 h.

**Saturation is the binding constraint: 1 of 7 workers busy against an 8,006-item
backlog.** The dominant claim refusal is not contention but the commit-headroom
governor. From `terminal_worker_T1.log` / `T5.log`:

```
{"event":"commit_headroom_low_pause","terminal":"T1","commit_headroom_gb":82.5,
 "commit_reserved_gb":84.6,"effective_commit_headroom_gb":-2.2,"threshold_gb":24.0,
 "commit_reservation_detail":[
   {"ea_id":"QM5_41196","reservation_gb":5.66,"expected_peak_gb":8.0,"measured_gb":2.34},
   {"ea_id":"QM5_10916","reservation_gb":34.99,"expected_peak_gb":44.0,"measured_gb":9.01,
    "reservation_class":"single_index_tick"},
   {"ea_id":"QM5_11125","reservation_gb":44.0,"expected_peak_gb":44.0,"measured_gb":null,
    "reservation_class":"single_index_tick"}]}
```

Two `single_index_tick` reservations at 44 GB `expected_peak_gb` consume the
whole commit budget and drive `effective_commit_headroom_gb` **negative**, while
their *measured* footprint is 0.12–9.15 GB — an over-reservation of roughly
5×–35× against measurement on these two items. Every other worker then refuses
to claim with `commit_headroom_low`.

This is an observation from two log windows on 2026-09-02, **not** a
characterisation of the `single_index_tick` class in general. Whether
`expected_peak_gb=44` is well calibrated needs a proper measured-vs-reserved
study across the class before anything is changed. Do not retune the governor
off this snapshot.

## Open items

1. **`farmctl health` wedge (P1).** Four processes still blocked at the time of
   writing (4808, 5528, 30744, 32776), the oldest 25 min. Each scheduled trigger
   adds one. Needs a diagnosis of where `health()` blocks and a hard timeout so a
   blocked run cannot accumulate. *This cycle produced no `health` output at all
   — the step-1 and step-4 health checks are unsatisfied.*
2. **Saturation 1/7 with 8,006 pending (P1).** Commit-headroom governor is the
   gate. Wants a measured-vs-reserved calibration study for
   `reservation_class=single_index_tick`, not an ad-hoc threshold change.
3. **Dead-PID mutation locks, 3 reaps in ~3 h (P3).** Self-healing via the 120 s
   identity-safe reaper; track the rate, no action.

## Evidence sources

- `D:/QM/strategy_farm/state/farm_state.sqlite` (read-only, `mode=ro`)
- `D:/QM/strategy_farm/logs/terminal_worker_T{1,5,7}.log`
- `D:/QM/strategy_farm/state/FACTORY_MUTATION.lock`
- `D:/QM/strategy_farm/state/custom_history_containment_mode.json`
- `D:/QM/reports/state/mutation_lock_reaps.jsonl`
- `C:/QM/repo/tools/strategy_farm/farmctl.py mt5-slots` @ 10:21:17Z
- `C:/QM/repo/tools/strategy_farm/agent_router.py status` @ ~10:21Z
- `C:/QM/repo/tools/strategy_farm/health.py:981-1000`,
  `C:/QM/repo/tools/strategy_farm/factory_mutation_lock.py:34,537-608`

## Actions taken

- Terminated **only** this cycle's own wedged `farmctl health` process (PID 25096).
  The four other blocked health processes were left running as evidence.
- No routing commands. No factory OFF/ON. No T_Live or AutoTrading action.
  No `terminal64.exe` started. No running backtest interrupted. No work item,
  hold, or lock mutated.

## 6. Correction — a task did arrive mid-cycle

§1 recorded an empty claude lane, which was true at ~10:21Z. The router then
routed `b335e499-86e9-5b7d-a309-8000ad07a282` (priority 85, `ops_issue`,
"Execute OWNER decision OWNER-DEC-LEGACY-COHORT-DISPO-20260830 = YES") at
`2026-09-02T10:21:56Z`, and the step-3 re-check picked it up. It was worked.

Outcome: Part B (6 append-only retires) was already complete via ticket
`7d561f89` and was independently re-verified; Part A (13 Q02-new-identity chains)
was held fail-closed because the REQUAL-8 wave is 7/8 with pair 8 pending and its
build reference `c2ef7f4a` is not locatable as a row id. No Codex ticket was
commissioned.

Full record: `docs/ops/evidence/2026-08-30_legacy-cohort-dispo-20260830_68a58c95_execution.md`
(commit `8bc92d4d22`). The task sits in `REVIEW` per
`INDEPENDENT_ORCHESTRATOR_CLOSEOUT`.

Note for open item 1: this cycle's *first* `farmctl health` call is the one that
wedged and was killed. The step-4 health check was still never satisfied.

## 7. Correction to §3 — health is pathologically slow, not deadlocked

§3 characterised the five `farmctl health` processes as "blocked, not computing"
on the basis of ~3 CPU-seconds after 10–25 minutes. A later scan at ~10:58Z
revises that:

- PIDs 4808, 5528 and 30744 **exited on their own** — they were not deadlocked.
- PID 32776 was still alive at **34.2 min**, but its user CPU had risen
  **2.8 s → 9.1 s**, i.e. it is making progress, just extremely slowly.

Corrected finding: `farmctl health` is **pathologically slow (25–35+ min per
run), not wedged.** Because the scheduled trigger fires far more often than a run
takes, invocations **overlap and stack** — five concurrent at 10:21Z. The
stacking is real and still worth fixing; the deadlock reading was wrong.

This changes the remedy in open item 1: the fix is not primarily a deadlock hunt
but (a) find why a health pass takes >25 minutes, and (b) make the scheduled
trigger non-overlapping (skip-if-running) so runs cannot pile up. A hard timeout
is still worth having as a backstop.

The correlation with the worker `sqlite_locked` claim backoffs stands as an
observation, but with several long-running health readers overlapping, causation
is more plausibly "slow overlapping readers contend with the claim writer" than
"health holds a lock and never releases it".
