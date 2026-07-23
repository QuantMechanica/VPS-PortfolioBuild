# QUA-1083: Multi-EA Cross-Terminal Scheduler (Phase 4 prerequisite)

Date: 2026-05-09  
Owner: CTO  
Status: Operational spec alignment for active infrastructure (historical title retained for audit fidelity)

## Governance Reframe (DL-061, 2026-05-09)

Per DL-061, company-level phase gating is dissolved. This work is now W6 Cross-Terminal Scheduler (always-on infra). The historical "Phase 4 prerequisite" label in this title/filename is retained only for audit continuity.

## 1) Scope

Define a deterministic scheduler contract that can run multiple EAs across T1-T5 without overlap, while preserving V5 hard rules and terminal isolation boundaries. Under DL-061 this is continuous operational infrastructure (not phase-gated) and does not change strategy logic.

Out of scope:
- T6 Live/Demo operations
- EA entry/exit model changes
- PASS/FAIL strategy decisions

## 2) Non-negotiable Constraints

- No T6 path access at runtime (`C:\QM\mt5\T6_Live\`, `C:\QM\mt5\T6_Demo\`).
- No file deletion flows in scheduler actions.
- Darwinex MT5 native data only; no external market APIs.
- Each EA run must preserve framework risk interface (`RISK_FIXED`/`RISK_PERCENT`) through existing setfiles.
- Scheduler executes Model 4 (Every Real Tick) jobs only; reject model drift at preflight.
- Symbol handling must retain `.DWX` in research/backtest context.
- Magic number collisions remain hard-abort conditions (delegated to framework/runtime checks).

## 3) Runtime Model

Use a two-layer model:
- Layer A: Windows Task Scheduler trigger (time cadence, SYSTEM principal, `IgnoreNew`).
- Layer B: Python orchestrator (`multi_ea_scheduler.py`) with state-aware dispatch and per-terminal occupancy enforcement.

Single entrypoint command:

```powershell
python -m framework.scripts.multi_ea_scheduler --sleep-seconds 30
```

## 4) Scheduler Manifest Contract

Queue source contract (built by `build_multi_ea_queue.py`) uses job objects with:
- `ea_id`
- `phase`
- `symbol` (must end with `.DWX`)
- `config_hash`

Scheduler inputs:
- queue file (`multi_ea_job_queue.json` by default)
- scheduler state file (`multi_ea_scheduler_state.json` by default)
- run records directory (`multi_ea_scheduler_runs/` by default)

Validation is fail-fast: invalid queue payload blocks dispatch tick.

## 5) Locking and Concurrency

Concurrency model:
- One active MT5 execution per terminal (`T1`..`T5`) enforced via in-memory/state `running` map.
- Scheduler reconciles finished PIDs before assigning new launches.
- Jobs that cannot be scheduled due to terminal occupancy remain queued (deferred, not failed).

## 6) Dispatch Policy

Selection order per tick:
1. Enabled jobs only.
2. Deterministic queue order (producer-defined order from queue builder).
3. Skip jobs with unmet terminal availability.
4. Respect `max_parallel_jobs` and per-terminal singleton rule.

Execution wrapper per job:
- Preflight checks (phase support, `.DWX` symbol policy, command build viability).
- Launch MT5 runner command.
- Capture exit code, start/end UTC, artifact paths.
- Release job/terminal lock in `finally`.

## 7) Evidence and State Outputs

Write machine-readable state:
- `D:\QM\Reports\pipeline\multi_ea_scheduler_state.json` (default)
- `D:\QM\Reports\pipeline\multi_ea_scheduler_runs/<timestamp>_<job_id>.json` (default)

Required fields:
- `run_id`
- `job_id`
- `terminal`
- `status` (`success|failed|deferred|skipped`)
- `reason`
- `started_at_utc`
- `ended_at_utc`
- `duration_sec`
- `exit_code`
- `evidence_paths`

## 8) Failure Policy

Hard-fail (non-zero orchestrator exit):
- queue payload invalid
- forbidden terminal/path detected
- unsupported phase dispatch request

Soft-fail (orchestrator stays zero, job marked failed/deferred):
- single job execution failure
- terminal busy
- missing optional artifact for one job

## 9) Minimal Acceptance Tests

1. Queue validation rejects symbol values without `.DWX`.
2. Scheduler refuses T6 terminal IDs/paths.
3. Scheduler never dispatches two concurrent jobs to the same terminal.
4. State JSON is emitted for launch, defer, and reconcile outcomes.
5. Unsupported phase produces deterministic scheduler error.

## 10) Implementation Breakdown (Child-Issue Ready)

1. Keep queue builder and scheduler schema in sync (`framework/scripts/build_multi_ea_queue.py`, `framework/scripts/multi_ea_scheduler.py`).
2. Maintain scheduler installer script (`infra/scripts/Install-MultiEASchedulerTask.ps1`) and verify task registration.
3. Extend unit tests for queue/state/dispatch behavior (`framework/tests/unit/test_multi_ea_scheduler.py`).
4. Maintain runbook section in `infra/README.md` and `infra/scripts/README.md` with install/verify commands.

## 11) Open Decisions Needing OWNER/CEO Confirmation

1. Final cadence window (hourly vs sub-hourly).
2. `max_parallel_jobs` default (proposed: `2`).
3. Retry policy for transient MT5 launch failures (proposed: no auto-retry in same tick).
