# SUB-DIRECTIVE: Build the MT5 worker-pool backtest queue

**Parent:** QUA-1562 (Master Directive — continuous pipeline)
**Routing:** CEO (`7795b4b0`) → CTO (`241ccf3c`) lead design, Dev-Codex (`ebefc3a6`) primary implementer, HoP (`46fc11e5`) integration with phase_orchestrator.py. **Board Advisor 2026-05-15 draft, OWNER ratified.**
**Priority:** critical (unblocks the only currently-bottlenecked pipeline stage)

---

## Aufgabe

Replace the current sequential Phase Orchestrator dispatch model with a **claim-based worker pool**: one deterministic Python worker per MT5 terminal (T1–T5), pulling jobs atomically from a shared SQLite queue. Each worker runs one backtest at a time, owns its `Tn/` data dir for the duration, parses the result, and releases the job. Goal: 5–10× backtest throughput, zero parallel-launch collisions, zero AI tokens in the hot loop.

This is the single most impactful change for V5 throughput. Without it, the company stalls on tester contention every time CEO approves more than one EA at a time.

## Was zu tun

### 1. Schema — `D:/QM/reports/pipeline/mt5_queue.db` (SQLite)

```sql
CREATE TABLE jobs (
  job_id            TEXT PRIMARY KEY,             -- uuid4
  ea_id             TEXT NOT NULL,
  version           TEXT NOT NULL,                -- 'smoke' | 'baseline' | etc.
  symbol            TEXT NOT NULL,
  period            TEXT NOT NULL,                -- 'H1', 'H4', 'M15'
  year              INTEGER NOT NULL,
  phase             TEXT NOT NULL,                -- 'P1','P2','P3','P3.5','P4','P5','P5b','P5c','P6'
  sub_gate_config_hash TEXT NOT NULL,             -- ea_id|version|symbol|phase|year fingerprint
  setfile_path      TEXT NOT NULL,                -- absolute, forward slashes
  status            TEXT NOT NULL,                -- queued | claimed | running | done | failed | invalid
  verdict           TEXT,                         -- PASS | FAIL | INVALID | NULL while in-flight
  invalidation_reason TEXT,                       -- 'no_summary_json:rc=1' etc.
  claimed_by        TEXT,                         -- 'T1'..'T5' or NULL
  claimed_at        TEXT,                         -- ISO-8601 UTC
  started_at        TEXT,
  finished_at       TEXT,
  result_path       TEXT,                         -- D:/QM/reports/pipeline/<ea>/<phase>/<symbol>/<runid>/summary.json
  retry_count       INTEGER NOT NULL DEFAULT 0,
  enqueued_at       TEXT NOT NULL,
  enqueued_by       TEXT NOT NULL                 -- 'phase_orchestrator' | 'gate_evaluator' | 'manual'
);

CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_claimed_by ON jobs(claimed_by) WHERE claimed_by IS NOT NULL;
CREATE INDEX idx_jobs_dedup ON jobs(sub_gate_config_hash);

CREATE TABLE worker_heartbeat (
  terminal_id       TEXT PRIMARY KEY,             -- 'T1'..'T5'
  pid               INTEGER,
  last_seen_utc     TEXT NOT NULL,
  current_job_id    TEXT,
  jobs_completed    INTEGER NOT NULL DEFAULT 0,
  last_error        TEXT
);
```

### 2. Worker loop — `framework/scripts/mt5_worker.py`

One file, parametrized by `--terminal T1..T5`. Each worker runs as its own Windows Scheduled Task (`QM_MT5_Worker_T1` ... `QM_MT5_Worker_T5`) with `LogonType=S4U`, runs every minute (the loop polls inside, the task just ensures liveness). The script:

1. **Liveness ping** — UPSERT into `worker_heartbeat` with current PID and timestamp.
2. **Pre-flight** — confirm `D:/QM/mt5/Tn/terminal64.exe` exists, `MQL5/Profiles/Tester/Groups/<server>_<account>.txt` present with commissions block.
3. **Atomic claim** — single SQLite transaction:
   ```sql
   UPDATE jobs SET status='claimed', claimed_by=?, claimed_at=? 
     WHERE job_id = (
       SELECT job_id FROM jobs 
       WHERE status='queued' 
       ORDER BY enqueued_at ASC LIMIT 1
     )
   RETURNING *;
   ```
   If nothing claimed → sleep 30s and loop.
4. **Verify EA + setfile on this terminal** — check `D:/QM/mt5/Tn/MQL5/Experts/QM/<ea>.ex5` and the `setfile_path` exist on disk. If not, mark job `failed` with `'deploy_missing:<path>'` and continue. (Don't deploy from worker — that's a separate concern, see §6.)
5. **Run** — invoke `terminal64.exe /portable /config:tester.ini` with the standard run_smoke pattern. Single foreground subprocess; worker owns `Tn/` for the duration.
6. **Parse result** — read produced `summary.json`, `report.htm`, `20*.log`. Decide verdict (PASS/FAIL/INVALID).
7. **Write back** — UPDATE jobs SET status='done', verdict=?, finished_at=?, result_path=? WHERE job_id=?.
8. **Release & loop** — set `worker_heartbeat.current_job_id = NULL`, go back to step 1.

**Concurrency invariant:** at most ONE running `terminal64` per `Tn/` at any time (the worker holds it). At most 5 backtests running company-wide. No file-lock collisions.

### 3. Gate evaluator — `framework/scripts/gate_evaluator.py`

Run as `QM_GateEvaluator_5min` Scheduled Task (S4U). For each row where `status='done'` and not yet rolled forward:

1. Apply phase gate criteria from `framework/registry/tester_defaults.json` (PF, trades, DD).
2. If PASS → generate next-phase set files via `gen_setfile.ps1`, deploy via `deploy_ea_to_all_terminals.ps1`, enqueue next-phase jobs.
3. If FAIL or INVALID with infra cause (`no_summary_json:rc=1`, `REPORT_MISSING`) → mark `retry_count++`, requeue if `< 3`; else mark `failed_terminal`.
4. If FAIL with strategy cause (`MIN_TRADES_NOT_MET`) → mark `blocked_strategy`, **create a Paperclip issue** assigned to Zero-Trades-Specialist (`8ba981d2`) — this is the agent-handoff at the failure boundary.
5. After processing, mark the source job's `verdict_processed_at` so we don't double-handle.

Gate evaluator never runs `terminal64` itself. It only reads queue state and writes new queue rows.

### 4. Phase Orchestrator integration

Existing `framework/scripts/phase_orchestrator.py` is repurposed to **enqueue jobs into `mt5_queue.db`** instead of launching `p2_baseline.py` directly. Per EA-in-pipeline-state, it:
- Looks up next phase to run from `dispatch_state.json`
- Generates dedup-key `ea_id|version|symbol|phase|sub_gate_config_hash`
- INSERT OR IGNORE into jobs (dedup key prevents re-queuing in-flight or already-done jobs)

Keep the hourly Windows Task schedule. Orchestrator becomes "the producer", workers are "the consumers". The existing `dispatch_state.json` continues to track per-EA phase progression — workers don't touch it, gate evaluator does.

### 5. Deployment pre-flight (existing path, keep)

`framework/scripts/deploy_ea_to_all_terminals.ps1` is already idempotent SHA-checked deploy across T1–T5. Gate evaluator calls it BEFORE enqueuing next-phase jobs. Workers verify on-disk presence as a safety check but don't deploy.

### 6. Watchdog integration

Add a `detector_e_worker_pool_health` to `C:/QM/paperclip/tools/ops/pipeline_health_watchdog.py`:
- ALARM if any worker's `last_seen_utc` is > 5 min stale (worker hung)
- ALARM if queue depth `> 50` for `> 30 min` (producer outpacing consumers)
- ALARM if `claimed_at` is older than 30 min on any single job (stuck backtest)

## Leitprinzipien

- **No AI tokens in the hot loop** — workers are pure Python. Agent only touched at the failure boundary (Zero-Trades dispatch).
- **Atomic claim** — single UPDATE with returning. SQLite handles concurrency. No file-lock games.
- **Deterministic, debuggable** — every state transition has a SQL row update and a timestamp. `sqlite3 mt5_queue.db "SELECT * FROM jobs ORDER BY enqueued_at DESC LIMIT 20"` shows pipeline state at any moment.
- **Idempotent** — re-running orchestrator or evaluator never breaks state. Dedup-key prevents double-enqueue.
- **T6 OFF LIMITS** (Hard Rule) — workers explicitly refuse if `--terminal T6` is passed.
- **Backwards-compatible** — existing `dispatch_state.json`, `report.csv` outputs continue to be written (workers + evaluator produce them). Dashboard/watchdog code keeps working.
- **Evidence over claims** (Hard Rule) — every job's verdict references a real `summary.json` path or an `invalidation_reason` string. No verdict without artifact.
- **Hard Rule preservation**: `RISK_FIXED=$1000` for backtests, `RISK_PERCENT` for live (DL-054). Workers don't generate set files — gate evaluator calls `gen_setfile.ps1` which respects defaults from `tester_defaults.json`. Worker just runs whatever `setfile_path` it's handed.

## Pfade

- Queue DB: `D:/QM/reports/pipeline/mt5_queue.db`
- Worker script: `C:/QM/repo/framework/scripts/mt5_worker.py` (new)
- Gate evaluator: `C:/QM/repo/framework/scripts/gate_evaluator.py` (new)
- Phase Orchestrator (modify): `C:/QM/repo/framework/scripts/phase_orchestrator.py`
- Deploy script (existing): `C:/QM/repo/framework/scripts/deploy_ea_to_all_terminals.ps1`
- Set-file generator (existing): `C:/QM/repo/framework/scripts/gen_setfile.ps1`
- Tester defaults (do not modify): `C:/QM/repo/framework/registry/tester_defaults.json`
- Watchdog (extend): `C:/QM/paperclip/tools/ops/pipeline_health_watchdog.py`
- Scheduled tasks to create: `QM_MT5_Worker_T1` ... `QM_MT5_Worker_T5`, `QM_GateEvaluator_5min`
- Evidence dir: `C:/QM/repo/docs/ops/evidence/2026-05-XX_mt5_worker_pool_smoketest/`

## Akzeptanzkriterien

A demonstrable end-to-end run, all evidence written:

1. **Schema created**: `mt5_queue.db` exists, `sqlite3 -header -column ... ".schema jobs"` matches §1. (Evidence: schema dump in CSV.)
2. **5 workers running**: `Get-ScheduledTask QM_MT5_Worker_T*` shows 5 tasks, all `State=Ready`, last run in last 5 min, last result `0`. (Evidence: PowerShell output.)
3. **Liveness rows**: `worker_heartbeat` table has 5 rows, all with `last_seen_utc` within 90 s. (Evidence: SELECT dump.)
4. **Atomic claim verified**: enqueue 10 dummy jobs, start workers, confirm no two `claimed_by` values for the same `job_id`. (Evidence: SELECT job_id, claimed_by, COUNT(*) GROUP BY job_id HAVING COUNT(*) > 1 returns zero rows.)
5. **Smoke-test E2E**: one real EA (suggest QM5_1003 since it's already deployed) goes from `phase_orchestrator.py` enqueue → 8 jobs queued (one per symbol) → 5 workers concurrently drain → all 8 results written → gate evaluator reads results → either next-phase enqueue or Zero-Trades issue created. End-to-end wall time < 15 minutes. (Evidence: CSV log of job state transitions.)
6. **Failure paths**: simulate `no_summary_json:rc=1` by killing terminal64 mid-run; worker writes `invalid` verdict + `retry_count=1`; gate evaluator re-queues; second attempt completes. (Evidence: jobs table showing retry chain.)
7. **Hard rule preservation**: `framework/scripts/build_check.ps1` on every EA in the smoke-test still passes. No new EA `.ex5` introduced; no commissions/swap/DST values modified.
8. **Token-budget impact**: in the 15-min smoke-test window, AI agent heartbeat-runs related to backtest dispatch = **0** (workers and evaluator are pure Python). Verified by `GET /heartbeat-runs?limit=200` filtered to that window.
9. **No T6 contamination**: `git status` shows no changes to `C:/QM/mt5/T6_Live/`. `mt5_worker.py --terminal T6` refuses with exit code 2.
10. **Evidence CSV**: `docs/ops/evidence/2026-05-XX_mt5_worker_pool_smoketest/` contains worker logs (one per Tn), schema dump, claim-collision audit, E2E timing.

## Hintergrund

The "MT5 multi-EA saturation scheduler" routine (`93af0c1f`, paused 2026-05-15) was scaffolded for exactly this design but the queue producer was never built — the routine kept firing on an empty (non-existent) queue, looped on continuation_needed, and burned tokens until Board Advisor paused it. This sub-directive completes that scaffolding correctly.

Currently observed P2 baseline runs show ~75% INVALID rate (`no_summary_json:rc=1`, `REPORT_MISSING`) on EAs like QM5_1017 / QM5_SRC04_S03 — root cause is parallel `terminal64 /portable` launches colliding on shared `Tn/` data dirs. The worker-pool eliminates this category of failure structurally (one worker = one terminal at a time).

OWNER directive 2026-05-15T09:30Z: "build it now". Sub-issue of master directive QUA-1562.

## Non-Goals

- No T6 worker (Hard Rule).
- No founder-comms / Gmail-Agent buildup (deferred).
- No new EAs (this is infrastructure, not strategy).
- No new dependencies beyond Python stdlib + existing PowerShell scripts (`sqlite3` is stdlib).
- No replacement of `dispatch_state.json` — it stays as the authoritative per-EA phase tracker; queue is for per-job tracking.
- No agent in the worker hot loop. Agent only touched at the strategy-failure boundary (Zero-Trades-Specialist dispatch from gate evaluator).
- No live trading changes (separate sub-directive when an EA reaches P7).

## Suggested implementation order (CTO discretion)

1. Schema + queue create script (Dev-Codex, ~2h) — `framework/scripts/queue_init.py`
2. Single-worker prototype against T1 only — proves the run loop (Dev-Codex, ~4h)
3. 5-worker rollout with Scheduled Tasks (HoP, ~2h)
4. Gate evaluator with PASS path (Dev-Codex, ~4h)
5. Gate evaluator with FAIL/INVALID retry + Zero-Trades dispatch (Dev-Codex, ~3h)
6. Orchestrator producer integration (HoP, ~3h)
7. Watchdog detector_e (CTO, ~1h)
8. Smoke-test + evidence (HoP, ~2h)

**Total: ~20h focused work. CEO: route subtasks. Board Advisor: review schema + acceptance evidence before declaring done.**
