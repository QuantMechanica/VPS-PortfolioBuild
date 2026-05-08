# QUA-662 serialized recovery step — 2026-05-05T19:20+02:00

## Actions this heartbeat

1. Ran one-symbol recovery for `EURUSD.DWX` on `T2`.
- Result: `INVALID no_summary_json:rc=1` with terminal contention stderr (`Terminal instance is already running`).

2. Re-checked completion criteria:
- `report.csv` reached 36+ total lines, but canonical coverage was only `21/36`; therefore not done.

3. Continued with next unresolved canonical symbol `GBPCAD.DWX` on `T3`.
- Invocation returned without symbol row emission.
- Reconciled manually with:
  - `1003,P2,GBPCAD.DWX,T3,INVALID,no_summary_json:rc=1,D:\QM\reports\pipeline\QM5_1003\P2\QM5_1003\20260505_172012`

## Coverage delta

- After reconciliation:
  - `report.csv` line count: `43`
  - canonical coverage: `22/36`
  - remaining canonical symbols: `14`

## Next action

- Continue serialized unresolved-symbol loop with the same reconcile guard until canonical coverage is `36/36`.
