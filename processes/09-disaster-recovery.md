---
title: Disaster Recovery
owner: OWNER
last-updated: 2026-07-22
---

# 09 — Disaster Recovery

This process covers VPS, disk, repository, terminal, data, scheduler, and backup
failures that exceed normal incident handling. OWNER is the sole authority for
live-capital decisions. Assigned workers execute bounded recovery steps; titles do
not confer approval authority.

## Trigger

- VPS or required storage becomes unavailable.
- Disk pressure prevents safe writes or backtests.
- Repository state, task definitions, data, or backup artifacts fail integrity
  checks.
- Factory processes disappear after an unexpected host or session failure.
- T_Live health cannot be established without changing live state.

## First response

1. Record UTC time, affected components, observed process/task/terminal state, and
   exact read-only evidence.
2. Protect T_Live: do not toggle AutoTrading, deploy, restart, or modify it unless
   the recovery task explicitly authorizes that exact action.
3. Stop only the unsafe work inside the affected scope. Do not kill unrelated
   factory workers or terminals.
4. Classify the incident:
   - **Sev-0:** live capital may be at immediate risk;
   - **Sev-1:** factory or VPS is unavailable with material state uncertainty;
   - **Sev-2:** degraded component with safe containment available;
   - **Sev-3:** transient failure that recovered and only needs verification.
5. Notify OWNER immediately for Sev-0 and before any action that changes live
   trading state, destroys data, or performs an irreversible rollback.

## Recovery order

1. Verify disk space, filesystem availability, and repository integrity.
2. Verify current Windows tasks and process command lines against repository
   installers. Do not assume a process should be running merely because an old
   evidence file names it.
3. Restore the deterministic strategy-farm controller and T1-T5 workers from their
   current installers and state database.
4. Verify data sources, setfiles, binaries, and deployed hashes before accepting
   new test results.
5. Verify backups by manifest and hash before using them. Prefer forward repair;
   do not overwrite newer valid state with an older snapshot.
6. Inspect T_Live read-only. Any live restart, deployment, or trade-state change
   needs explicit OWNER authorization and the applicable live runbook.

## Exit criteria

- Required filesystem paths, tasks, and processes match the current desired state.
- Strategy-farm state is readable and no active job was silently relabeled.
- T1-T5 tests can produce artifact-bound evidence.
- T_Live remains isolated and its state is documented.
- A dated incident record contains root cause, repairs, verification output, and
  any remaining risk.

If an exit criterion fails, keep the affected component contained and report the
specific blocker to OWNER. Do not convert missing evidence into a PASS.

## References

- [Incident response](04-incident-response.md)
- [Disk and sync](11-disk-and-sync.md)
- [Infrastructure task installer](../infra/tasks/Register-QMInfraTasks.ps1)
- [Strategy-farm runbook](../docs/ops/OPTION_A_STRATEGY_FARM_RUNBOOK.md)
