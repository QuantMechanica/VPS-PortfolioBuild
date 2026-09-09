param([Parameter(Mandatory=$true)][string]$OutputPath)
# Read-only introspection. Load ONLY named function definitions from the canonical
# generator AST; never execute its top-level setfile writer or a source expression.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw 'Evidence output already exists' }
$repoRoot = 'C:\QM\repo'
$generator = Join-Path $repoRoot 'framework\scripts\gen_setfile.ps1'
$parseTokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($generator, [ref]$parseTokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Generator parse error' }
$required = @('Find-CardPath','Parse-CardDefaults','Get-EAInputDefaults','Convert-EAInputValueForSetfile','Normalize-CardDefaultsForSetfile')
foreach ($name in $required) {
    $defs = @($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name}, $true))
    if ($defs.Count -ne 1) { throw "Ambiguous/missing function: $name" }
    Invoke-Expression $defs[0].Extent.Text
}
$cardsRoots = @('strategy-seeds\cards','strategy-seeds\cards\approved','artifacts\cards_approved') | ForEach-Object { Join-Path $repoRoot $_ }
$cardsRoots += 'D:\QM\strategy_farm\artifacts\cards_approved'
$cardsRoots = @($cardsRoots | Where-Object { Test-Path -LiteralPath $_ })
$prior = Get-Content (Join-Path $repoRoot 'docs\ops\evidence\2026-09-09_pattern_filter_repair_final.json') -Raw | ConvertFrom-Json
$cohort = Get-Content (Join-Path $repoRoot 'docs\ops\evidence\2026-09-09_candidates_pattern_balke.json') -Raw | ConvertFrom-Json
$ids = @($prior.programs.measurement_ea_id) + @($cohort.qualified.ea_id) + @('QM5_41398')
$ids = @($ids | Sort-Object -Unique)
$results = @()
foreach ($id in $ids) {
    $folders = @(Get-ChildItem (Join-Path $repoRoot 'framework\EAs') -Directory -Filter "${id}_*")
    if ($folders.Count -ne 1) { $results += @{ea_id=$id;error='EA_FOLDER_NOT_UNIQUE';count=$folders.Count}; continue }
    $folder = $folders[0]
    $inputs = Get-EAInputDefaults -EAFolder $folder.FullName
    $source = Join-Path $folder.FullName ($folder.Name + '.mq5')
    $card = Find-CardPath -CardsRoots $cardsRoots -EaSlug $folder.Name
    $defaults = [ordered]@{}
    if ($card) { $defaults = Normalize-CardDefaultsForSetfile -EaSlug $folder.Name -Defaults (Parse-CardDefaults -CardPath $card) }
    $serialized = [ordered]@{}
    $sourceValues = [ordered]@{}
    $errors = @()
    foreach ($key in $inputs.all.Keys) {
        try { $sourceValues[$key] = Convert-EAInputValueForSetfile -Name $key -Value ([string]$inputs.all[$key]) -InputTypes $inputs.types }
        catch { $errors += "source:${key}:$($_.Exception.Message)" }
    }
    foreach ($key in $defaults.Keys) {
        if (-not $inputs.all.Contains($key)) { continue }
        try { $serialized[$key] = Convert-EAInputValueForSetfile -Name $key -Value ([string]$defaults[$key]) -InputTypes $inputs.types }
        catch { $errors += "card:${key}:$($_.Exception.Message)" }
    }
    $results += [ordered]@{ea_id=$id;ea_label=$folder.Name;source_path=$source;source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLower();input_defaults=$sourceValues;input_types=$inputs.types;card_path=$card;card_sha256=$(if($card){(Get-FileHash -LiteralPath $card -Algorithm SHA256).Hash.ToLower()}else{$null});card_defaults=$serialized;parse_conversion_errors=$errors;historical_card_identity_proven=$false}
}
$result = [ordered]@{schema='qm.pattern-current-card-defaults/v1';created_at_utc=[DateTime]::UtcNow.ToString('o');generator_sha256=(Get-FileHash -LiteralPath $generator -Algorithm SHA256).Hash.ToLower();method='AST named-function introspection only; no generation';limits='Current card/source comparison only; no assertion these card bytes governed historical runs. Direct EA inputs only; include-declared inputs are outside coverage.';ea_count=$results.Count;rows=$results}
$json = $result | ConvertTo-Json -Depth 14
$stream = [System.IO.File]::Open($OutputPath,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write)
try { $writer = [System.IO.StreamWriter]::new($stream,[System.Text.UTF8Encoding]::new($false)); $writer.Write($json); $writer.Flush() } finally { $stream.Dispose() }
Write-Output "Current source/card evidence: $($results.Count) EAs -> $OutputPath"
