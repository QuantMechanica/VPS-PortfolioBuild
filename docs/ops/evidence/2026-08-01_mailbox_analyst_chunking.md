# Mailbox analyst backlog chunking

Date: 2026-08-01
Router task: `e657a83f-1631-42c9-976d-ac97270b153f`
Implementation commit: `3badd51343b49ee3c9f5f624e8603a05236a9970`
Status: IMPLEMENTED; NATURAL-RUN VERIFICATION PENDING

## Outcome

The mailbox intake now dispatches the analyst sequentially in stable chunks of at
most 10 leads instead of sending the entire retryable backlog to one process. Each
chunk has a 360-second process timeout. The wrapper reconciles the chunk against
the canonical `leads.csv`, rebuilds the terminal-status audit, and writes a durable
`analyst_chunk_complete` JSONL checkpoint before it launches the next chunk.

The wrapper starts its wall-clock budget before the mailbox sweep. It stops
launching chunks after 40 minutes or whenever fewer than 480 seconds remain (one
full chunk timeout plus a 120-second reconciliation/cleanup reserve). The outer
scheduled-task limit remains 45 minutes and the MNT-003 console bridge remains
2,640 seconds. An early stop does not edit untouched rows, so they remain `NEW` or
otherwise explicitly retryable for the next scheduled attempt.

No scheduled task was started manually. The next natural runtime verification is
the existing `2026-08-02 06:07:07 +02:00` trigger.

## Incident evidence

The first natural run under the new MNT-003 task contract occurred at
`2026-08-01 06:07:07 +02:00`:

- Task Scheduler principal/action: `SYSTEM` / `ServiceAccount`, bridging through
  `run_in_console_session.ps1` to the logged-on `qm-admin` token; task result
  `0x00000001`.
- The extraction sweep succeeded in 19.9 seconds, collected 53 new rows, and
  advanced the mailbox watermark from 459 to 528. Together with three older
  retryable rows, the analyst received 56 leads.
- The single analyst process reached the old 1,800-second timeout (`rc=124`). Its
  managed process termination was confirmed.
- The canonical CSV currently contains 106 rows, of which exactly 56 are
  retryable and all 56 have status `NEW`. No lead was falsely marked terminal.
- Durable incident artifacts:
  - `D:\QM\reports\sourcing_intake\summary_20260801T040704Z.md`
  - `D:\QM\reports\sourcing_intake\analyst_prompts\analyst_20260801_040724.md`
  - `D:\QM\reports\sourcing_intake\analyst_prompts\analyst_20260801_040724.log`
  - `D:\QM\reports\sourcing_intake\mailbox_source_intake_run_log.jsonl`

This establishes a monolithic-dispatch timeout, not a scheduler-launch, sweep, or
credential-bridge failure.

## Implementation

Changed only the mailbox intake implementation, its analyst prompt, and focused
tests:

- `tools/strategy_farm/mailbox_source_intake.py`
  - `ANALYST_CHUNK_SIZE = 10`; the incident backlog deterministically becomes
    `10, 10, 10, 10, 10, 6`.
  - `ANALYST_CHUNK_TIMEOUT_SECONDS = 360`.
  - `RUN_BUDGET_SECONDS = 2400` and `SHUTDOWN_GRACE_SECONDS = 120`.
  - Microsecond prompt/log names prevent collisions between sequential chunks.
  - Terminal handoff evidence is verified after every chunk. A qualified result
    still requires the exact factory source and source-linked draft card.
  - Each chunk writes a status snapshot and `analyst_chunk_complete` checkpoint.
  - Capacity/spawn failure and unconfirmed child termination stop cleanly.
    Confirmed per-chunk timeout permits the next independent chunk to run.
  - Final success still requires every initially retryable URL to have a verified
    terminal handoff; process return codes remain diagnostic rather than overriding
    canonical postconditions.
- `tools/strategy_farm/prompts/mailbox_source_intake_prompt.md`
  - Directs the analyst to persist each row's status immediately before starting
    the next lead, so completed work survives a later-lead timeout.
- `tools/strategy_farm/tests/test_mailbox_source_intake.py`
  - Covers the exact 56-lead chunk calculation, sequential per-chunk persistence,
    and a budget early-stop that completes the first 10 of 12 rows while leaving
    the final two retryable.
  - Aligns the local task-contract assertion with the already-applied MNT-003 v2
    SYSTEM-to-console-session bridge.

## Verification

Executed from `C:\QM\repo`:

```text
python -m py_compile tools\strategy_farm\mailbox_source_intake.py
python -m pytest tools/strategy_farm/tests/test_mailbox_source_intake.py tools/strategy_farm/tests/test_mnt003_installer_alignment.py tools/strategy_farm/tests/test_task_contract_fix_package.py -q

...................................                                      [100%]
35 passed in 5.96s
```

`git diff --check` reported no whitespace errors on the three implementation
paths. No mailbox sweep, analyst dispatch, scheduled-task start, terminal launch,
factory state change, backtest interruption, `T_Live`, or AutoTrading action was
performed during verification.

## Review boundary

The deterministic behavior and failure-safe state handling are test-verified.
Production throughput is deliberately **not yet established**: acceptance requires
the 2026-08-02 natural 06:07 run to show bounded chunk records, persisted partial or
complete terminal statuses, no 1,800-second monolithic dispatch, and task exit
within the unchanged outer limit.
