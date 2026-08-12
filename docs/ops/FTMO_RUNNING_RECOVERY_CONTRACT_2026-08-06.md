# FTMO RUNNING recovery contract

Date: 2026-08-06

OWNER ratified the FTMO Global Markets MT5 terminal as `RUNNING` and subject to
the same automatic recovery expectation as DXZ. The bounded review expiry is
`2026-09-30T00:00:00Z`; expiry is fail-closed and never launch permission.

## Exact recovery target

- Executable: `C:/Program Files/FTMO Global Markets MT5 Terminal/terminal64.exe`
- Data directory ID: `81A933A9AFC5DE3C23B15CAB19C63850`
- Account/server: `1514165262` / `FTMO-Demo`
- Profile: `Default`
- Profile contents: AccountMonitor, five attached demo-instrumentation sleeves,
  and one blank XAUUSD/H1 chart.

The attached sleeves are QM5_13301 GER40.cash/M5, QM5_10911 GER40.cash/H1,
QM5_11165 EURUSD/H1, QM5_10706 GBPUSD/H1, and QM5_12969 USDJPY/M30. The saved
QM5_10911 expert mode is disabled and remains pinned that way. The staged
QM5_12989 XAUUSD/H4 sleeve was not present in the saved profile after the host
crash and is not inferred or attached by recovery.

`verify_ftmo_demo_instrumentation_contract.ps1` checks the exact file set,
account/server, chart contracts, preset inputs and hashes, EX5 hashes,
AccountMonitor, and the blank chart. It is read-only. The archived Round25
verifier is no longer called by `FTMO_ON.ps1`.

## Recovery behavior

`FTMO_ON.ps1`, `Live_MT5_SessionSupervisor.ps1`, and `T_Live_Watchdog.ps1`
all bake `expectedFtmoState='RUNNING'` with the same review expiry. The watchdog
also pins `expectedFtmoProfile='Default'`.

An already-running FTMO process is an exit-0 no-op before interactive identity
enforcement. This lets the SYSTEM watchdog verify the launcher path without
creating a duplicate. If FTMO is absent, launch remains restricted to the
`qm-admin` interactive session and must pass the read-only contract verifier.
No script toggles AutoTrading.

The task installer and watchdog recovery-task contract were not changed. The
post-change watchdog observation reported `recovery_task_contract_ready=true`,
so no installer/runtime drift was introduced.
