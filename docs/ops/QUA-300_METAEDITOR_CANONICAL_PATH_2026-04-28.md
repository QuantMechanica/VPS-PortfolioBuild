# QUA-300 MetaEditor Canonical Path Evidence (2026-04-28)

Status: resolved

- Canonical path: `D:\QM\mt5\T1\MetaEditor64.exe`
- Fallback order: `D:\QM\mt5\T1\MetaEditor64.exe`, `D:\QM\mt5\T2\MetaEditor64.exe`
- Discovery timestamp (UTC): `04/28/2026 04:26:25`

Verification

- `Test-Path D:\QM\mt5\T1\MetaEditor64.exe` => `True`
- `Test-Path D:\QM\mt5\T2\MetaEditor64.exe` => `True`
- `where MetaEditor64.exe` => not on `PATH` (expected; explicit absolute path required).
