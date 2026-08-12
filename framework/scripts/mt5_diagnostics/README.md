# MT5 Diagnostic & Recovery Scripts

MQL5 scripts for specific MT5-side incidents. Drag onto a chart in the
affected terminal; read the Experts log.

## `QM_Recover_DWX_Symbols.mq5`

Re-creates the custom DWX symbols after an unclean VPS reboot wipes
`symbols.custom.dat`. The `.tkc` / `.hcc` cache survives the reboot and
re-attaches automatically when the symbol is re-created with the same
name. Origin: 2026-05-22 incident.

- `InpTestOnly = true`  -> EURUSD.DWX only (safe probe).
- `InpTestOnly = false` -> all 40 symbols.

After running, **close the terminal cleanly** (File -> Exit) so the
re-registered definitions persist to `symbols.custom.dat`.

## `QM_Probe_NewsFile.mq5`

Probes `FileOpen` for the news calendar CSV across sandbox / COMMON /
absolute / colon-stripped variants. Reports which path MT5 actually
opens. Diagnosed the 2026-05-23 news-init failure (MT5 5833 rejects
absolute paths with err 5002).

Companion fix:
- News CSVs deployed to `<Common>\Files\`.
- Framework patch in `QM_NewsReadFileBytes` (commit `3a7a2207`) - basename
  + `FILE_COMMON` fallback after the absolute path is refused.

## `QM_Dump_DWX_TickValue.mq5`

Verification-only H5/P1.8 diagnostic for the seven non-FX custom symbols:
`NDX.DWX`, `WS30.DWX`, `SP500.DWX`, `GDAXI.DWX`, `XAUUSD.DWX`,
`XTIUSD.DWX`, and `XNGUSD.DWX`.

The script records native tick metadata and account currency, calls the actual
`QM_RiskSizerReadSymbolSnapshot` and `QM_LotsForRiskFromSnapshot` functions,
and compares their result with four independent one-lot `OrderCalcProfit`
probes. It has no order-send or position-management path. It writes only:

- `<Common>\Files\QM\state\dwx_tickvalue_dump_staging.csv`
- `<Common>\Files\QM\state\dwx_tickvalue_dump_complete.marker`

Do not drag this script onto a chart and do not use a factory or live terminal.
The sole launcher is `run_dwx_tickvalue_dump.ps1`, which is permanently bound
to `D:\QM\mt5\T_Export`. The runner requires an `IN_PROGRESS` Codex
`ops_issue` in the agent-task database with this payload contract:

```json
{
  "operation": "framework_h5_dwx_tickvalue_verify",
  "terminal": "T_Export",
  "allow_terminal_launch": true,
  "verify_only": true,
  "sizing_changes": false
}
```

After the task is routed to Codex, run:

```powershell
pwsh -File framework\scripts\mt5_diagnostics\run_dwx_tickvalue_dump.ps1 `
  -AgentTaskId <task-guid>
```

The runner fails closed if `T_Export` is active, if any executable or deployment
path resolves outside that terminal, or if an evidence file already exists. It
compiles an isolated copy of the source and current `QM_RiskSizer.mqh`, launches
the script through a minimal `[StartUp]` INI with `ShutdownTerminal=1`, validates
the exact 67-column schema and seven-symbol row set, and checks that the source
and RiskSizer hashes did not change. It never changes terminal trading settings.

Validated evidence is published atomically to:

- `D:\QM\reports\state\dwx_tickvalue_dump_<yyyy-MM-dd>.csv`
- `D:\QM\reports\state\dwx_tickvalue_dump_<yyyy-MM-dd>.json`
- `D:\QM\reports\state\dwx_tickvalue_dump_<yyyy-MM-dd>_compile.log`
- `D:\QM\reports\state\dwx_tickvalue_dump_<yyyy-MM-dd>_terminal.log`

An `UNRESOLVED` row is still published for diagnosis, but the runner exits with
failure. A sizing divergence is evidence only; this diagnostic never patches
`QM_RiskSizer.mqh`.

## Compile

This legacy manual compile recipe applies to the recovery/probe scripts above,
not to `QM_Dump_DWX_TickValue.mq5`, which must use its guarded runner.

```
& "D:\QM\mt5\T1\MetaEditor64.exe" /compile:"<script>.mq5"
```

Then copy the `.ex5` into every terminal's `MQL5\Scripts\` (or just T1
for a one-terminal probe).
