# QM5_4006 Q02 History-Sync Reroute

## Scope

- EA: `QM5_4006_fx-session-flow`
- Instrument: `EURUSD.DWX`, M15
- Failed Q02 work item: `1ec70bea-9ff7-4186-beb5-81b11ade0de1`
- Re-enqueued existing Q02 work item: `41353941-8f90-4969-8cd7-d22f2c23e995`

## Diagnosis

The failed row was claimed in the farm DB before diagnosis. Its worker log shows
successful EX5 deployment and terminal launch on T6, followed by an empty report.
The T6 tester log records `EURUSD.DWX: history synchronization error` before EA
initialization. Other EURUSD EAs failed at the same boundary on the same terminal,
so this is terminal history infrastructure rather than a strategy verdict.

Stale build deployment was ruled out: the repository and deployed T6 EX5 SHA-256
were both `0FCAF685A4AC225F29F60F8FB629F5102899357EFE045DB1F1C22916A202AE17` before
the repair. `cache_audit.py --ea QM5_4006` confirms EURUSD M15 source history from
2017 through 2026 and warm tester caches on T1 and T4.

## Repair and queue action

The EA was rebuilt with `compile_one.ps1 -Strict`: PASS, zero errors and zero
warnings. The already-pending Q02 row was enriched atomically instead of creating
a duplicate. It is priority-tracked, avoids the two terminals from the repeated
failed attempts (`T2`, `T6`), and preserves the canonical `RISK_FIXED` backtest
setfile. The diagnostic claim on the failed source row was then released.

No local backtest was launched because the fleet queue owns Q02 execution. No
portfolio gate, T_Live path, deploy manifest, or AutoTrading state was touched.
