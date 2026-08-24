# Worker logs made timestamp-complete: `at_utc` on `cpu_high_pause` / `claim_declined`

- **Task ID:** cf97e8c3-df2d-40cf-a268-976466782c0f (claude, ops_issue, priority 60)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Source:** `docs/ops/evidence/2026-08-24_throughput_forensics.md` (branch
  `rb-throughput-forensics`), §4 / recommendation 5: "Make logs timestamp-complete.
  Add `at_utc` to every `cpu_high_pause` and `claim_declined` emission. Today's logs
  cannot support an exact hourly histogram; this report deliberately uses bracketed
  lower bounds."
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)

## What changed

Pure logging addition, no behavior/threshold/sleep logic touched:

- `tools/strategy_farm/terminal_worker.py`
  - `_pause_after_unclaimed()` — the `claim_declined` JSON emission now includes
    `"at_utc": datetime.now(timezone.utc).isoformat()`.
  - `run_loop()` — the `cpu_high_pause` JSON emission (inside the CPU hysteresis
    guard) now includes the same `at_utc` field.
- `tools/strategy_farm/tests/test_terminal_worker_log_timestamps.py` (new, 2 tests):
  - `test_claim_declined_emission_has_at_utc` — calls `_pause_after_unclaimed()`
    directly (a standalone function, real code path, `time.sleep` mocked only to
    avoid a real delay) and asserts the emitted JSON line has a timezone-aware
    `at_utc` parseable by `datetime.fromisoformat`, and that the pre-existing
    fields (`event`, `reason`, `terminal`) are unchanged.
  - `test_cpu_high_pause_emission_has_at_utc` — drives one real iteration of
    `run_loop()` with disk/RAM checks mocked to pass and `_cpu_load_percent`
    mocked to exceed the ceiling, captures stdout, and asserts the emitted
    `cpu_high_pause` line has a valid `at_utc` plus its existing fields
    (`terminal`, `hysteresis_latched`) unchanged.

## Example lines (actual captured stdout from the two new tests, this run)

```json
{"event": "claim_declined", "at_utc": "2026-08-24T17:13:43.975508+00:00", "terminal": "T7", "reason": "no_pending_claimable", "lock": null, "history_skipped": 0, "launch_cooldown_skipped": 0}
{"event": "cpu_high_pause", "terminal": "T3", "at_utc": "2026-08-24T17:13:50.168198+00:00", "cpu_load_percent": 99.9, "threshold_percent": 97.0, "hysteresis_latched": true}
```

## Verification

- `python -m pytest -q tools/strategy_farm/tests/test_terminal_worker_log_timestamps.py`
  → **2 passed**.
- Re-ran adjacent existing suites to confirm no regression from the two edits:
  `test_terminal_worker_atomic_claim.py`, `test_claim_spacing.py`,
  `test_terminal_worker_adoption.py`, `test_terminal_worker_identity.py` →
  **86 passed**.
- No existing code in `farmctl.py` or `health.py` parses these two event types
  today (`grep` for both event strings returns no hits outside
  `terminal_worker.py` itself and the new test), so there is no existing
  strict-schema log parser this addition could break; the forensics report's
  own §4 explicitly describes falling back to heuristic line-bracketing
  because no such parser/timestamp existed.

## Not done

- No change to `CPU_MAX_LOAD_PERCENT`/`CPU_RESUME_LOAD_PERCENT`, sleep durations,
  or any other guard threshold — logging only, per the task's constraint.
- Did not add `at_utc` to other emission types in this file; the task named only
  these two, matching the forensics report's identified gap.
