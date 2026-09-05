# M09-B package staging and native readiness — REVIEW, incomplete

Task `7cc4ab4c-ae16-4eb7-9409-4ce5ff179d77`, 2026-09-05. The eight exact candidate
binaries and eight immutable trial set files are now staged under the isolated
`D:/QM/mt5/FTMO_STREAM1/MQL5/Experts/QM/M09B` and
`MQL5/Profiles/Presets/M09B` directories. **16/16 destination hashes match the
sealed input manifest. Native readiness remains 0 TESTABLE / 8 UNTESTABLE.**
This is a partial delivery with concrete execution blockers, not task acceptance.

[install_manifest.json](2026-09-05_m09b_native_readiness/install_manifest.json:1)
binds every source, destination and SHA-256 to the immutable manifest
`db442c0095b7a9bbac7cdcbf898036486a6f2e4d3af90f057660fbca3430b94c`.
The staging program checked that the isolated lane was stopped and that Experts
were already disabled; its before/after hashes for common.ini, accounts.dat and
servers.dat are equal. No account, provider, AutoTrading or active factory
terminal was changed. Trial sets retain their declared percentage risk and were
not submitted to a backtest runner; backtests still require fixed risk.

## Measured blockers

The requested governed compilation was attempted with canonical
`farmctl.py enqueue-compile QM_FTMO_TrialTelemetry`. It exited 1 with
`EA_LABEL_INVALID`, zero eligible entries and zero enqueued work items.
The standalone monitor has no accepted EA identity in this queue. An ad hoc
compile beside the running factory is explicitly refused by
`tools/strategy_farm/include_mirror.py:208`; the scheduled cycle forbids stopping
backtests. No invented EA ID, compile claim or guard bypass was used.

The immutable binaries also cannot acquire new instrumentation by changing an
include file. `framework/include/QM/QM_AccountRiskReservation.mqh:131` disables
the reservation contract in the tester and requires an OWNER-bound percentage
risk account. `framework/include/QM/QM_TradeContext.mqh:147` currently wraps
OrderSend but lacks correlated acquire/commit/release telemetry. Adding that
instrumentation requires a separately built and bound binary cohort; it cannot
be represented as evidence from these eight unchanged hashes.

## Scenario table

| Scenario | Native readiness | Remaining dependency |
|---|---|---|
| Reservation activation | UNTESTABLE | Bound event instrumentation and native account activation |
| Simultaneous entries | UNTESTABLE | Shared-account driver and correlated reservation events |
| Pending orders | UNTESTABLE | Native placement/cancel/fill driver and reservation reconciliation |
| Restart | UNTESTABLE | Bound isolated process lifecycle adapter and runtime receipt |
| Disconnect/reconnect | UNTESTABLE | Isolated connection driver and server-state reconciliation |
| Foreign positions | UNTESTABLE | Bound foreign-position driver and whole-account evidence |
| Measurement resolution | UNTESTABLE | Governed compiled collector and measured runtime cadence |
| Intraday trough | UNTESTABLE | Compiled collector, native path and unsampled-loss bounds |

The provider account is not the only dependency. Collector compilation,
reservation instrumentation, the shared-account scenario adapter, and the native
dry run remain undelivered. The current single-EA runner cannot establish this
proof, and this cycle cannot enable AutoTrading or manually launch a terminal.
The existing task remains open for reviewer disposition through REVIEW.

## Verification

[prepare.py](2026-09-05_m09b_native_readiness/prepare.py:1) checks all input hashes
before copying, refuses different destination bytes and exclusive-creates its
receipt. Installation checked all 16 output hashes. Existing telemetry and
account-risk reservation tests passed: **14 passed**. The exact command output
and compile refusal are in
[verification.json](2026-09-05_m09b_native_readiness/verification.json:1).
These are reader/unit checks, not new instrumentation or native scenario tests.
