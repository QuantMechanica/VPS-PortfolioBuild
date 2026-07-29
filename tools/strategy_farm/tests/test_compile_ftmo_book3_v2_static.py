from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "strategy_farm" / "compile_ftmo_book3_v2.ps1"


def _source() -> str:
    return SCRIPT.read_text(encoding="utf-8-sig")


def _compact(value: str) -> str:
    return "".join(value.split()).lower()


def test_powershell_ast_is_valid_without_executing_controller() -> None:
    shell = shutil.which("pwsh") or shutil.which("powershell")
    assert shell is not None, "PowerShell is required for the repository contract test"
    quoted = str(SCRIPT).replace("'", "''")
    command = (
        f"$tokens=$null;$errors=$null;"
        "[System.Management.Automation.Language.Parser]::ParseFile("
        f"'{quoted}',[ref]$tokens,[ref]$errors)|Out-Null;"
        "if($errors.Count-ne 0){$errors|ForEach-Object{$_.ToString()};exit 1};"
        "Write-Output ('AST_OK:'+ $tokens.Count)"
    )

    result = subprocess.run(
        [shell, "-NoProfile", "-NonInteractive", "-Command", command],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "AST_OK:" in result.stdout


def test_exact_four_eas_are_bound_in_serial_order() -> None:
    source = _source()
    expected = [
        "QM5_9936_ff-range-breakout-gmt3-h1",
        "QM5_10145_tsm-meanret",
        "QM5_13108_xti-mtsm-s2",
        "QM5_20181_ftmo-joint-multisym-timer",
    ]

    positions = [source.index(f"name = '{name}'") for name in expected]
    assert positions == sorted(positions)
    assert source.count("name = 'QM5_") == 4
    assert "foreach ($spec in $eaSpecs)" in source
    assert "serial_compile = $true" in source
    assert "$results.Count -ne $eaSpecs.Count" in source


def test_create_only_root_is_disjoint_from_v1_repo_and_protected_terminals() -> None:
    source = _source()
    compact = _compact(source)

    assert "[parameter(mandatory=$true)][validatenotnullorempty()][string]$artifactroot" in compact
    assert "$v1artifactroot=get-normalizedpath-path'd:\\qm\\strategy_farm\\artifacts\\ftmo_book3'" in compact
    assert "v2artifactrootversusimmutablev1artifactroot" in compact
    assert "artifactrootversusrepository" in compact
    assert "artifactrootiscreate-onlyandalreadyexists" in compact
    assert "assert-notprotectedterminalpath-path$artifactrootpath" in compact
    assert "assert-notprotectedterminalpath-path$templaterootpath" in compact

    disjoint = source.index("Assert-PathsDisjoint -Left $artifactRootPath")
    existence = source.index("if (Test-Path -LiteralPath $artifactRootPath)")
    create = source.index("New-Item -ItemType Directory -Path $artifactRootPath")
    assert disjoint < existence < create

    # The only filesystem deletion is the exact copied EX5, after containment.
    assert source.count("Remove-Item") == 1
    containment = source.index("Computed EX5 escaped new workspace")
    deletion = source.index("Remove-Item -LiteralPath $stagedEx5 -Force")
    assert containment < deletion
    assert "Remove-Item -LiteralPath $stagedEx5 -Force -Recurse" not in source


def test_security_bound_paths_reject_reparse_points_and_junctions() -> None:
    source = _source()
    compact = _compact(source)

    assert "functionassert-noreparsepointinexistingpath" in compact
    assert "[system.io.fileattributes]::reparsepoint" in compact
    assert "containsareparse-point/junctioncomponent" in compact
    assert "functionassert-noreparsepointsintree" in compact
    assert "containsreparse-point/junctionmembers" in compact

    # The create-only ArtifactRoot is checked through its nearest existing
    # ancestor before creation, then checked again after it exists.
    disjoint = source.index("Assert-PathsDisjoint -Left $artifactRootPath")
    artifact_create = source.index(
        "New-Item -ItemType Directory -Path $artifactRootPath"
    )
    post_create = source.index(
        "-Path $artifactRootPath -Label 'Created artifact root'"
    )
    assert disjoint < artifact_create < post_create

    assert (
        "Assert-NotProtectedTerminalPath -Path $templateRootPath "
        "-Label 'Portable template root'"
    ) in source
    assert "-Root $standardIncludeRoot -Label 'Portable template standard include tree'" in source
    assert "-Root $repoIncludeRoot -Label 'Repository include tree'" in source
    assert '-Root $sourceDirectory -Label "Canonical FTMO EA tree $($spec.name)"' in source
    assert '-Path $FlagPath -Label "[$Checkpoint] FACTORY_OFF path"' in source
    assert '-Path $LockPath -Label "[$Checkpoint] mutation-lock path"' in source
    assert "-Root $artifactRootPath -Label 'Artifact root before publication'" in source
    assert "-Root $artifactRootPath -Label 'Artifact root before manifest commit'" in source


def test_factory_off_lock_and_idle_metaeditor_are_rechecked() -> None:
    source = _source()
    compact = _compact(source)

    assert "[validatepattern('^[0-9a-fa-f]{64}$')]" in compact
    assert "get-sha256-path$flagpath" in compact
    assert "factory_offsha-256mismatch" in compact
    assert "factory_mutation.lock" in source.lower()
    assert "Get-Process -Name 'metaeditor64', 'metaeditor'" in source
    assert "MetaEditor process already active" in source

    for checkpoint in (
        "before-artifact-create",
        "before-compile-{0}",
        "after-compile-{0}",
        "before-canonical-publication",
        "before-manifest-commit",
    ):
        assert checkpoint in source
    assert source.count("Assert-SafetyInterlocks -FlagPath") >= 5


def test_source_commit_and_narrow_dirty_scope_are_fail_closed() -> None:
    source = _source()
    compact = _compact(source)

    assert "[validatepattern('^[0-9a-fa-f]{40}$')][string]$expectedsourcecommit" in compact
    assert "git-c$reporootrev-parse--verifyhead" in compact
    assert "repositoryheadisnotanexact40-hexcommit" in compact
    assert "sourcecommitmismatch" in compact
    assert "git-c$reporootstatus--porcelain=v1--untracked-files=all--@pathspecs" in compact
    assert "compile-relevantsourceisdirtyrelativetohead" in compact

    assert "$compileSourcePathspecs = @('framework/include')" in source
    assert '"framework/EAs/$($_.name)"' in source
    assert (
        "$compileSourcePathspecs += "
        "'tools/strategy_farm/compile_ftmo_book3_v2.ps1'"
    ) in source
    assert "framework/EAs/*" not in source
    assert source.count("Assert-CompileSourceBinding -RepoRoot $repoRoot") >= 5

    binding = source.index(
        "$actualSourceCommit = Assert-CompileSourceBinding -RepoRoot $repoRoot"
    )
    artifact_create = source.index(
        "New-Item -ItemType Directory -Path $artifactRootPath"
    )
    assert binding < artifact_create


def test_portable_compiler_and_appdata_are_isolated_without_terminal_start() -> None:
    source = _source()
    compact = _compact(source)

    assert "$workspacemetaeditor=join-path$compilerroot'metaeditor64.exe'" in compact
    assert "'/portable'" in source
    assert "portable.txt" in source
    assert "SetEnvironmentVariable('APPDATA', $IsolatedRoamingAppData, 'Process')" in source
    assert "SetEnvironmentVariable('LOCALAPPDATA', $IsolatedLocalAppData, 'Process')" in source
    assert "SetEnvironmentVariable('APPDATA', $previousAppData, 'Process')" in source
    assert "SetEnvironmentVariable('LOCALAPPDATA', $previousLocalAppData, 'Process')" in source

    # No terminal or tester is invokable: the sole process start is the copied
    # workspace MetaEditor, and other template EXEs are excluded from copying.
    assert source.count("Start-Process") == 1
    assert "Start-Process -FilePath $WorkspaceMetaEditor" in source
    assert "-PassThru -WindowStyle Hidden" in source
    assert "$runtimeExtensions = @('.dll', '.dat', '.ico')" in source
    assert "$runtimeExtensions -notcontains $file.Extension.ToLowerInvariant()" in source
    assert "-not $isMetaEditor" in source
    assert "Start-ScheduledTask" not in source


def test_standard_includes_are_copied_then_repo_overlay_is_bound() -> None:
    source = _source()

    standard_copy = source.index(
        "Copy-DirectoryContents -Source $standardIncludeRoot "
        "-Destination $isolatedIncludeRoot"
    )
    repo_overlay = source.index(
        "Copy-DirectoryContents -Source $repoIncludeRoot "
        "-Destination $isolatedIncludeRoot -Overlay"
    )
    assert standard_copy < repo_overlay
    assert "Get-TreeDigest -Root $standardIncludeRoot" in source
    assert "Get-TreeDigest -Root $repoIncludeRoot" in source
    assert "Get-TreeDigest -Root $isolatedIncludeRoot" in source
    assert "Isolated include tree changed during compile" in source


def test_compile_is_strict_fresh_and_rejects_external_include_provenance() -> None:
    source = _source()
    compact = _compact(source)

    assert "(?<errors>\\d+)\\s+errors?" in source
    assert "(?<warnings>\\d+)\\s+warnings?" in source
    assert "$summary.errors -ne 0 -or $summary.warnings -ne 0" in source
    assert "MetaEditor produced no EX5" in source
    assert "Compile output predates this invocation" in source
    assert "MetaEditor changed staged MQ5 bytes" in source
    assert "Compile log contains APPDATA provenance" in source
    assert "Compile log contains T_Live/T1-T10 provenance" in source
    assert "Compile log header escaped isolated MQL5 root" in source
    assert "deal_entry" not in compact  # compile controller has no trading behavior


def test_publication_and_manifest_happen_only_after_four_passes() -> None:
    source = _source()

    all_pass = source.index("Canonical publication requires exactly four serial PASS results")
    publication_stage = source.index(
        "$publicationStage = Join-Path $workspaceRoot 'publication_stage'"
    )
    canonical_move = source.index(
        "Move-Item -LiteralPath $publicationEx5 -Destination $canonicalEx5"
    )
    manifest_commit = source.index("Write-JsonCreateOnly -Path $manifestPath")
    assert all_pass < publication_stage < canonical_move < manifest_commit

    assert "canonical_staged_ex5" in source
    assert "canonical_compile_logs" in source
    assert "FileMode]::CreateNew" in source
    assert "canonical_publication_after_four_pass = $true" in source
    for manifest_field in (
        "source_commit",
        "source_mq5_sha256",
        "staged_mq5_sha256",
        "ex5_sha256",
        "compile_log_sha256",
        "source_sha256",
        "workspace_sha256",
        "standard_source",
        "repo_overlay",
        "isolated_merged_before",
        "isolated_merged_after",
        "staged_ex5_tree",
        "compile_logs_tree",
    ):
        assert manifest_field in source
