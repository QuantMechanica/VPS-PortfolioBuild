$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

function Assert-ThrowsMatch([scriptblock]$Action, [string]$Pattern, [string]$Message) {
    try {
        & $Action
    } catch {
        Assert-True ($_.Exception.Message -match $Pattern) `
            ("$Message; unexpected error: " + $_.Exception.Message)
        return
    }
    throw "ASSERT FAILED: $Message; no exception was raised"
}

function Get-TestFileSha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

$strategyFarm = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $strategyFarm 'factory_restore_intent.py'
$factoryOff = Join-Path $strategyFarm 'Factory_OFF.ps1'
$factoryOn = Join-Path $strategyFarm 'Factory_ON.ps1'
$taskManifest = Join-Path $strategyFarm 'qm_tasks.manifest.ps1'
$python = (Get-Command python -ErrorAction Stop).Source
foreach ($scriptPath in @($factoryOff,$factoryOn,$taskManifest)) {
    $parseTokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$parseTokens,
        [ref]$parseErrors
    ) | Out-Null
    Assert-True (@($parseErrors).Count -eq 0) `
        ("PowerShell parse failed for ${scriptPath}: " + (@($parseErrors) -join '; '))
}
$source = Get-Content -LiteralPath $factoryOff -Raw
$match = [regex]::Match($source, '(?s)\$QM_QUIESCENCE_TASKS\s*=\s*@\((.*?)\r?\n\)')
Assert-True $match.Success 'QM_QUIESCENCE_TASKS must be present'
$tasks = @([regex]::Matches($match.Groups[1].Value, "'([^']+)'") |
    ForEach-Object { $_.Groups[1].Value })
Assert-True ($tasks.Count -gt 0) 'task set must not be empty'

# Load only the validation function AST from Factory_ON; never execute the
# Factory_ON script body or any scheduler/process operation.
$onTokens = $null
$onErrors = $null
$onAst = [Management.Automation.Language.Parser]::ParseFile(
    $factoryOn,
    [ref]$onTokens,
    [ref]$onErrors
)
$validatorFunctionAst = $onAst.Find({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'ConvertTo-ExactTaskEnabledState'
}, $true)
Assert-True ($null -ne $validatorFunctionAst) 'Factory_ON exact-state validator function missing'
. ([scriptblock]::Create($validatorFunctionAst.Extent.Text))

$validStateMap = [ordered]@{}
foreach ($task in $tasks) { $validStateMap[$task] = $true }
$validState = [pscustomobject]$validStateMap
$normalized = ConvertTo-ExactTaskEnabledState -State $validState `
    -ExpectedTasks $tasks -SourceLabel 'PS test'
Assert-True ($normalized.Count -eq $tasks.Count) 'valid exact task state was not preserved'

$missingMap = [ordered]@{}
foreach ($task in ($tasks | Select-Object -Skip 1)) { $missingMap[$task] = $true }
Assert-ThrowsMatch {
    ConvertTo-ExactTaskEnabledState -State ([pscustomobject]$missingMap) `
        -ExpectedTasks $tasks -SourceLabel 'PS missing test' | Out-Null
} 'key-set mismatch.*missing=' 'missing task key must fail closed'

$extraMap = [ordered]@{}
foreach ($task in $tasks) { $extraMap[$task] = $true }
$extraMap['QM_NOT_IN_CONTRACT'] = $false
Assert-ThrowsMatch {
    ConvertTo-ExactTaskEnabledState -State ([pscustomobject]$extraMap) `
        -ExpectedTasks $tasks -SourceLabel 'PS extra test' | Out-Null
} 'key-set mismatch.*extra=' 'extra task key must fail closed'

$stringMap = [ordered]@{}
foreach ($task in $tasks) { $stringMap[$task] = $true }
$stringMap[$tasks[0]] = 'false'
Assert-ThrowsMatch {
    ConvertTo-ExactTaskEnabledState -State ([pscustomobject]$stringMap) `
        -ExpectedTasks $tasks -SourceLabel 'PS string test' | Out-Null
} 'explicit boolean' 'string task state must fail closed'

$nullMap = [ordered]@{}
foreach ($task in $tasks) { $nullMap[$task] = $true }
$nullMap[$tasks[0]] = $null
Assert-ThrowsMatch {
    ConvertTo-ExactTaskEnabledState -State ([pscustomobject]$nullMap) `
        -ExpectedTasks $tasks -SourceLabel 'PS null test' | Out-Null
} 'explicit boolean' 'null task state must fail closed'

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("qm-mnt052-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $flag = Join-Path $tempRoot 'FACTORY_OFF.flag'
    Set-Content -LiteralPath $flag -Encoding UTF8 `
        -Value '{"off_at":"2026-07-29T07:27:38Z","codex_parallel_before":"0"}'
    $flagSha = Get-TestFileSha256 -Path $flag
    $taskState = [ordered]@{}
    for ($index = 0; $index -lt $tasks.Count; $index++) {
        $taskState[$tasks[$index]] = [bool](($index % 2) -eq 0)
    }
    $manifest = [ordered]@{
        schema_version = 'qm.factory-restore-intent/v1'
        manifest_id = 'OWNER-PS-TEST-01'
        legacy_off_flag = [ordered]@{ path=$flag; sha256=$flagSha }
        owner_authorization = [ordered]@{
            authority = 'OWNER'
            authorized_by = 'powershell-test-owner'
            authorized_at_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
            decision = 'RESTORE_EXACT_PRE_OFF_TASK_INTENT'
            decision_ref = 'OWNER-PS-TEST-DECISION-01'
            scope = 'QM_QUIESCENCE_TASKS_RESTORE_INTENT'
        }
        task_enabled_before = $taskState
    }
    $manifestPath = Join-Path $tempRoot 'manifest.json'
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $args = @($validator,'validate','--manifest',$manifestPath,'--legacy-flag',$flag)
    foreach ($task in $tasks) { $args += @('--expected-task',$task) }
    $output = @(& $python @args 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) ("valid manifest rejected: " + ($output -join "`n"))
    $recordPrefix = 'QM_FACTORY_RESTORE_INTENT_V1:'
    $records = @($output | ForEach-Object { [string]$_ } | Where-Object {
        $_.StartsWith($recordPrefix, [System.StringComparison]::Ordinal)
    })
    Assert-True ($records.Count -eq 1) 'validator did not emit exactly one framed record'
    $result = $records[0].Substring($recordPrefix.Length) | ConvertFrom-Json
    Assert-True ($result.validated -eq $true) 'validator attestation missing'
    Assert-True ($result.legacy_flag_sha256 -eq $flagSha) 'legacy flag hash not bound'

    $before = Get-TestFileSha256 -Path $flag
    $manifest.task_enabled_before.Remove($tasks[0])
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $ErrorActionPreference = 'Continue'
    $badOutput = @(& $python @args 2>&1)
    $ErrorActionPreference = 'Stop'
    Assert-True ($LASTEXITCODE -ne 0) 'missing task key was accepted'
    Assert-True (($badOutput -join "`n") -match 'key-set mismatch') 'missing-key reason absent'
    Assert-True ((Get-TestFileSha256 -Path $flag) -eq $before) `
        'validator changed the legacy flag'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'Factory restore-intent tests passed'
