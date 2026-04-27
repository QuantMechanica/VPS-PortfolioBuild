# VPS Setup Baseline (Idempotent)

## Scope

This document defines desired state for QuantMechanica V5 infra provisioning on
the Hetzner Windows VPS. Every step is safe to re-run and should converge to the
same state.

## Desired State

1. Windows Server 2022 hardened (RDP port policy, firewall policy, IPBan installed).
2. Repo present at `C:\QM\repo` with clean `.git` ownership and no Drive sync on
   `.git/`.
3. MT5 layout:
   - `D:\QM\mt5\T1` to `D:\QM\mt5\T5` factory terminals
   - each factory terminal root has `portable.txt` marker present (empty file)
   - `D:\QM\mt5\T6_Live` and `D:\QM\mt5\T6_Demo` isolated
4. Seed assets installed:
   - `seed_assets/news_calendar/*.csv` copied to `D:\QM\data\news_calendar\`
   - manifest hashes verified before backtest jobs.
5. Runtime tasks registered with desired-state updater:
   - `QM_PublicSnapshot_Export_Hourly` (HH:07)
   - `QM_DWX_HourlyCheck` (if DWX pipeline exists on host)
   - `QM_InfraHealthCheck_5min`
   - `QM_Backup_Daily_0215`
6. Monitoring outputs written to:
   - `C:\QM\logs\infra\health\`
   - `C:\QM\logs\infra\backup\`

## Re-run Procedure

1. `powershell -File C:\QM\repo\infra\tasks\Register-QMInfraTasks.ps1`
2. `powershell -File C:\QM\repo\infra\backup.ps1 -WhatIf` for dry-run check
3. `powershell -File C:\QM\repo\infra\monitoring\Invoke-InfraHealthCheck.ps1`
4. `powershell -File C:\QM\repo\infra\scripts\Ensure-Mt5PortableMarker.ps1 -FailOnMissingRoot`
5. `powershell -File C:\QM\repo\scripts\export_public_snapshot.ps1 -NoGit`

## Drive/Git Safety Rules (PC1-00)

- Keep `C:\QM\repo\.git\` excluded from Drive sync.
- Use one writer process per repo at commit time (external git mutex).
- Alert on stale `index.lock` files older than 20 minutes.
- Prefer per-agent worktrees for concurrent automation sessions.
