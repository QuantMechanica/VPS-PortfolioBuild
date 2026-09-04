# Finished-but-alive terminal recovery

2026-09-04. Router task `d9379ede-3369-470f-87a9-68b1baa13bb0`.
RESULT: IMPLEMENTED; **83 focused regression tests PASS**. Leave REVIEW.

Code commit `bb606040f69e206e4e0d0fe88717517d24eca3d7` on `agents/codex`. [Unapplied patch](2026-09-04_terminal_finished_but_alive.patch). This commit follows and depends on monitor-budget commit `14e65476a1`; the code base includes required `29d4f083b6` and all five prerequisite commits named in the task. No canonical runtime code or active terminal was changed by this delivery.

[Integration check](2026-09-04_terminal_finished_but_alive_apply_check.json): the monitor-budget patch followed by this patch applies cleanly to the recorded canonical HEAD in an isolated temporary Git index, with a clean code whitespace check. Applying this dependent patch alone before the prerequisite correctly fails its context checks. The canonical worktree/index and branch references were not changed by the integration check.

## Behavior

The owning terminal worker polls for a completed-test hang every 30 seconds. Recovery requires all of the following evidence for the current run:

- The latest runner-log `terminal_start` and `terminal_spawn_confirmed` agree, with no subsequent terminal exit, report latch, or next-run start/config marker.
- The exact INI is under this work item's report root and a `raw/run_NN` directory. It is a non-optimization test with `ShutdownTerminal=1`. The terminal's latest native startup/config marker names that same INI.
- The confirmed terminal PID is alive, its executable is the expected T1–T10 `terminal64.exe`, and its Windows creation key exactly matches all **seven fractional timestamp digits** recorded by .NET. PID reuse, other images and T_Live are refused.
- The UTF-16 tester log contains `automatic testing finished` after this process started, with no later test-start marker. Historical or superseded run markers are refused.
- No HTML report exists in the raw run directory, and neither the configured native report nor its HTM/HTML variants exists. Even an empty report file prevents recovery, avoiding termination while a report is being produced.
- The same completed run has been continuously observed for **more than 300 monotonic seconds**. A new run or missing evidence resets that wait. This deliberately waits five minutes from first observation, including when an older completed hang is first discovered after worker adoption.

Immediately before recovery, the log/config/report/identity checks repeat. The worker opens a Windows process handle with query/terminate rights, checks creation identity and image through that handle, and terminates that exact terminal handle. It does not kill the runner or a process tree. The generic controller PID-stop function remains disabled and unchanged. A refused termination is recorded once for that run; the existing monitor remains responsible afterward.

The runner continues through its ordinary missing-report/retry handling. A runner that subsequently exits after this recovery reaches normal completion handling instead of being mistaken for an unexplained runner death. Existing `run_smoke.ps1` and its timeouts are unchanged.

Each attempt emits `terminal_finished_but_alive` with runner and terminal PIDs, creation identity, process start, tester finish line/path, exact INI, absent report paths, first observation, elapsed grace, action time and termination result. It is retained in the worker log, DB event and final run-result payload. Health reports last-24-hour detections, successful terminations and counts by UTC day. These are operational metrics, not pipeline verdicts.

## Verification and incident evidence

[Validation receipt](2026-09-04_terminal_finished_but_alive_validation.json): **83 tests PASS** across finished-terminal, monitor-budget, worker-adoption and summary-classification suites. The 29 new tests include UTF-16 logs, strict 299/300/301-second boundaries, exact FILETIME conversion, fake PID/process handles, same-handle verification, PID reuse at the final recheck, report arrival during grace, next-run transitions, later active-test messages, stale finishes, wrong INIs, unsupported terminals, structured events, health counts and normal runner completion without a runner kill.

The FILETIME fixture was independently checked with `DateTimeOffset.UtcDateTime.ToFileTimeUtc()`: `2026-09-04T12:00:00.1234567+02:00` maps to `134329896001234567`. A one-digit 100-nanosecond change produces a different identity key.

[Read-only live probe and historical log excerpts](2026-09-04_terminal_finished_but_alive_probe.json): seven active T1–T10 claims checked, **zero candidates**, no termination function called. New-class live health counts are zero because this code is not deployed.

The retained T2 tester log contains the reported `14:52:44.496 automatic testing finished` line. Its native terminal log binds the old work item `b7b1fb26-6947-54ed-82b8-3c276212d7c2` to run_01 starting near 14:48:21 and run_02 near 16:45:22. The current work-item runner log has since been replaced by its successful T8 rerun. These are historical incident excerpts, not a claim that the old PID remains eligible for termination now. The detector requires a current, exact process/config binding.

Reproduce in `C:/QM/worktrees/codex`:

```text
python -m pytest tools/strategy_farm/tests/test_finished_terminal.py tools/strategy_farm/tests/test_monitor_budget.py tools/strategy_farm/tests/test_terminal_worker_adoption.py tools/strategy_farm/tests/test_summary_missing_classification.py -q
```

## Limits and handoff

The detector reads bounded tails (2 MiB per file, latest three native days) and refuses recovery when those tails omit the required binding. It currently covers conventional non-optimization `run_smoke` reports in raw run directories with a native report basename. Unsupported layouts, uncertain process identity, missing logs or report activity leave the existing monitor in charge. No real hang was induced and no active backtest was interrupted for validation; process termination tests use mocked Windows handles.

Code changes are limited to `finished_terminal.py`, worker wiring, health telemetry and tests. Evidence is committed only on `agents/board-advisor`. The pre-existing MagicResolver edit is untouched. Integration and acceptance remain with Claude+OWNER; this task does not advance main or authorize live trading.
