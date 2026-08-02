# Mailbox-Intake Chunk-Tuning Evidence (DRAFT)

Date: 2026-08-02  
Branch: `agents/board-advisor`  
Scope: implementation and local verification only; no commit

## Rationale

The ticket's 2026-08-02 06:07Z run evidence records six ten-lead analyst
chunks, all reaching the 360-second timeout. Only 18 of 58 leads reached a
terminal status and 40 remained retryable. With observed progress of roughly
two to five leads per 360 seconds, five-lead chunks and a 600-second ceiling
give each dispatched unit a realistic opportunity to finish and checkpoint.

## Changes

- `tools/strategy_farm/mailbox_source_intake.py:115-118`
  - Default analyst chunk size: `10` -> `5` leads.
  - Default per-chunk timeout: `360` -> `600` seconds.
  - Both values are import-time environment overrides using the names
    `ANALYST_CHUNK_SIZE` and `ANALYST_CHUNK_TIMEOUT_SECONDS`; when the variables
    are absent, the new defaults apply.
- `tools/strategy_farm/tests/test_mailbox_source_intake.py:360-373`
  - Added a focused test that loads the module with both variables absent and
    asserts defaults `5` / `600`, then loads it with overrides `7` / `900` and
    asserts the override path.
- `tools/strategy_farm/tests/test_mailbox_source_intake.py:376-423`
  - Updated default chunking and sequential-checkpoint expectations from
    ten-lead chunks to five-lead chunks.
- `tools/strategy_farm/tests/test_mailbox_source_intake.py:426-460`
  - Updated the existing early-stop test for five-lead chunks; it still proves
    that one admitted chunk completes and later chunks remain retryable when the
    next full chunk plus shutdown grace no longer fits.

The pre-change branch defined the two analyst settings as plain numeric
constants. The environment-variable reads use those exact existing constant
names, as required by the ticket; no setting was renamed.

## Run-budget arithmetic and guard review

The outer run budget and scheduler safety settings are unchanged at
`tools/strategy_farm/mailbox_source_intake.py:119-123`:

- `RUN_BUDGET_SECONDS = 40 * 60 = 2,400` seconds.
- `SHUTDOWN_GRACE_SECONDS = 2 * 60 = 120` seconds.
- Task Scheduler kill: 45 minutes = 2,700 seconds.
- Console-session bridge wait: 44 minutes = 2,640 seconds.

The between-chunk admission guard remains at
`tools/strategy_farm/mailbox_source_intake.py:583-600`. With the new timeout it
requires:

```text
required_seconds = 600 + 120 = 720 seconds
```

before it dispatches another chunk. Therefore:

- A newly admitted analyst can use its entire 600-second timeout and still
  reach the timeout point with at least 120 seconds left in the 2,400-second
  run budget. The latest full-timeout point is at minute 38; the remaining two
  minutes are reserved for termination and reconciliation.
- The run-budget boundary is five minutes earlier than the 45-minute Task
  Scheduler kill and four minutes earlier than the 44-minute bridge wait.
- Sweep time is counted because `run_started` is recorded before the sweep. Any
  sweep or reconciliation overhead reduces the time available for another
  chunk, and the guard stops before dispatch rather than interrupting a chunk
  because of the outer budget.

Four five-lead chunks represent a nominal capacity of about 20 leads per run.
The four timeout ceilings total exactly `4 * 600 = 2,400` seconds, so four
full-duration chunks plus sweep overhead cannot fit in a 2,400-second budget.
The retained conservative guard admits a fourth chunk only when the sweep,
earlier chunks, and reconciliation have collectively used no more than 1,680
seconds. If the first three chunks each consume their full 600-second timeout,
the run stops cleanly before chunk four with 600 seconds left. Thus the safe
worst case is three chunks (15 leads), while approximately 20 leads is possible
when earlier chunks complete below their timeout ceilings. No budget-guard
change was needed or made.

## Verification

Command:

```text
python -m pytest tools/strategy_farm/tests/test_mailbox_source_intake.py
```

Verbatim result:

```text
============================= test session starts =============================
platform win32 -- Python 3.11.9, pytest-9.1.1, pluggy-1.6.0
rootdir: C:\QM\repo
collected 24 items

tools\strategy_farm\tests\test_mailbox_source_intake.py ................ [ 66%]
........                                                                 [100%]

============================= 24 passed in 0.54s ==============================
```

Command:

```text
python -m py_compile tools/strategy_farm/mailbox_source_intake.py
```

Verbatim result: no stdout or stderr; exit code `0`.
