# DWX Custom Symbol Import Automation

Created: 2026-04-25
Owner: DevOps + Pipeline-Operator
Reviewer: Quality-Tech

## Goal

Take TDM-exported tick + M1 CSVs and turn them into ready-to-use `.DWX`
custom symbols on T1 with **zero manual typing and no per-symbol waiting**.
Once OWNER has started the long-running pieces, every TDM batch flows
end-to-end on its own.

## Pieces

| Role | Path | Trigger |
|---|---|---|
| Stager (Python) | `D:\QM\mt5\T1\dwx_import\prepare_import.py` | Called by the hourly cron, once per CSV pair |
| Importer (MT5 Service) | `D:\QM\mt5\T1\MQL5\Services\Import_DWX_Queue_Service.ex5` | Drag onto Navigator → Services **once**; runs forever |
| Importer (MT5 Script — manual fallback) | `D:\QM\mt5\T1\MQL5\Scripts\Import_DWX_From_Bin.ex5` | Drag onto a chart for one-shot batch processing |
| Verifier (Python) | `D:\QM\mt5\T1\dwx_import\verify_import.py` | Called by the hourly cron after queue drains |
| Hourly orchestrator | `D:\QM\mt5\T1\dwx_import\dwx_hourly_check.py` | Windows Scheduled Task `QM_DWX_HourlyCheck` |
| Readiness report | `D:\QM\reports\setup\T1_READINESS_REPORT.md` | Written by the orchestrator |

Job-staging area: `D:\QM\mt5\T1\MQL5\Files\imports\` (sidecars + binaries)
Archive: `D:\QM\mt5\T1\MQL5\Files\imports\done\`

## Hourly automation flow

The `QM_DWX_HourlyCheck` Scheduled Task runs `dwx_hourly_check.py` once an
hour. It is **idempotent** — every fire is a no-op until the next thing
becomes possible.

**Phase A — wait for WS30.** The orchestrator gates on WS30 because TDM
imports it last. Both `WS30_GMT+2_US-DST.csv` and `..._M1.csv` must
exist in the staging folder *and* be untouched for at least 30 minutes
(TDM creates the file then fills it, taking up to 30 min). If either is
missing or too fresh, log status and exit. Cron will retry next hour.

**Phase B — stage everything.** Once WS30 is stable, every other
`<SYMBOL>_GMT+2_US-DST.csv` pair is checked and staged via
`prepare_import.py`, skipping ones that are already in MT5, already
queued, already in `done\`, or not yet stable themselves. Stale CSVs
(mtime < 30 min) are deferred to the next hour.

**Phase C — verify and write readiness.** When `imports\` is empty
(meaning the MT5 Service has drained the queue), the orchestrator runs
`verify_import.py` and writes `T1_READINESS_REPORT.md` summarising every
`.DWX` symbol's status. The verdict line is `OVERALL=READY` when all
expected symbols are present, no jobs are pending, the commission file
is populated, and the service heartbeat is fresh.

## Per-symbol stager flow (what `prepare_import.py` does)

1. Parses the symbol root from the filename (`EURUSD_GMT+2_US-DST.csv` → `EURUSD`).
2. Picks target `<root>.DWX` and source `<root>` automatically. Refuses if the broker doesn't have the source.
3. Refuses if the target symbol already exists in MT5 (no clobbering).
4. Refuses if a job for this target is already queued.
5. Validates the tail of each CSV is parseable (truncation/mid-download guard).
6. Streams both CSVs into packed binaries (`.tick.bin` 24 B/tick, `.m1.bin` 48 B/bar) via atomic `.tmp + rename`.
7. Writes a key=value sidecar (`.import.txt`) **last** — that's what the service watches for.

## MT5 Service flow (`Import_DWX_Queue_Service.ex5`)

- Polls `imports\*.import.txt` every 60 s.
- For each new sidecar: refuses to clobber, calls `CustomSymbolCreate(target, group, source)`, patches `tick_value_profit/loss = tick_value`, bulk-loads ticks (500k chunks) via `CustomTicksAdd`, bulk-loads M1 (100k chunks) via `CustomRatesUpdate`, archives sidecar+bins to `imports\done\<timestamp>_*`.
- Writes a heartbeat to `imports\service_heartbeat.txt` every loop so the cron can tell whether it's alive.
- Honours `IsStopped()` cleanly so OWNER can stop the service from the Services panel.

## OWNER setup checklist (one-time)

1. **Start the MT5 Service.** Open T1 portable (the desktop shortcut), Navigator (Ctrl+N) → Services → drag `Import_DWX_Queue_Service` onto the Services pane. Right-click → Start. The service icon should turn green.  
   *If you ever close MT5: when you reopen it via the desktop shortcut, the service auto-resumes.*
2. The Scheduled Task `QM_DWX_HourlyCheck` is already registered. It runs hourly under `Administrator`, fires only when the user is logged in, and is logged to `D:\QM\mt5\T1\dwx_import\logs\hourly_<date>.log`.
3. Continue downloading via TDM normally. Once WS30 is fully filled and idle for 30 min, the cron's next hourly fire kicks off the rest of the pipeline.

## Status at a glance

- Latest cron log: `D:\QM\mt5\T1\dwx_import\logs\hourly_<YYYY-MM-DD>.log`
- Live readiness verdict: `D:\QM\reports\setup\T1_READINESS_REPORT.md`
- Service heartbeat: `D:\QM\mt5\T1\MQL5\Files\imports\service_heartbeat.txt`

## Manual operations

- **Trigger the cron now:** `Start-ScheduledTask -TaskName "QM_DWX_HourlyCheck"` (PowerShell).
- **Stage one symbol manually (bypass cron):** `python D:\QM\mt5\T1\dwx_import\prepare_import.py D:\QM\reports\setup\tick-data-timezone\<SYMBOL>_GMT+2_US-DST.csv`.
- **Manual import without the service:** drag `Scripts\Import_DWX_From_Bin` onto any chart — it processes the queue once and exits.
- **Verify only:** `python D:\QM\mt5\T1\dwx_import\verify_import.py`.

## Limitations

- TDM's filename pattern `<SYMBOL>_GMT[+-]<N>_(EU|US)-DST(_M1)?.csv` is hard-coded; other CSV layouts need `--target` / `--source` overrides.
- The MT5 Service requires the T1 terminal to be running. If T1 is closed, queued jobs sit until OWNER reopens it.
- The Service uses `Custom\…` mirror commission rules already in `MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt` (rows 36–70). Symbols outside the broker's Forex/Indices/Commodities/Stocks/ETFs/Futures categories would need extra rules.
- T2–T5 are populated by copying `D:\QM\mt5\T1\Bases\Custom\` and the tester groups file — *not* by re-running this importer.

## Source attribution

- TDM defaults: `GMT+2`, DST = US. Source: OWNER, screenshot Capture1 (Trade Settings → Commissions, broker side). Verified to match Darwinex's NY-Close server-time convention 2026-04-25.
- DWX target naming convention: `<root>.DWX` for every TDM-imported symbol. Source: OWNER instruction 2026-04-25.
- WS30 chosen as the readiness sentinel. Source: OWNER instruction 2026-04-25 — it is the last symbol queued to TDM in this batch.
