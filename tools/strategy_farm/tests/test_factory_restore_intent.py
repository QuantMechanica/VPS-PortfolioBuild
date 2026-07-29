from __future__ import annotations

import copy
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import factory_restore_intent as restore_intent  # noqa: E402


FACTORY_OFF = STRATEGY_FARM / "Factory_OFF.ps1"
FACTORY_ON = STRATEGY_FARM / "Factory_ON.ps1"
SCHEMA = STRATEGY_FARM / "schemas" / "factory_restore_intent.v1.schema.json"
TEMPLATE = STRATEGY_FARM / "factory_restore_intent.v1.template.json"
PS_TEST = HERE / "Test-FactoryRestoreIntent.ps1"


def _tasks() -> list[str]:
    source = FACTORY_OFF.read_text(encoding="utf-8-sig")
    match = re.search(r"\$QM_QUIESCENCE_TASKS\s*=\s*@\((.*?)\n\)", source, re.DOTALL)
    assert match
    return re.findall(r"'([^']+)'", match.group(1))


def _fixture(tmp_path: Path) -> tuple[Path, Path, dict]:
    flag = tmp_path / "FACTORY_OFF.flag"
    flag.write_text(
        '{"off_at":"2026-07-29T07:27:38Z","codex_parallel_before":"0"}\n',
        encoding="utf-8",
    )
    manifest = {
        "schema_version": restore_intent.SCHEMA_VERSION,
        "manifest_id": "OWNER-TEST-RESTORE-01",
        "legacy_off_flag": {
            "path": str(flag),
            "sha256": hashlib.sha256(flag.read_bytes()).hexdigest(),
        },
        "owner_authorization": {
            "authority": "OWNER",
            "authorized_by": "test-owner",
            "authorized_at_utc": "2026-07-29T12:00:00Z",
            "decision": restore_intent.DECISION,
            "decision_ref": "OWNER-TEST-DECISION-01",
            "scope": restore_intent.SCOPE,
        },
        "task_enabled_before": {
            task: index % 2 == 0 for index, task in enumerate(_tasks())
        },
    }
    path = tmp_path / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return flag, path, manifest


def test_valid_manifest_is_exactly_bound_and_normalized(tmp_path: Path) -> None:
    flag, path, manifest = _fixture(tmp_path)

    result = restore_intent.validate_restore_intent(path, flag, _tasks())

    assert result["validated"] is True
    assert result["legacy_flag_sha256"] == hashlib.sha256(flag.read_bytes()).hexdigest()
    assert result["manifest_sha256"] == hashlib.sha256(path.read_bytes()).hexdigest()
    assert result["task_enabled_before"] == manifest["task_enabled_before"]


@pytest.mark.parametrize("defect", ["missing", "extra", "non_boolean"])
def test_task_key_set_and_boolean_values_fail_closed(tmp_path: Path, defect: str) -> None:
    flag, path, manifest = _fixture(tmp_path)
    task = _tasks()[0]
    if defect == "missing":
        del manifest["task_enabled_before"][task]
    elif defect == "extra":
        manifest["task_enabled_before"]["QM_NOT_IN_CONTRACT"] = True
    else:
        manifest["task_enabled_before"][task] = 1
    path.write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(restore_intent.RestoreIntentError):
        restore_intent.validate_restore_intent(path, flag, _tasks())


def test_duplicate_json_keys_fail_before_semantic_validation(tmp_path: Path) -> None:
    flag, path, manifest = _fixture(tmp_path)
    raw = json.dumps(manifest)
    raw = raw.replace(
        '"manifest_id": "OWNER-TEST-RESTORE-01",',
        '"manifest_id": "OWNER-TEST-RESTORE-01", "manifest_id": "duplicate",',
    )
    path.write_text(raw, encoding="utf-8")

    with pytest.raises(restore_intent.RestoreIntentError, match="duplicate JSON key"):
        restore_intent.validate_restore_intent(path, flag, _tasks())


def test_flag_hash_and_owner_authorization_are_mandatory(tmp_path: Path) -> None:
    flag, path, manifest = _fixture(tmp_path)
    manifest["legacy_off_flag"]["sha256"] = "0" * 64
    path.write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(restore_intent.RestoreIntentError, match="SHA-256 mismatch"):
        restore_intent.validate_restore_intent(path, flag, _tasks())

    manifest["legacy_off_flag"]["sha256"] = hashlib.sha256(flag.read_bytes()).hexdigest()
    manifest["owner_authorization"]["decision_ref"] = "TBD"
    path.write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(restore_intent.RestoreIntentError, match="template placeholder"):
        restore_intent.validate_restore_intent(path, flag, _tasks())


def test_authorization_timestamp_must_be_utc_not_merely_timezone_aware(tmp_path: Path) -> None:
    flag, path, manifest = _fixture(tmp_path)
    manifest["owner_authorization"]["authorized_at_utc"] = "2026-07-29T14:00:00+02:00"
    path.write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(restore_intent.RestoreIntentError, match="must be UTC"):
        restore_intent.validate_restore_intent(path, flag, _tasks())


def test_nonlegacy_or_already_upgraded_flag_is_rejected(tmp_path: Path) -> None:
    flag, path, _ = _fixture(tmp_path)
    flag.write_text('{"schema_version":2,"task_enabled_before":{}}', encoding="utf-8")

    with pytest.raises(restore_intent.RestoreIntentError, match="not legacy-v1"):
        restore_intent.validate_restore_intent(path, flag, _tasks())


def test_schema_and_non_authorizing_template_track_exact_task_contract() -> None:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    expected = set(_tasks())

    task_schema = schema["properties"]["task_enabled_before"]
    assert set(task_schema["required"]) == expected
    assert set(task_schema["properties"]) == expected
    assert task_schema["additionalProperties"] is False
    assert schema["properties"]["owner_authorization"]["properties"][
        "authorized_at_utc"
    ]["pattern"] == "(?:Z|[+-]00:00)$"
    assert set(template["task_enabled_before"]) == expected
    assert all(value is None for value in template["task_enabled_before"].values())
    assert template["manifest_id"] is None
    assert template["legacy_off_flag"]["sha256"] is None
    assert template["owner_authorization"]["decision_ref"] is None


def test_factory_scripts_gate_legacy_upgrade_before_every_mutation() -> None:
    off = FACTORY_OFF.read_text(encoding="utf-8-sig")
    on = FACTORY_ON.read_text(encoding="utf-8-sig")
    legacy_branch = off.index("} elseif ($null -ne $existingOff) {")
    missing_manifest = off.index("legacy-v1 FACTORY_OFF.flag requires", legacy_branch)
    validator = off.index("$validatorOutput = @(& $pythonExe @validatorArgs", legacy_branch)
    hash_recheck = off.index("legacy FACTORY_OFF.flag changed after", validator)
    manifest_hash_recheck = off.index("restore-intent manifest changed after", hash_recheck)
    interlock_write = off.index("Write-FactoryOffRecord $offRecord", manifest_hash_recheck)
    parallel_write = off.index("Set-Content -LiteralPath $codexParallelPath", interlock_write)
    disable = off.index("Disable-ScheduledTask", parallel_write)

    assert legacy_branch < missing_manifest < validator < hash_recheck < manifest_hash_recheck
    assert manifest_hash_recheck < interlock_write < parallel_write < disable
    assert "$currentRestoreManifestSha = Get-QmFileSha256" in off
    assert "Get-TaskEnabled $taskName" not in off[legacy_branch:off.index("} else {", legacy_branch)]
    assert "-EncodedCommand" in off
    assert "-RestoreIntentManifest ' +" in off
    assert "factory_restore_intent.v1.template.json" in on
    assert "Current task state must not be inferred as pre-OFF intent" in on
    on_validation = on.index("$taskEnabledBefore = ConvertTo-ExactTaskEnabledState")
    on_lock = on.index("$script:factoryRestartMutationLock = Enter-FactoryMutationLock")
    on_release = on.index("Remove-Item -LiteralPath $factoryOffFlagPath", on_lock)
    assert on_validation < on_lock < on_release


def test_powershell_contract_suite() -> None:
    powershell = shutil.which("powershell.exe") or shutil.which("pwsh")
    if powershell is None:
        pytest.skip("PowerShell is not installed")
    result = subprocess.run(
        [powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(PS_TEST)],
        text=True,
        capture_output=True,
        timeout=60,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Factory restore-intent tests passed" in result.stdout
