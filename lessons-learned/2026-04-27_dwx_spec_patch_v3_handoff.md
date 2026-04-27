# 2026-04-27 - DWX spec patch v3 infra handoff (QUA-65)

Issue link: `QUA-65` (`DEVOPS-006`)

## Infra change

- Added idempotent converger:
  - `infra/scripts/Install-DwxSpecPatchRunner.ps1`
- Purpose:
  - Promote known-good startup launcher config from `run_fix_dwx_spec_v2.ini` to `run_fix_dwx_spec_v3.ini` using deterministic token replacement.
  - Keep launcher maintenance in infra scope without editing EA/script source.

## Safety / constraints

- Check-then-act write (only updates target INI on content diff).
- Forces `ShutdownTerminal=1` in target INI.
- Hard guard against T6 path usage (`\T6_` / `\T6\`).
- Requires existing source INI and terminal executable under target root.

## Current operational command (T1 only)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-DwxSpecPatchRunner.ps1 -TerminalRoot D:\QM\mt5\T1 -FromVersion v2 -ToVersion v3
```

Then execute:

```powershell
D:\QM\mt5\T1\terminal64.exe /portable /config:D:\QM\mt5\T1\run_fix_dwx_spec_v3.ini
```

## Execution evidence (T1, 2026-04-27)

- Compile:
  - `D:\QM\mt5\T1\MetaEditor64.exe /compile:D:\QM\mt5\T1\MQL5\Scripts\Fix_DWX_Spec_v3.mq5`
  - Result: `0 errors, 0 warnings` (`Fix_DWX_Spec_v3.compile.log`).
- Runtime launch evidence:
  - `D:\QM\mt5\T1\logs\20260427.log` contains startup config + script load/remove entries for `run_fix_dwx_spec_v3.ini`.
- Script output evidence:
  - `D:\QM\mt5\T1\MQL5\logs\20260427.log` contains:
    - `BATCH|processed=5|sleep_ms=200` (throttling active)
    - intermediate summary during low-liquidity startup windows:
      - `done expected=36 matched=36 patched=15 unchanged=1 failed=20`
      - failure reason: `source_tick_value_zero` on startup before broker tick-values hydrated.
    - final validated summary after retry-window update:
      - `2026-04-27 08:39:01 local: done expected=36 matched=36 patched=0 unchanged=36 failed=0`
- `symbols.custom.dat` integrity checks:
  - Path: `D:\QM\mt5\T1\Bases\symbols.custom.dat`
  - Size remained `20480` bytes through runs.
  - First rerun changed checksum (expected while applying remaining symbol writes), second rerun checksum stable (no further mutation).
  - Final acceptance run checksum remained stable:
    - pre/post SHA256: `49D4BA80F9409AA30977D6777C34F67B325F7581C0878202A79DDDE1F9C90075`
