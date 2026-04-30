param(
    [string]$RepoRoot = 'C:\QM\repo'
)

$cardPath = Join-Path $RepoRoot 'strategy-seeds\cards\lien-fade-double-zeros_card.md'
$sourcePath = Join-Path $RepoRoot 'strategy-seeds\sources\SRC04\raw\ch08-12_technical.txt'
$proposalPath = Join-Path $RepoRoot 'artifacts\qua-342\src04_s03_cto_payload_proposal_2026-04-28T085344Z.json'

$cardExists = Test-Path -LiteralPath $cardPath
$sourceExists = Test-Path -LiteralPath $sourcePath
$proposalExists = Test-Path -LiteralPath $proposalPath

$payloadReady = $false
$missingPayloadFields = @()

if ($proposalExists) {
    $proposal = Get-Content -LiteralPath $proposalPath -Raw | ConvertFrom-Json
    $p = $proposal.proposed_payload
    if (-not $p.ea_name -or $p.ea_name -eq '<CTO_FILL_REQUIRED>') { $missingPayloadFields += 'ea_name' }
    if (-not $p.setfile_path -or $p.setfile_path -eq '<CTO_FILL_REQUIRED>') { $missingPayloadFields += 'setfile_path' }
    if (-not $p.symbols -or $p.symbols.Count -eq 0) { $missingPayloadFields += 'symbols' }
    if (-not $p.from) { $missingPayloadFields += 'from' }
    if (-not $p.to) { $missingPayloadFields += 'to' }
    $payloadReady = ($missingPayloadFields.Count -eq 0)
}

$dispatchReady = $cardExists -and $sourceExists -and $payloadReady

$missingArtifacts = @()
if (-not $cardExists) { $missingArtifacts += 'strategy card' }
if (-not $sourceExists) { $missingArtifacts += 'SRC04 raw source' }

$unblockAction = ''
if ($dispatchReady) {
    $unblockAction = 'None (dispatch-ready)'
} elseif ($missingArtifacts.Count -gt 0 -and $missingPayloadFields.Count -gt 0) {
    $unblockAction = ('Provide missing artifacts ({0}) and fill payload fields ({1})' -f ($missingArtifacts -join ', '), ($missingPayloadFields -join ', '))
} elseif ($missingArtifacts.Count -gt 0) {
    $unblockAction = ('Provide missing artifacts ({0})' -f ($missingArtifacts -join ', '))
} else {
    $unblockAction = ('Assign executable mapping fields in payload ({0}) and set strategy EA ID from TBD to concrete mapping' -f ($missingPayloadFields -join ', '))
}

$result = [pscustomobject]@{
    issue = 'QUA-342'
    checked_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    required_artifacts = [pscustomobject]@{
        card_path = $cardPath
        card_exists = $cardExists
        source_path = $sourcePath
        source_exists = $sourceExists
        cto_payload_path = $proposalPath
        cto_payload_exists = $proposalExists
    }
    payload_readiness = [pscustomobject]@{
        payload_ready = $payloadReady
        missing_fields = $missingPayloadFields
    }
    dispatch_ready = $dispatchReady
    unblock_owner = 'CTO'
    unblock_action = $unblockAction
}

$outDir = Join-Path $RepoRoot 'artifacts\qua-342'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outPath = Join-Path $outDir 'src04_s03_readiness_latest.json'
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath

Write-Output "readiness.output=$outPath"
Write-Output (Get-Content -LiteralPath $outPath -Raw)
