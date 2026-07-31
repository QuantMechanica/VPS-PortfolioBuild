from __future__ import annotations

import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
STRATEGY_FARM = ROOT / "tools" / "strategy_farm"
FACTORY_ON = STRATEGY_FARM / "Factory_ON.ps1"
FACTORY_OFF = STRATEGY_FARM / "Factory_OFF.ps1"
PS51 = (
    Path(os.environ.get("SystemRoot", r"C:\Windows"))
    / "System32"
    / "WindowsPowerShell"
    / "v1.0"
    / "powershell.exe"
)
PS7 = Path(shutil.which("pwsh.exe") or r"C:\Program Files\PowerShell\7\pwsh.exe")
POWERSHELLS = (
    pytest.param(PS51, id="powershell-5.1"),
    pytest.param(PS7, id="powershell-7"),
)


def _ps_function(source: str, name: str) -> str:
    candidates = [
        index
        for token in (f"function {name} ", f"function {name}(")
        if (index := source.find(token)) >= 0
    ]
    if not candidates:
        raise ValueError(f"PowerShell function not found: {name}")
    start = min(candidates)
    opening = source.find("{", start)
    if opening < 0:
        raise ValueError(f"PowerShell function body not found: {name}")
    depth = 0
    quote: str | None = None
    block_comment = False
    index = opening
    while index < len(source):
        char = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if block_comment:
            if char == "#" and following == ">":
                block_comment = False
                index += 2
                continue
            index += 1
            continue
        if quote is not None:
            if char == "`":
                index += 2
                continue
            if char == quote:
                if quote == "'" and following == "'":
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if char == "<" and following == "#":
            block_comment = True
            index += 2
            continue
        if char == "#":
            newline = source.find("\n", index)
            index = len(source) if newline < 0 else newline + 1
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
        index += 1
    raise ValueError(f"PowerShell function end not found: {name}")


def _ps_literal(value: Path | str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def _write_native_helper(
    path: Path,
    *,
    exit_code: int = 0,
    noise_after_json: bool = False,
) -> None:
    noise = (
        "sys.stderr.write('native-prefix-noise\\n')\n"
        "sys.stderr.flush()\n"
    )
    json_line = "print('{\"authorized\":true,\"validated\":true}', flush=True)\n"
    ordered_output = (
        json_line + "time.sleep(0.1)\n" + noise
        if noise_after_json
        else noise + "time.sleep(0.1)\n" + json_line
    )
    path.write_text(
        "import sys\n"
        "import time\n"
        + ordered_output
        + f"raise SystemExit({exit_code})\n",
        encoding="utf-8",
    )


def _run_extracted(
    tmp_path: Path,
    shell: Path,
    *,
    extracted: str,
    harness: str,
) -> subprocess.CompletedProcess[str]:
    assert shell.is_file(), f"required PowerShell runtime missing: {shell}"
    extracted_path = tmp_path / "extracted.ps1"
    harness_path = tmp_path / "harness.ps1"
    extracted_path.write_text(extracted, encoding="utf-8-sig")
    harness_path.write_text(
        f". {_ps_literal(extracted_path)}\n{harness}",
        encoding="utf-8-sig",
    )
    return subprocess.run(
        (
            str(shell),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(harness_path),
        ),
        cwd=tmp_path,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=45,
        check=False,
    )


@pytest.mark.parametrize("shell", POWERSHELLS)
def test_factory_on_host_argv_candidates_execute_as_exact_7_and_8_arrays(
    tmp_path: Path,
    shell: Path,
) -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    function = _ps_function(source, "Assert-CanonicalFactoryOnHostProcess")
    marker = "    $matches = $false"
    assert function.count(marker) == 1
    function = function.replace(
        marker,
        """
    $script:observedAllowedCounts = @()
    foreach ($observedCandidate in $allowed) {
        $script:observedAllowedCounts += $observedCandidate.Count
    }
    $matches = $false""".strip("\n"),
        1,
    )
    harness = r"""
$ErrorActionPreference = 'Stop'
$canonicalFactoryOnProcessImage = 'C:\Synthetic\powershell.exe'
$canonicalFactoryOnPath = 'C:\Synthetic\Factory_ON.ps1'
function Get-CimInstance {
    param($ClassName, $Filter, $ErrorAction)
    [pscustomobject]@{
        ExecutablePath = $canonicalFactoryOnProcessImage
        CommandLine = 'synthetic command line'
    }
}
function Get-QmCommandLineArguments {
    param($CommandLine)
    $script:testCommandLineArguments
}
function Get-Process {
    param($Id, $ErrorAction)
    [pscustomobject]@{ StartTime = [datetime]'2026-07-31T05:00:00Z' }
}
$base = @(
    $canonicalFactoryOnProcessImage,
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $canonicalFactoryOnPath,
    '-CanonicalRuntimeHost'
)
$script:testCommandLineArguments = $base
Assert-CanonicalFactoryOnHostProcess
if (($script:observedAllowedCounts -join ',') -cne '7,8') { exit 11 }
$script:testCommandLineArguments = @($base + '-NoPause')
Assert-CanonicalFactoryOnHostProcess
if (($script:observedAllowedCounts -join ',') -cne '7,8') { exit 12 }
$script:testCommandLineArguments = @($base + '-Unexpected')
$rejected = $false
try { Assert-CanonicalFactoryOnHostProcess } catch {
    $rejected = $_.Exception.Message -match 'additional arguments are forbidden'
}
if (-not $rejected) { exit 13 }
Write-Output 'PASS exact-argv-7-8'
"""
    result = _run_extracted(
        tmp_path,
        shell,
        extracted=function,
        harness=harness,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS exact-argv-7-8" in result.stdout


@pytest.mark.parametrize("shell", POWERSHELLS)
def test_factory_off_published_record_executes_bom_and_bomless_roundtrips(
    tmp_path: Path,
    shell: Path,
) -> None:
    source = FACTORY_OFF.read_text(encoding="utf-8-sig")
    extracted = "\n\n".join(
        (
            _ps_function(source, "Get-QmFileSha256"),
            _ps_function(source, "ConvertTo-ExactTaskEnabledState"),
            _ps_function(source, "Assert-PublishedFactoryOffRecord"),
        )
    )
    flag_path = tmp_path / "FACTORY_OFF.flag"
    harness = f"""
$ErrorActionPreference = 'Stop'
$factoryOffFlagPath = {_ps_literal(flag_path)}
$QM_QUIESCENCE_TASKS = @('A','B')
$expected = [ordered]@{{
    schema_version = 2
    state = 'OFF'
    task_enabled_before = [ordered]@{{ A = $true; B = $false }}
}}
$json = '{{"schema_version":2,"state":"OFF","task_enabled_before":{{"A":true,"B":false}}}}'
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$jsonBytes = $utf8.GetBytes($json)
    foreach ($withBom in @($false, $true)) {{
    [byte[]]$bytes = $jsonBytes
    if ($withBom) {{
        [byte[]]$bytes = @([Text.UTF8Encoding]::new($true).GetPreamble() + $jsonBytes)
    }}
    [IO.File]::WriteAllBytes($factoryOffFlagPath, $bytes)
    $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($factoryOffFlagPath))
    $expectedSha = Get-QmFileSha256 -Path $factoryOffFlagPath
    $actualSha = Assert-PublishedFactoryOffRecord -ExpectedRecord $expected
    $after = [Convert]::ToBase64String([IO.File]::ReadAllBytes($factoryOffFlagPath))
        if ($actualSha -cne $expectedSha -or $after -cne $before) {{ exit 21 }}
    }}
[byte[]]$invalidBytes = @(
    [Text.UTF8Encoding]::new($true).GetPreamble() + [byte[]]@(0xff)
)
[IO.File]::WriteAllBytes($factoryOffFlagPath, $invalidBytes)
$invalidBefore = [Convert]::ToBase64String($invalidBytes)
$rejected = $false
try {{ Assert-PublishedFactoryOffRecord -ExpectedRecord $expected | Out-Null }} catch {{
    $rejected = $_.Exception.Message -match 'cannot be verified'
}}
$invalidAfter = [Convert]::ToBase64String(
    [IO.File]::ReadAllBytes($factoryOffFlagPath)
)
if (-not $rejected -or $invalidAfter -cne $invalidBefore) {{ exit 22 }}
Write-Output 'PASS bom-and-bomless-byte-exact'
"""
    result = _run_extracted(
        tmp_path,
        shell,
        extracted=extracted,
        harness=harness,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS bom-and-bomless-byte-exact" in result.stdout


@pytest.mark.parametrize("shell", POWERSHELLS)
def test_both_validator_paths_execute_last_json_line_with_native_stderr(
    tmp_path: Path,
    shell: Path,
) -> None:
    on_source = FACTORY_ON.read_text(encoding="utf-8-sig")
    off_source = FACTORY_OFF.read_text(encoding="utf-8-sig")
    on_function = _ps_function(
        on_source,
        "Get-CanonicalRuntimeActivationAuthorization",
    )
    off_start = off_source.index("    $validatorArgs = @(")
    off_end = off_source.index(
        "    $taskEnabledBefore = ConvertTo-ExactTaskEnabledState",
        off_start,
    )
    off_block = textwrap.dedent(off_source[off_start:off_end])
    extracted = (
        on_function
        + "\n\nfunction Invoke-ExtractedFactoryOffRestoreValidator {\n"
        + textwrap.indent(off_block, "    ")
        + "\n    return $validatedRestoreIntent\n}\n"
    )
    helper = tmp_path / "native-json-helper.py"
    failing_helper = tmp_path / "native-failure-helper.py"
    trailing_noise_helper = tmp_path / "native-trailing-noise-helper.py"
    _write_native_helper(helper)
    _write_native_helper(failing_helper, exit_code=7)
    _write_native_helper(trailing_noise_helper, noise_after_json=True)
    missing_flag = tmp_path / "missing-FACTORY_OFF.flag"
    harness = f"""
$ErrorActionPreference = 'Stop'
$pythonExe = {_ps_literal(Path(sys.executable))}
$runtimeActivationValidatorScript = {_ps_literal(helper)}
$factoryOffFlagPath = {_ps_literal(missing_flag)}
$authorization = Get-CanonicalRuntimeActivationAuthorization
if ($authorization.authorized -ne $true) {{ exit 31 }}
if ($ErrorActionPreference -cne 'Stop') {{ exit 32 }}

$restoreIntentValidatorPath = {_ps_literal(helper)}
$RestoreIntentManifest = {_ps_literal(tmp_path / "manifest.json")}
$QM_QUIESCENCE_TASKS = @()
$validated = Invoke-ExtractedFactoryOffRestoreValidator
if ($validated.validated -ne $true) {{ exit 33 }}
if ($ErrorActionPreference -cne 'Stop') {{ exit 34 }}

$runtimeActivationValidatorScript = {_ps_literal(failing_helper)}
$failedClosed = $false
try {{ Get-CanonicalRuntimeActivationAuthorization | Out-Null }} catch {{
    $failedClosed = $_.Exception.Message -match 'validation failed'
}}
if (-not $failedClosed -or $ErrorActionPreference -cne 'Stop') {{ exit 35 }}

$runtimeActivationValidatorScript = {_ps_literal(trailing_noise_helper)}
$trailingNoiseRejected = $false
try {{ Get-CanonicalRuntimeActivationAuthorization | Out-Null }} catch {{
    $trailingNoiseRejected = $_.Exception.Message -match 'invalid JSON'
}}
if (-not $trailingNoiseRejected -or $ErrorActionPreference -cne 'Stop') {{ exit 36 }}
Write-Output 'PASS noisy-validator-last-line-and-eap'
"""
    result = _run_extracted(
        tmp_path,
        shell,
        extracted=extracted,
        harness=harness,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS noisy-validator-last-line-and-eap" in result.stdout


@pytest.mark.parametrize("shell", POWERSHELLS)
def test_pacer_cleanup_and_rollback_execute_under_stop_with_native_stderr(
    tmp_path: Path,
    shell: Path,
) -> None:
    off_source = FACTORY_OFF.read_text(encoding="utf-8-sig")
    on_source = FACTORY_ON.read_text(encoding="utf-8-sig")
    pacer_start = off_source.index("$pacerCleanupOk = $true")
    pacer_end = off_source.index(
        'Write-Host ("  managed Codex drain',
        pacer_start,
    )
    pacer_block = textwrap.dedent(off_source[pacer_start:pacer_end])
    rollback = _ps_function(on_source, "Invoke-FailClosedRollback")
    extracted = (
        "function Invoke-ExtractedFactoryOffPacerCleanup {\n"
        + textwrap.indent(pacer_block, "    ")
        + "\n    [pscustomobject]@{ ok = $pacerCleanupOk; output = $pacerCleanupOutput }\n"
        + "}\n\n"
        + rollback
    )
    helper = tmp_path / "native-pacer-helper.py"
    _write_native_helper(helper)
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_bytes(b'{"state":"OFF","off_request_id":"synthetic"}\n')
    codex_parallel = tmp_path / "codex_parallel.txt"
    harness = f"""
$ErrorActionPreference = 'Stop'
$pythonExe = {_ps_literal(Path(sys.executable))}
$pacerScript = {_ps_literal(helper)}
$mutationDrainedBeforeCleanup = $true
$taskDrain = [pscustomobject]@{{ drained = $true }}
$cleanup = Invoke-ExtractedFactoryOffPacerCleanup
if (-not $cleanup.ok -or $cleanup.output -notmatch 'native-prefix-noise') {{ exit 41 }}
if ($ErrorActionPreference -cne 'Stop') {{ exit 42 }}

$factoryOffFlagPath = {_ps_literal(flag)}
$codexParallelPath = {_ps_literal(codex_parallel)}
$managedTasks = @()
function Stop-FactoryProcesses {{}}
$before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($factoryOffFlagPath))
Invoke-FailClosedRollback -Reason 'synthetic rollback' -PriorOffRecord $null
$after = [Convert]::ToBase64String([IO.File]::ReadAllBytes($factoryOffFlagPath))
if ($before -cne $after -or -not $script:externalFactoryOffIntentPreserved) {{ exit 43 }}
if ($ErrorActionPreference -cne 'Stop') {{ exit 44 }}
Write-Output 'PASS noisy-pacer-cleanup-and-rollback-eap'
"""
    result = _run_extracted(
        tmp_path,
        shell,
        extracted=extracted,
        harness=harness,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS noisy-pacer-cleanup-and-rollback-eap" in result.stdout


@pytest.mark.parametrize("shell", POWERSHELLS)
def test_quiescence_loop_executes_ordered_map_contains_semantics(
    tmp_path: Path,
    shell: Path,
) -> None:
    source = FACTORY_ON.read_text(encoding="utf-8-sig")
    anchor = source.index("$criticalTasksStartedAtUtc")
    loop_start = source.index(
        "    foreach ($taskName in $QM_QUIESCENCE_TASKS) {",
        anchor,
    )
    loop_end = source.index(
        "    # Keep read-only support online",
        loop_start,
    )
    loop = textwrap.dedent(source[loop_start:loop_end])
    extracted = (
        "function Invoke-ExtractedQuiescenceRestore {\n"
        + textwrap.indent(loop, "    ")
        + "\n}\n"
    )
    harness = r"""
$ErrorActionPreference = 'Stop'
$QM_QUIESCENCE_TASKS = @('A','B','C')
$taskEnabledBefore = [ordered]@{ A = $true; B = $false }
$script:enabled = @()
$script:disabled = @()
function Get-ScheduledTask {
    param($TaskName, $ErrorAction)
    [pscustomobject]@{ TaskName = $TaskName; State = 'Disabled' }
}
function Assert-NoFactoryOffIntent { param($Context) }
function Enable-ScheduledTask {
    param($TaskName, $ErrorAction)
    $script:enabled += $TaskName
}
function Disable-ScheduledTask {
    param($TaskName, $ErrorAction)
    $script:disabled += $TaskName
}
Invoke-ExtractedQuiescenceRestore
if (($script:enabled -join ',') -cne 'A') { exit 51 }
if (($script:disabled -join ',') -cne 'B,C') { exit 52 }
Write-Output 'PASS ordered-map-contains'
"""
    result = _run_extracted(
        tmp_path,
        shell,
        extracted=extracted,
        harness=harness,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS ordered-map-contains" in result.stdout
