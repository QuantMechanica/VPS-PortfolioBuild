# MT5 Tester `bar*.tmp` Watchdog

Purpose: detect and contain MT5 tester temp-file growth (`bar*.tmp`) that can consume disk during BL runs.

Script: `Company/scripts/infra/mt5_tester_bar_tmp_watchdog.ps1`

## What It Does

- Scans `MetaQuotes\Tester\<terminal-id>\Agent-*\...\bar*.tmp`.
- Computes total temp-file footprint and optional growth rate vs previous run.
- Emits machine-readable JSON for alerts/gates.
- Optional containment mode deletes stale `bar*.tmp` files only.

Defaults:
- Warn threshold: `2 GB`
- Critical threshold: `5 GB`
- Growth warn: `0.75 GB / 5m`
- Growth critical: `1.5 GB / 5m`
- Containment mode: `none`

State file (for growth deltas):
- `Company/scripts/infra/mt5_tester_bar_tmp_watchdog_state.json`

## Safety Rules

- Default mode is read-only.
- Containment deletes only files that match `bar*.tmp`.
- Deletion candidates must stay under the configured tester root.
- By default, containment skips when `terminal64` or `metatester64` is still running.
- To override the running-process guard, pass `-AllowContainmentWithTesterRunning`.

## Usage

One-shot audit:

```powershell
powershell -ExecutionPolicy Bypass -File Company/scripts/infra/mt5_tester_bar_tmp_watchdog.ps1
```

Audit only selected terminals:

```powershell
powershell -ExecutionPolicy Bypass -File Company/scripts/infra/mt5_tester_bar_tmp_watchdog.ps1 `
  -TerminalIds 35E1BC295E58086216981F2888C37961,D0E73AF0F17162F32C13B3D22CCF0323
```

Containment (delete stale `bar*.tmp` older than 15 minutes):

```powershell
powershell -ExecutionPolicy Bypass -File Company/scripts/infra/mt5_tester_bar_tmp_watchdog.ps1 `
  -ContainmentMode delete_stale_tmp `
  -ContainmentMinAgeMinutes 15
```

## JSON Output Fields

- `severity_before_containment`, `severity_after_containment`
- `scan_before` / `scan_after` (`file_count`, `total_bytes`, `total_gb`)
- `growth` (`delta_bytes`, `delta_gb_per_5m`)
- `containment` (`candidate_file_count`, `deleted_file_count`, `deleted_bytes`, `skipped_reason`)
- `per_terminal` with top agent contributors
- `largest_files` for rapid triage
