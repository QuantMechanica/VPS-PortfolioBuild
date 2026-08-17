<#
Positive-control test for Convert-EAInputValueForSetfile's floating-point handling.

Why this exists: MT5's .set parser truncates exponent notation for double inputs
(`1.0e-10` is read as `1.0e-1`), which silently mis-configures an EA and kills the
run in OnInit.  A generator fix for that is only trustworthy if it is proven to
convert the defect case AND proven to refuse the case it cannot convert exactly --
a detector that cannot fire is not a detector.

Run:  pwsh -File framework/scripts/tests/test_setfile_float_serialization.ps1
Exit: 0 all assertions held, 1 otherwise.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$genPath = Join-Path $PSScriptRoot '..\gen_setfile.ps1'
if (-not (Test-Path -LiteralPath $genPath)) { throw "generator not found: $genPath" }

# Extract the function under test without executing the generator body.
$lines = Get-Content -LiteralPath $genPath
$start = ($lines | Select-String -Pattern '^function Convert-EAInputValueForSetfile\s*\{' |
    Select-Object -First 1).LineNumber
if (-not $start) { throw 'Convert-EAInputValueForSetfile not found in generator' }
$depth = 0
$end = $null
for ($i = $start - 1; $i -lt $lines.Count; $i++) {
    $depth += ([regex]::Matches($lines[$i], '\{')).Count
    $depth -= ([regex]::Matches($lines[$i], '\}')).Count
    if ($depth -le 0 -and $i -gt ($start - 1)) { $end = $i; break }
}
if ($null -eq $end) { throw 'could not delimit the function body' }
Invoke-Expression (($lines[($start - 1)..$end]) -join "`n")

$types = @{
    strategy_reconcile_tolerance = 'double'
    strategy_threshold           = 'double'
    strategy_ratio               = 'float'
    strategy_hold_bars           = 'int'
    strategy_label               = 'string'
    strategy_tf                  = 'ENUM_TIMEFRAMES'
    strategy_tiny                = 'double'
}
$fail = 0
function Assert-Value {
    param([string]$Name, [string]$Value, [string]$Expect, [string]$Why)
    $got = Convert-EAInputValueForSetfile -Name $Name -Value $Value -InputTypes $script:types
    if ($got -ne $Expect) {
        Write-Host ("  FAIL  {0}='{1}' -> '{2}', expected '{3}'  ({4})" -f $Name, $Value, $got, $Expect, $Why)
        $script:fail++
    }
    else {
        Write-Host ("  ok    {0}='{1}' -> '{2}'  ({3})" -f $Name, $Value, $got, $Why)
    }
}
function Assert-Throws {
    param([string]$Name, [string]$Value, [string]$Token, [string]$Why)
    try {
        $got = Convert-EAInputValueForSetfile -Name $Name -Value $Value -InputTypes $script:types
        Write-Host ("  FAIL  {0}='{1}' returned '{2}' but must refuse ({3})" -f $Name, $Value, $got, $Why)
        $script:fail++
    }
    catch {
        if ($_.Exception.Message -notmatch [regex]::Escape($Token)) {
            Write-Host ("  FAIL  {0}='{1}' threw '{2}', expected token {3}" -f $Name, $Value, $_.Exception.Message, $Token)
            $script:fail++
        }
        else {
            Write-Host ("  ok    {0}='{1}' refused with {2}  ({3})" -f $Name, $Value, $Token, $Why)
        }
    }
}

Write-Host 'positive control -- the defect case must be expanded:'
Assert-Value strategy_reconcile_tolerance '1.0e-10' '0.0000000001' 'the value that killed QM5_41033'
Assert-Value strategy_reconcile_tolerance '1e-10'   '0.0000000001' 'no mantissa decimal point'
Assert-Value strategy_threshold           '-3.2E-7' '-0.00000032'  'negative, capital E'
Assert-Value strategy_ratio               '1.5e3'   '1500'         'float type, positive exponent'

Write-Host ''
Write-Host 'regression control -- ordinary values must pass through byte-identical:'
Assert-Value strategy_threshold '0.0000000001' '0.0000000001' 'already decimal'
Assert-Value strategy_threshold '2.5'          '2.5'          'plain double'
Assert-Value strategy_threshold '0'            '0'            'zero'
Assert-Value strategy_threshold '-1.25'        '-1.25'        'negative plain'

Write-Host ''
Write-Host 'other types must be untouched by the new branch:'
Assert-Value strategy_hold_bars '60'         '60'        'int is not reformatted'
Assert-Value strategy_label     '"QM"'       'QM'        'string still unquoted'
Assert-Value strategy_tf        'PERIOD_D1'  '16408'     'timeframe still mapped'

Write-Host ''
Write-Host 'negative control -- the detector must fire when expansion is not exact:'
Assert-Throws strategy_tiny '1e-30' 'SETFILE_FLOAT_EXPANSION_LOSSY' 'below System.Decimal, would flush to 0'
Assert-Throws strategy_tiny '1e40'  'SETFILE_FLOAT_NOT_REPRESENTABLE_IN_DECIMAL' 'above System.Decimal'
Assert-Throws strategy_tiny '1.0e'  'SETFILE_FLOAT_UNPARSEABLE' 'malformed exponent'

Write-Host ''
if ($fail -gt 0) {
    Write-Host ("FAILED: {0} assertion(s)" -f $fail)
    exit 1
}
Write-Host 'PASS: all assertions held'
exit 0
