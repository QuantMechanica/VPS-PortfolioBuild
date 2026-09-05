$ErrorActionPreference='Stop'
$EALabel=$null
$script:found=New-Object 'System.Collections.Generic.List[string]'
function Add-Failure {param([string]$Message) if($Message.StartsWith('EA_ML_FORBIDDEN:')){$script:found.Add($Message)}}
function Add-Warning {param([string]$Message)}
function Invoke-ForbiddenScan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedRepoRoot
    )

    $scanRoots = @(
        (Join-Path $ResolvedRepoRoot "framework\include"),
        (Join-Path $ResolvedRepoRoot "framework\templates"),
        (Join-Path $ResolvedRepoRoot "framework\tests"),
        (Join-Path $ResolvedRepoRoot "framework\EAs")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    if ($EALabel) {
        $targetEaRoot = Join-Path $ResolvedRepoRoot "framework\EAs\$EALabel"
        $scanRoots = @(
            (Join-Path $ResolvedRepoRoot "framework\include"),
            $targetEaRoot
        ) | Where-Object { Test-Path -LiteralPath $_ }
    }

    $mqlFiles = New-Object System.Collections.Generic.List[string]
    foreach ($scanRoot in $scanRoots) {
        $files = Get-ChildItem -LiteralPath $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @(".mq5", ".mqh") }
        foreach ($f in $files) {
            $mqlFiles.Add($f.FullName)
        }
    }

    if ($mqlFiles.Count -eq 0) {
        Add-Warning "BUILD_CHECK_FORBIDDEN_SCAN_EMPTY: no framework MQL files found."
        return
    }

    $mlIncludePattern = '(?im)^\s*#(?:include|import|resource)\s*[<"][^>"\r\n]*(?:tensorflow|torch|pytorch|sklearn|keras|onnx|xgboost|lightgbm|catboost|mlpack|dlib|neural|perceptron|\bML[/\\.])[^>"\r\n]*[>"]'
    $mlLearningPattern = '(?i)\b(?:Onnx\w+|Backpropagate|Backpropagation|TrainModel|FitModel|UpdateWeights|LearnOnline)\s*\(|\b(?:weights|biases?|coefficients)\s*\[[^\]]+\]\s*(?:[+-]=|=(?!=))\s*[^;]*(?:learning_?rate|gradient|loss|error|target|reward)\b'
    $externalPattern = '(?i)\bWebRequest\s*\(|https?://'

    foreach ($mqlFile in $mqlFiles) {
        $rawMl = Get-Content -LiteralPath $mqlFile -Raw
        # Preserve line positions; prose and string examples cannot be learning code.
        $commentFree = [regex]::Replace($rawMl, '(?s)/\*.*?\*/|(?m)//[^\r\n]*', {
            param($m) [regex]::Replace($m.Value, '[^\r\n]', ' ')
        })
        $codeMl = [regex]::Replace($commentFree, '"(?:\\.|[^"\\])*"', {
            param($m) [regex]::Replace($m.Value, '[^\r\n]', ' ')
        })
        $mlHits = @([regex]::Matches($commentFree, $mlIncludePattern)) + @([regex]::Matches($codeMl, $mlLearningPattern))
        foreach ($hit in $mlHits) {
            $lineNumber = 1 + ([regex]::Matches($commentFree.Substring(0, $hit.Index), "`n")).Count
            Add-Failure "EA_ML_FORBIDDEN: ${mqlFile}:$lineNumber contains a model include or learning operation '$($hit.Value.Trim())'."
        }
    }

    $externalHits = Select-String -Path $mqlFiles.ToArray() -Pattern $externalPattern
    foreach ($hit in $externalHits) {
        Add-Failure "BUILD_CHECK_EXTERNAL_DATA_API_FORBIDDEN: $($hit.Path):$($hit.LineNumber) contains '$($hit.Matches[0].Value)'. Darwinex MT5 native data only."
    }

    # ---- .DWX backtest-invariant idiom advisories (WARN, not fail) ----
    # From the 2026-06-16 zero-trade rework: ~88 EA bugs clustered into a few
    # idioms that silently produce 0 trades in the .DWX tester. These are emitted
    # as WARNINGS (not failures) ON PURPOSE: calibration over the live corpus
    # showed each idiom ALSO appears in EAs that PASS Q02 (the same pattern is
    # benign or buggy depending on spread SOURCE / carry-by-design / a legitimately
    # deployed custom indicator), so a hard fail would regress healthy EAs. The
    # build prompt (codex_build_ea.md) is the primary prevention; this surfaces
    # slips for the reviewer. Spec: docs/ops/CODEGEN_SYSTEMIC_BUG_PREVENTION_SPEC_2026-06-16.md
    $dwxAdvisories = @(
        @{ Code = 'DWX_SPREAD_FAILCLOSED';
           Pattern = '(?<![A-Za-z])ask\s*<=\s*bid(?![A-Za-z])';
           Hint = 'fail-closed spread guard: .DWX quotes ask==bid (0 modeled spread) in the tester, so this blocks every bar -> 0 trades. Use `ask < bid` (block only crossed/negative quotes); treat zero spread as tradeable.' },
        @{ Code = 'DWX_SPREAD_ZERO_BLOCK';
           Pattern = 'if\s*\([^)]*\b(?:spread|current_spread|spread_points)\s*<=\s*0(?:\.0)?\b';
           Hint = 'spread<=0 in an if-guard: SymbolInfoInteger(SYMBOL_SPREAD)/iSpread/rates[].spread read 0 in the .DWX tester, so a guard that blocks on spread<=0 stops all entries. Allow zero/degenerate spread; only block a genuinely wide spread.' },
        @{ Code = 'DWX_SWAP_USAGE_REVIEW';
           Pattern = 'SYMBOL_SWAP_(?:LONG|SHORT)';
           Hint = 'swap usage: .DWX symbols apply $0 swap in the tester. OK to read swap as a carry SIGNAL/ranking, but a boolean entry gate on swap (sign or magnitude, directly or via a derived var) blocks every trade. Verify this is a signal, not a gate.' },
        @{ Code = 'DWX_LAZY_INDICATOR_HANDLE';
           Pattern = '\b(?:iRSI|iMA|iATR|iMACD|iADX|iBands|iStochastic|iVIDyA|iAO|iCMO|iCCI|iMomentum|iSAR)\s*\(';
           Hint = 'raw indicator handle in EA body: a handle created/released in a signal function does not back-calculate in the tester and returns a constant fallback -> indicator never crosses. Use the pooled QM_* readers (QM_RSI/QM_ATR/QM_EMA/QM_MACD_*/QM_ADX*/QM_BB_*/QM_Stoch).' },
        @{ Code = 'DWX_INDICATOR_RELEASE';
           Pattern = '\bIndicatorRelease\s*\(';
           Hint = 'IndicatorRelease in EA body: framework pools+releases handles. Releasing in the EA (esp. same function as create) yields a never-back-calculated handle -> 0 trades.' }
    )
    $dwxAdvisoryFiles = @($mqlFiles.ToArray() | Where-Object { $_ -notmatch '\\framework\\include\\' })
    foreach ($adv in $dwxAdvisories) {
        $hits = Select-String -Path $dwxAdvisoryFiles -Pattern $adv.Pattern -AllMatches
        foreach ($hit in $hits) {
            Add-Warning "BUILD_CHECK_DWX_ADVISORY_$($adv.Code): $($hit.Path):$($hit.LineNumber) -- $($adv.Hint)"
        }
    }
}


Invoke-ForbiddenScan -ResolvedRepoRoot 'C:\QM\repo'
ConvertTo-Json -InputObject @($script:found) -Compress
