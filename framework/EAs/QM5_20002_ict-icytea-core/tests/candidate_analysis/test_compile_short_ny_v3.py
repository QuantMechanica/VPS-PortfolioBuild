from __future__ import annotations

from pathlib import Path


EA_ROOT = Path(__file__).resolve().parents[2]
CONTROLLER_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "compile_short_ny_v3.ps1"
)
CONTROLLER = CONTROLLER_PATH.read_text(encoding="utf-8")


def test_controller_binds_frozen_contract_and_source() -> None:
    assert "3fd49f2cea7575e659f1b1cf9c24c752a4a8e11db5e0c17cae69629a6f207f83" in CONTROLLER
    assert "6ee74c60a823fe87b03b40a2737ba67d113b2e52e7c09a05f42ba2084e17fefa" in CONTROLLER
    assert "3f1039f0eeb56ee882b5c3451eed3ee71567d6bc" in CONTROLLER
    assert "d902b04932c340dd1212b9420077d7cec6b0d80d" in CONTROLLER
    assert "git -C $repoRoot cat-file -e" in CONTROLLER
    assert "git -C $repoRoot merge-base --is-ancestor" in CONTROLLER


def test_controller_only_invokes_the_canonical_strict_compile_path() -> None:
    assert "framework\\scripts\\compile_one.ps1" in CONTROLLER
    assert "-EAPath $stageMq5 -Strict -MetaEditorPath $metaEditor" in CONTROLLER
    assert "Start-Process" not in CONTROLLER
    assert "/config:" not in CONTROLLER
    assert "Start-ScheduledTask" in CONTROLLER
    assert "Register-ScheduledTask" in CONTROLLER
    assert "-RunLevel Limited" in CONTROLLER
    assert "-Trigger" not in CONTROLLER


def test_controller_is_fail_closed_and_transactional() -> None:
    for required in (
        "$controllerScript = [IO.Path]::GetFullPath($PSCommandPath)",
        "Global\\QM_DEV1_SMOKE_CONTROLLER",
        "if ($mutexAcquired)",
        "@($task.Triggers).Count -ne 0",
        "Compile controller changed during compile.",
        "compile_one changed during compile.",
        "MetaEditor changed during compile.",
        "if (-not $complete)",
        "Remove-Item -LiteralPath $repoEx5 -Force",
        "Copy-Item -LiteralPath $preexistingBackup -Destination $repoEx5 -Force",
    ):
        assert required in CONTROLLER


def test_evidence_marks_research_intake_and_binds_compile_closure() -> None:
    assert "$researchStatus = 'CARD_INTAKE_NOT_APPROVED'" in CONTROLLER
    assert "research_status = $researchStatus" in CONTROLLER
    for field in (
        "contract_commit",
        "contract_sha256",
        "source_git_commit",
        "source_sha256",
        "metaeditor_sha256",
        "compile_one_sha256",
        "compile_controller_sha256",
        "compile_log_sha256",
        "include_sync_manifest_sha256",
        "include_path_audit_sha256",
        "source_manifest_sha256",
        "active_dev1_processes_after",
        "ephemeral_tasks_after",
        "git_head_after",
    ):
        assert f"{field} =" in CONTROLLER
