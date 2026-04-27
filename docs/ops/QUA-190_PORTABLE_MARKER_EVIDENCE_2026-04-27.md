# QUA-190 Portable Marker Evidence (2026-04-27)

## Scope

- Issue: `QUA-190`
- Objective: drop `portable.txt` marker on factory MT5 roots `T1`-`T5`.
- Excluded: `T6` (no touch).

## Command Used

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Drop-PortableMarkers.ps1 -RestartForNonPortableProbe -ProbeWaitSeconds 10
```

## Acceptance Results

1. Marker drop:
   - `D:\QM\mt5\T1\portable.txt` created (0 bytes)
   - `D:\QM\mt5\T2\portable.txt` created (0 bytes)
   - `D:\QM\mt5\T3\portable.txt` created (0 bytes)
   - `D:\QM\mt5\T4\portable.txt` created (0 bytes)
   - `D:\QM\mt5\T5\portable.txt` created (0 bytes)
2. Existence verification:
   - `Test-Path` true for all five marker files.
3. Non-portable restart probe:
   - One controlled restart per terminal from non-`/portable` invocation.
   - Probe status `pass` for `T1`-`T5`.
   - `Bases\Custom` path confirmed present under each factory root.
   - No AppData `origin.txt` writes attributable to factory terminal exe paths during probe window.
4. T6:
   - Out of scope and not modified.

## Evidence Files

- `D:\QM\reports\ops\devops\portable_marker_evidence_20260427_142904.json`
- `D:\QM\reports\ops\devops\portable_marker_evidence_20260427_143227.json`

## Post-Run State

- Factory terminals `T1`-`T5` restored to `/portable` runtime mode after probe.
