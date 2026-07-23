# QUA-376 Owner Completion Checklist — 2026-04-28

Purpose: close the remaining dependency for `SRC05_S01` execution (`QM5_SRC05_S01` binary + active registry row).

## Unblock Owner

- `CTO/Dev`

## Required Deliverables

1. Deploy compiled expert binary to factory terminals:
- `D:\QM\mt5\T1\MQL5\Experts\QM\QM5_SRC05_S01_chan_at_bb_pair.ex5`
- same path on `T2`..`T5`

2. Add/activate magic registry row in:
- `framework/registry/magic_numbers.csv`

3. Confirm proxy-pair mapping encoded in queue config digest:
- `XAUUSD.DWX` (gold proxy)
- `XTIUSD.DWX` (oil proxy)

## Verification Commands (deterministic)

1. Binary presence on all terminals:
```powershell
$terms='T1','T2','T3','T4','T5';
$terms | ForEach-Object {
  $p = "D:\\QM\\mt5\\$_\\MQL5\\Experts\\QM\\QM5_SRC05_S01_chan_at_bb_pair.ex5";
  [pscustomobject]@{ terminal=$_; exists=(Test-Path -LiteralPath $p); path=$p }
} | Format-Table -AutoSize
```

2. Active registry row check:
```powershell
Import-Csv framework\registry\magic_numbers.csv |
  Where-Object { $_.ea_slug -like '*src05*' -or $_.ea_id -like '*SRC05*' -or $_.status -eq 'active' } |
  Format-Table -AutoSize
```

3. Proxy pair readiness (must remain ready):
```powershell
.\infra\scripts\Invoke-QUA376ProxyPairReadiness.ps1
Get-Content artifacts\qua-376\proxy_pair_readiness.json -Raw
```

4. First queue run (nonce-safe):
```powershell
.\infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1 `
  -EAId <SRC05_S01_EAID> -Version v1 -Symbol XAUUSD.DWX -Phase P3.5 `
  -SubGateConfig "src05_s01:pair_proxy=xauusd.dwx-xtiusd.dwx:lookback20:entry1:exit0:<nonce>" `
  -Terminal T2 -Year 2024 -Expert "QM/QM5_SRC05_S01_chan_at_bb_pair" -Period H1 `
  -Runs 2 -MinTrades 1 -TimeoutSeconds 600 -AllowMissingRealTicksLogMarker
```

## Acceptance Criteria

- Binary exists on T1-T5.
- Registry row active for SRC05_S01.
- `proxy_pair_readiness.json` reports `readiness=ready`.
- First queue run writes evidence chain under:
  - `D:\QM\reports\factory_runs\<ea_id>\<version>\<phase>\<symbol>\<run_key>\`
- Queue lifecycle evidence present: `enqueue -> claim -> running -> ack(final)`.

## Resume Signal

After completion, resume this issue using the blocked transition package with `resume=true`:
- `docs/ops/QUA-376_ISSUE_STATUS_UPDATE_2026-04-28.json`
