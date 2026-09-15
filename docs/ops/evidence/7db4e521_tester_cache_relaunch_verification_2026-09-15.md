# Tester-cache purge relaunch verification — task `7db4e521-37f2-4649-8b12-9f8421315a34`

## Verdict

The 2026-09-12 15:20Z partial relaunch was an admission-policy interaction,
not a failed console-session launch and not a `worker_pids.json` rewrite race.
The purge accepted a successful `start_terminal_workers.py --dedupe` process
without checking that it had restored the worker set present before the purge.

The purge now binds recovery to that exact pre-purge T1–T10 worker set. After
each idempotent interactive-token launch it waits 10 seconds, scans actual
worker command lines, and compares the normalized expected and running sets.
A mismatch triggers exactly one retry. Every attempt is journaled with
expected, running, missing, unexpected, launcher status, and probe status. A
second mismatch emits `ALARM event=TESTER_CACHE_RELAUNCH_INCOMPLETE` and exits
with code 4 rather than recording a partial relaunch as success.

## Incident reconstruction

Source: `D:/QM/reports/state/tester_cache_purge.log`, durable line numbers
98190–98231 at inspection.

| UTC event | Bound fact |
|---|---|
| 15:20:09 | Purge triggered at 59.83 GB free against the 60 GB threshold. |
| 15:20:10 | Preflight found 15 targets / 1.834 GB of candidates. |
| 15:20:20 | Five active/running terminals were protected: T3, T4, T5, T9, T10. |
| 15:20:21–22 | Idle caches were purged for T1, T2, T6, T7, T8. |
| 15:20:24 | 1,969,153,556 bytes were deleted; reported free space rose only 1.8 GB, to 61.67 GB. |
| 15:20:39 | The console-session launcher reported `LAUNCHED pid=19080` and `WAIT_EXIT ... code=0`; therefore token launch and child exit both succeeded. |
| 15:20:39 | The child measured 61.66 GB free, selected disk as bottleneck, calculated `additional_capacity=2`, `max_workers=7`, and returned exactly seven daemons. |
| 15:20:39 | Its returned worker map contained T1, T2, T3, T4, T5, T9, T10; T6, T7, and T8 were absent by policy. |
| 15:28:49 | The journal observed 77.13 GB free after delayed filesystem/concurrent reclamation, explaining why a later orchestrator dedupe could admit the remaining workers. |

`start_terminal_workers._governed_terminals()` preserves all workers already
running and admits missing terminals only up to the current resource cap. With
five protected survivors and disk capacity for two additions, its seven-worker
result was internally correct. The defect was the purge's weaker success
predicate: launcher exit success was treated as fleet restoration.

## Implementation

- `tester_cache_purge.ps1` captures the actual T1–T10 worker set before any
  scheduled-task stop or idle-worker teardown.
- `tester_cache_relaunch.ps1` provides an injectable, exact-set verifier with a
  fixed two-attempt loop. It has no process-stop operation.
- Recovery retains the existing interactive-session launcher and
  `start_terminal_workers.py --dedupe`; existing singleton workers are reused.
- The process probe accepts only `T1`–`T10`. `T_Live`, `T_Export`, and the
  inert T11/T12 canaries are outside the comparison and every purge kill path.
- Probe or launcher exceptions are fail-loud alarms. Neither can silently
  downgrade the expected fleet.

## Verification

No purge, worker restart, terminal launch, or cache deletion was performed.
Only injected scriptblocks were used in the behavioral tests.

```powershell
python -m pytest tools/strategy_farm/tests/test_tester_cache_purge_owner_state.py tools/strategy_farm/tests/test_tester_cache_relaunch.py tools/strategy_farm/tests/test_start_terminal_workers_env.py -q
```

Result: `13 passed in 9.60s`.

The tests cover Windows PowerShell 5.1 parsing, exact-set normalization,
one-attempt success, one retry followed by success, exhausted retry with both
missing and unexpected terminals, ordering of snapshot-before-teardown, the
alarm/exit contract, owner-state preservation, and launcher environment
preservation.

SHA-256 bindings:

- `tester_cache_purge.ps1`:
  `6a2a2de95e95d9c875dc1ea9791792fefcf4a1dff0f6754332d14ce89f5555fc`
- `tester_cache_relaunch.ps1`:
  `8c154794e18a791879477f8877796a7dde4f02788e55e2a3d882ab944f20b702`
- unchanged `start_terminal_workers.py`:
  `a8f037a9c25c0462e85b3025fcc625e3365a4fcb59fcffd216c24f8c67c847fb`

RESULT task=7db4e521-37f2-4649-8b12-9f8421315a34 verdict=PASS root_cause=disk_admission_partial_set_accepted relaunch_attempts_max=2 exact_set_verification=true outcome_journal=true alarm_exit=4 live_actions=0
