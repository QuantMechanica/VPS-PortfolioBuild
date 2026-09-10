# QM5_41412 WTI Weekly Alternation Fade — Build and Q02 CPU Stop

Date: 2026-09-10  
Branch: `agents/board-advisor`

## Outcome

`QM5_41412_wti-walt3-fade` is a new, committed low-frequency WTI energy
sleeve. It reconstructs three immediately completed, adjacent broker weeks,
requires strict `+,-,+` or `-,+,-` open-to-close return alternation, and fades
the newest sign for one week. It is the reversal-direction counterpart—not a
parameter copy—of continuation sibling `QM5_41411`.

The approved card, source packet, governed identity and magic, V5 source,
fixed-risk setfile, reference tests, and binary are present. The mandatory
framework-input pin audit returned exit code zero with no
`EA_FRAMEWORK_INPUT_PINNED` finding before compile enqueue.

Governed compile work item `11cf801c-5e01-45b0-a50a-d90270ec153c` completed
`COMPILE_OK`; build-check passed and the binary SHA-256 is
`c2db75155de29e8a80d37c184f61406a3a77b08835d6d8c3b8f8c17f848395a0`.
The deterministic reference suite passed 10/10.

## Q02 Stop

The target-only first-Q02 dry run selected exactly one `XTIUSD.DWX` D1 row
with `RISK_FIXED=1000` and `RISK_PERCENT=0`. The first apply reached SQLite
`BEGIN IMMEDIATE` but returned `database is locked`; no success or mutation is
claimed. After the lock cleared, the idempotence check remained eligible and
showed no Q02 row.

A required fresh five-sample CPU window then measured `96, 96, 91, 94, 99`.
Average was `95.2%` and maximum was `99%`. Because both average and maximum
must be strictly below `97%`, the maximum refused Q02. No second apply,
manual tester dispatch, terminal control, live action, portfolio-gate change,
`T_Live` edit, AutoTrading action, or manifest change occurred.

## Resume Condition

On a later paced wake, repeat the first-Q02 dry run and a fresh five-sample CPU
window. Apply the exact compile-bound intake only if both average and maximum
are strictly below `97%` and no Q02 row already exists.
