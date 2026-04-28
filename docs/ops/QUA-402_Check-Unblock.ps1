param(
  [string]$RegistryPath = "C:\QM\worktrees\development\framework\registry\ea_id_registry.csv"
)

if(-not (Test-Path -LiteralPath $RegistryPath)) {
  Write-Output "BLOCKED: registry file not found -> $RegistryPath"
  exit 2
}

$rows = Get-Content -LiteralPath $RegistryPath | Select-String -Pattern "SRC04_S03,lien-fade-double-zeros|lien-fade-double-zeros,SRC04_S03"
if($rows.Count -gt 0) {
  Write-Output "READY: SRC04_S03 allocation present"
  $rows | ForEach-Object { Write-Output $_.Line }
  exit 0
}

Write-Output "BLOCKED: SRC04_S03 allocation missing"
exit 1
