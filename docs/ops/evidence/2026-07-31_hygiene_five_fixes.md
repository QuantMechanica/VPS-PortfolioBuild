# 2026-07-31 hygiene five-pack — implementation evidence

Task: `50b8dabe-3937-4864-8c16-86e257afaa91`  
Brief: `docs/ops/CODEX_BRIEF_2026-07-31_hygiene_five_fixes.md`  
Implementation branch: `agents/board-advisor`

## Result

All five review findings were implemented as separate, path-scoped commits. No
Factory_ON/Factory_OFF command was run, no scheduled task was started/stopped or
reconfigured, no terminal/worker process was stopped, and T_Live/AutoTrading
were not touched.

| Item | Commit | Result |
|---|---|---|
| Pump-gate calibration | `7122eaf2b` | PASS |
| Framed validator records | `c817f5a74` | PASS |
| Canonical batch-coder enqueue | `916e80067` | PASS |
| Router list-order regression | `39f55a961` | PASS |
| Manual-kill evidence path | `7c1b19b83` | PASS |

## 1. Pump-gate calibration

Read-only Task Scheduler inspection confirmed
`QM_StrategyFarm_Pump_5min.Settings.ExecutionTimeLimit = PT10M` and
`MultipleInstances = IgnoreNew`. Correlating Event IDs 100/102 by instance ID
over the retained 14-day Operational log produced 74 completed pairs. Thirteen
were substantive runs longer than 30 seconds:

| statistic | seconds |
|---|---:|
| p50 | 550.203 |
| p75 | 599.982 |
| p90 | 599.996 |
| p95 | 599.999 |
| maximum | 599.999 |
| runs at or above 599 seconds | 5 |

The 1,800-second caller bound could therefore span multiple Pump attempts but
could not make a single scheduled attempt complete after its 600-second hard
ceiling. `Factory_ON.ps1` now passes 600 seconds, and
`factory_restart_health.ps1` rejects caller bounds above 600. The full health
predicate, early-success behavior, rollback path, task freshness checks, and
worker-cohort checks are unchanged.

Focused result: `test_factory_restart_post_start_health.py` — 16 passed.

## 2. Versioned framed validator records

The runtime-activation and restore-intent validators now emit exactly one
versioned record:

- `QM_FACTORY_RUNTIME_ACTIVATION_V1:<compact-json>`
- `QM_FACTORY_RESTORE_INTENT_V1:<compact-json>`

Factory_ON/OFF still check the native exit code first, then require exactly one
matching framed record. Unframed stdout/stderr noise is position-independent;
zero or duplicate records fail closed, and malformed framed JSON still fails
closed. The PowerShell 5.1 compatibility scope still restores
`ErrorActionPreference` after every native invocation.

Tests cover leading noise, trailing noise, non-zero native exit, duplicate
framed records, both PowerShell 5.1 and PowerShell 7, and direct Python CLI
framing.

## 3. `batch_coder.py` canonical enqueue

The private SQLite INSERT and its duplicated UUID/timestamp/capability fields
were removed. Generated skeletons now call `agent_router.enqueue_task` with
only the intentional business fields: `build_ea`, `BACKLOG`, artifact path, and
payload. Canonical validation/defaults now own task ID, timestamps, capabilities,
priority, budget class, skills, assignment, and verdict initialization.

Focused result: `test_batch_coder.py` plus `test_agent_router.py` — 23 passed at
the point-3 checkpoint.

## 4. Router list ordering

A regression test now fixes the public listing contract as:

1. `priority DESC`;
2. for equal priority, `updated_at DESC`.

The fixture deliberately inserts priorities `90, 90, 10` with inverse update
times and asserts the newer priority-90 row precedes the older priority-90 row,
and both precede priority 10. Focused router result: 22 passed.

## 5. Manual terminal/worker kill evidence

`tools/strategy_farm/manual_process_kill_evidence.py` is a deliberately
non-destructive pre-action recorder. It requires `actor`, `reason`,
`authority_ref`, PID and target type; inspects the live Win32 identity; rejects
T_Live; and accepts only:

- `terminal64.exe` under exact `C:\QM\mt5\T1` through `T10` roots; or
- canonical `C:\QM\repo\tools\strategy_farm\terminal_worker.py` workers with
  an exact `--terminal T1` through `T10` binding.

It appends a fsynced JSONL record with event ID, UTC timestamp, actor, reason,
authority reference, PID, creation time, executable path and command line to
`D:\QM\reports\state\manual_process_kills.jsonl`. The Operating Rules now
require a successful recorder exit and citation of that event ID before an
OWNER-authorized manual stop. The recorder contains no process-termination
primitive.

A read-only real-process probe normalized current PID `10328` as the canonical
T4 worker. The invocation called only the inspect/validate functions; it did not
append a kill-intent record or stop the process. Focused unit result: 4 passed.

## Aggregate verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_factory_live_fix_regressions.py \
  tools/strategy_farm/tests/test_factory_runtime_activation.py \
  tools/strategy_farm/tests/test_factory_restore_intent.py \
  tools/strategy_farm/tests/test_factory_restart_post_start_health.py \
  tools/strategy_farm/tests/test_batch_coder.py \
  tools/strategy_farm/tests/test_agent_router.py \
  tools/strategy_farm/tests/test_manual_process_kill_evidence.py -q

81 passed in 55.17s
```

Python bytecode compilation passed for every changed Python module/test.
PowerShell AST parsing passed for Factory_ON, Factory_OFF, and the restore-intent
contract test. `git diff --check` passed for each commit pathspec (only the
repository's expected future-CRLF warnings were emitted).

Verdict: **READY_FOR_CLAUDE_REVIEW**.
