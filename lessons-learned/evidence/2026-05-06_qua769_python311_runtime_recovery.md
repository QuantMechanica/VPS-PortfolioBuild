# QUA-769 Python 3.11 Runtime Recovery Evidence (2026-05-06)

## Incident

- Issue: `QUA-769`
- Severity: `P0` infra outage
- Symptom window: between `2026-05-06 09:45Z` and `2026-05-06 11:40Z`
- Primary failure:
  - `C:\Users\Administrator\AppData\Local\Programs\Python\Python311\Lib` missing
  - runtime crash on startup (`ModuleNotFoundError: No module named 'encodings'`)

## Forensics Snapshot

- Broken install contained only partial binaries/dlls.
- Python launcher registry mapping was corrupted to `C:\Program\python.exe`.
- MSI installer repair/modify flows repeatedly failed (`0x80070643`) on `pip/path` packages.

## Recovery Executed

1. Recovered runtime via official NuGet package (`python/3.11.9`) instead of MSI path.
2. Restored install tree at:
   - `C:\Users\Administrator\AppData\Local\Programs\Python\Python311`
3. Corrected launcher registry:
   - `HKCU\Software\Python\PythonCore\3.11\InstallPath`

## Validation Results

- `python -V` -> `Python 3.11.9`
- `python -c "import encodings, ssl, sqlite3"` -> success
- `python -m pip --version` -> success
- `py -0p` resolved 3.11 to:
  - `C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe`

## Durable Controls Added

- Recovery automation:
  - `infra/scripts/Repair-Python311FromNuget.ps1`
- Runtime health monitor:
  - `infra/monitoring/Test-PythonRuntimeHealth.ps1`
- Infra audit integration:
  - `infra/scripts/Invoke-InfraAudit.ps1` includes `python_runtime_health` check

## Commits

- `052af89` — add idempotent Python 3.11 NuGet recovery script + docs
- `727bfef` — add Python runtime health monitor + infra audit wiring + docs

## Residual Risk / Follow-up

- Suspected root causes remain open:
  - Drive-sync/host file deletion class
  - AV quarantine
  - manual accidental delete
- Follow-up should collect host event evidence for exact deletion actor/time:
  - Windows Event Viewer (`Security`, `System`, Defender operational logs)
  - Google DriveFS client logs around incident window
