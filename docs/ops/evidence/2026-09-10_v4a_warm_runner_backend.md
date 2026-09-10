# V4a warm-runner backend — controlled review outcome

Task: `da0512a7-0edf-46f6-b83e-bf4f67dcec55` (P84).

**Verdict:** `REVIEW — DEVIATION_NO_T10_WARM_EXECUTION`.

The current default-off implementation is not a resident-T10 backend.  Its
`ResidentSessionBackend` is an injected protocol used by unit tests.  The only
real-controller adapter in `tools/strategy_farm/warm_cell_runner.py` is the
task-bound `GovernedDev2RestartBackend`; it invokes the reviewed DEV2
controller and records a terminal restart per cell.  It is not a resident
session, is DEV2-bound, and cannot honestly satisfy this task's T10 / 20-cell
resident acceptance criterion.

`QM_ENABLE_WARM_CELL_RUNNER` remains unset and Default-OFF.  No T10 process,
worker reload, terminal restart, setfile, EA binary, worker path, queue row or
state DB was changed.  Therefore no 20/20 warm-versus-cold equality result,
speed-up estimate, fleet cells/hour projection, or rollout authorization is
claimed.

Focused verification passed on the existing contract:

- `tools/strategy_farm/tests/test_warm_cell_runner.py` verifies Default-OFF,
  owner-seal refusal, one-session sequencing with the injected backend,
  immediate mismatch stop, risk/news guardrails, receipt hashing and the
  DEV2 governed-controller binding.
- The code's validation setfile guard rejects `qm_news_stale_max_hours > 336`
  and requires positive `RISK_FIXED` with `RISK_PERCENT=0`.

## Required next implementation boundary

A future reviewable backend must use a supported, governed T10 command
surface—not a manual `terminal64.exe` start—and add all of the following before
any activation:

1. a terminal-owned resident session with per-cell input/report isolation,
   fresh logger/run authentication, crash/hang detection, and cold fallback;
2. a sealed, immutable set of 20 T10 cold references with exact identity,
   report-field and canonical-trade-byte comparisons;
3. continuous CPU/RAM guard and resident process ownership audit; and
4. a staged, orchestrator-only Default-OFF reload plan (`T10 -> T5 -> fleet`),
   with rollback by unsetting the flag and staggered idle-worker reload.

This task does not authorize activation.  The prior laboratory parity evidence
is not reclassified as a factory result.
