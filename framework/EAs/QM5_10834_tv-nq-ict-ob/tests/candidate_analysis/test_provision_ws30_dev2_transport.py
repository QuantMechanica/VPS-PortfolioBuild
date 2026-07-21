from __future__ import annotations

import ast
import importlib.util
import json
import os
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOL = (
    EA_ROOT
    / "tools"
    / "candidate_analysis"
    / "provision_ws30_dev2_transport.py"
)


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


subject = _load("provision_ws30_dev2_transport_test", TOOL)


def _create_source_store(root: Path) -> Path:
    history = root / "history" / "WS30.DWX"
    ticks = root / "ticks" / "WS30.DWX"
    history.mkdir(parents=True)
    ticks.mkdir(parents=True)
    for year in subject.A.B._required_history_years():
        (history / f"{year}.hcc").write_bytes(f"ws30-history-{year}".encode("ascii"))
    for month in subject.A.B._required_tick_months():
        (ticks / f"{month}.tkc").write_bytes(f"ws30-ticks-{month}".encode("ascii"))
    (ticks / "202601.tkc").write_bytes(b"outside-preregistered-coverage")
    return root


def _sandbox(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[Path, Path, Path]:
    source = _create_source_store(tmp_path / "T1" / "Bases" / "Custom")
    target = tmp_path / "DEV2" / "Bases" / "Custom"
    (target / "history").mkdir(parents=True)
    (target / "ticks").mkdir(parents=True)
    evidence = (
        tmp_path
        / "reports"
        / "setup"
        / "tick-data-timezone"
        / "WS30.DWX_DEV2_TRANSPORT_001"
    )
    evidence.parent.mkdir(parents=True)
    manifest = evidence / "provision_manifest.json"
    receipt = evidence / "provision_receipt.json"

    monkeypatch.setattr(subject, "SOURCE_DATA_ROOT", source)
    monkeypatch.setattr(subject, "TARGET_DATA_ROOT", target)
    monkeypatch.setattr(subject, "EVIDENCE_ROOT", evidence)
    monkeypatch.setattr(subject, "MANIFEST_PATH", manifest)
    monkeypatch.setattr(subject, "RECEIPT_PATH", receipt)
    monkeypatch.setattr(subject.A, "PROVISION_SOURCE_DATA_ROOT", source)
    monkeypatch.setattr(subject.A, "PROVISION_TARGET_DATA_ROOT", target)
    monkeypatch.setattr(subject.A, "PROVISION_ROOT", evidence)
    monkeypatch.setattr(subject.A, "PROVISION_MANIFEST_PATH", manifest)
    monkeypatch.setattr(subject.A, "PROVISION_RECEIPT_PATH", receipt)
    return source, target, evidence


def _load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    assert isinstance(value, dict)
    return value


def test_happy_path_produces_exact_independent_ordered_98_file_ledger(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source, target, evidence = _sandbox(tmp_path, monkeypatch)

    result = subject.provision_historical_transport()

    assert result["status"] == "PASS"
    assert result["operation"] == "BYTE_EXACT_OFFLINE_FILE_TRANSPORT"
    assert result["research_historical_only"] is True
    assert result["symbol_validation_status"] == "FAIL_RESEARCH_HISTORICAL_ONLY"
    assert result["live_parity_claim"] is False
    assert result["registry_updated"] is False
    assert result["mt5_started"] is False
    assert result["file_count"] == 98

    manifest_path = evidence / "provision_manifest.json"
    receipt_path = evidence / "provision_receipt.json"
    manifest = _load_json(manifest_path)
    receipt = _load_json(receipt_path)
    assert set(manifest) == {
        "schema_version",
        "artifact_type",
        "created_utc",
        "symbol",
        "source_terminal",
        "source_data_root",
        "target_terminal",
        "target_data_root",
        "coverage",
        "expected_history_files",
        "expected_tick_files",
        "expected_total_files",
        "operation",
        "outcome_fence",
    }
    assert set(receipt) == {
        "schema_version",
        "artifact_type",
        "status",
        "completed_utc",
        "manifest",
        "symbol",
        "source_terminal",
        "target_terminal",
        "target_data_root",
        "history_files",
        "tick_files",
        "file_count",
        "files",
        "source_file_set_sha256",
        "target_file_set_sha256",
        "source_target_sha256_equal",
        "outcome_fence",
    }
    assert "validation_status" not in manifest
    assert "validation_status" not in receipt
    assert receipt["source_file_set_sha256"] == receipt["target_file_set_sha256"]
    assert result["file_set_sha256"] == receipt["source_file_set_sha256"]

    expected_periods = [
        *(str(year) for year in range(2018, 2026)),
        *subject.A.B._required_tick_months(),
    ]
    assert [row["period"] for row in receipt["files"]] == expected_periods
    assert [row["kind"] for row in receipt["files"][:8]] == ["history"] * 8
    assert [row["kind"] for row in receipt["files"][8:]] == ["ticks"] * 90
    for row in receipt["files"]:
        source_path = Path(row["source"]["path"])
        target_path = Path(row["target"]["path"])
        assert source_path.read_bytes() == target_path.read_bytes()
        assert row["source"]["size"] == row["target"]["size"]
        assert row["source"]["sha256"] == row["target"]["sha256"]
        assert not os.path.samefile(source_path, target_path)
        assert source_path.stat().st_nlink == 1
        assert target_path.stat().st_nlink == 1
    assert (source / "ticks" / "WS30.DWX" / "202601.tkc").is_file()
    assert not (target / "ticks" / "WS30.DWX" / "202601.tkc").exists()

    audited = subject.A.validate_data_provision_contract(
        "WS30.DWX", receipt_path, manifest_path
    )
    assert audited["status"] == "PASS"
    assert audited["files"] == 98


@pytest.mark.parametrize("kind", ["history", "ticks"])
def test_preexisting_target_symbol_directory_fails_before_evidence_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, kind: str
) -> None:
    _source, target, evidence = _sandbox(tmp_path, monkeypatch)
    (target / kind / "WS30.DWX").mkdir()

    with pytest.raises(subject.ProvisionError, match="already exists"):
        subject.provision_historical_transport()

    assert not evidence.exists()
    assert not (evidence / "provision_receipt.json").exists()


def test_preexisting_evidence_root_fails_before_target_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source, target, evidence = _sandbox(tmp_path, monkeypatch)
    evidence.mkdir()

    with pytest.raises(subject.ProvisionError, match="evidence root already exists"):
        subject.provision_historical_transport()

    assert not (target / "history" / "WS30.DWX").exists()
    assert not (target / "ticks" / "WS30.DWX").exists()


def test_source_hardlink_is_rejected_before_any_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source, target, evidence = _sandbox(tmp_path, monkeypatch)
    original = source / "history" / "WS30.DWX" / "2018.hcc"
    os.link(original, source / "history" / "WS30.DWX" / "2018-copy.hcc")

    with pytest.raises(subject.ProvisionError, match="hardlink count"):
        subject.provision_historical_transport()

    assert not evidence.exists()
    assert not (target / "history" / "WS30.DWX").exists()


def test_source_reparse_file_is_rejected_before_any_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source, target, evidence = _sandbox(tmp_path, monkeypatch)
    victim = source / "history" / "WS30.DWX" / "2018.hcc"
    outside = tmp_path / "outside.hcc"
    outside.write_bytes(victim.read_bytes())
    victim.unlink()
    try:
        victim.symlink_to(outside)
    except OSError as exc:  # pragma: no cover - depends on Windows symlink policy.
        pytest.skip(f"symlink creation is unavailable: {exc}")

    with pytest.raises(subject.ProvisionError, match="reparse component"):
        subject.provision_historical_transport()

    assert not evidence.exists()
    assert not (target / "history" / "WS30.DWX").exists()


def test_target_namespace_reparse_is_rejected_before_any_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source, target, evidence = _sandbox(tmp_path, monkeypatch)
    outside = tmp_path / "outside-history"
    outside.mkdir()
    (target / "history").rmdir()
    try:
        (target / "history").symlink_to(outside, target_is_directory=True)
    except OSError as exc:  # pragma: no cover - depends on Windows symlink policy.
        pytest.skip(f"directory symlink creation is unavailable: {exc}")

    with pytest.raises(subject.ProvisionError, match="reparse component"):
        subject.provision_historical_transport()

    assert not evidence.exists()
    assert not (target / "ticks" / "WS30.DWX").exists()


def test_source_identity_change_after_preflight_leaves_no_pass_receipt(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source, _target, evidence = _sandbox(tmp_path, monkeypatch)
    original = subject._copy_file_atomic
    mutated = False

    def mutate_then_copy(snapshot, **kwargs):
        nonlocal mutated
        if not mutated:
            mutated = True
            snapshot.source_path.write_bytes(snapshot.source_path.read_bytes() + b"tamper")
        return original(snapshot, **kwargs)

    monkeypatch.setattr(subject, "_copy_file_atomic", mutate_then_copy)
    with pytest.raises(subject.ProvisionError, match="source changed after preflight"):
        subject.provision_historical_transport()

    assert (evidence / "provision_manifest.json").is_file()
    assert not (evidence / "provision_receipt.json").exists()


def test_target_change_after_atomic_copy_is_rejected_before_receipt(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source, _target, evidence = _sandbox(tmp_path, monkeypatch)
    original = subject._copy_file_atomic
    mutated = False

    def copy_then_mutate(snapshot, **kwargs):
        nonlocal mutated
        result = original(snapshot, **kwargs)
        if not mutated:
            mutated = True
            snapshot.target_path.write_bytes(snapshot.target_path.read_bytes() + b"tamper")
        return result

    monkeypatch.setattr(subject, "_copy_file_atomic", copy_then_mutate)
    with pytest.raises(subject.ProvisionError, match="target identity drift"):
        subject.provision_historical_transport()

    assert (evidence / "provision_manifest.json").is_file()
    assert not (evidence / "provision_receipt.json").exists()


def test_same_file_or_hardlink_alias_is_rejected(tmp_path: Path) -> None:
    source = tmp_path / "source.bin"
    target = tmp_path / "target.bin"
    source.write_bytes(b"independent-file-required")
    if target.exists():
        target.unlink()
    os.link(source, target)
    source_identity = subject._identity_from_stat(os.stat(source))
    target_identity = subject._identity_from_stat(os.stat(target))
    with pytest.raises(subject.ProvisionError, match="hardlink|same-file"):
        subject._assert_source_target_distinct(
            source, target, source_identity, target_identity, "test"
        )


def test_atomic_json_create_never_replaces_existing_destination(tmp_path: Path) -> None:
    root = tmp_path / "evidence"
    root.mkdir()
    _root, identity = subject._directory_identity(root, "test evidence root")
    destination = root / "receipt.json"
    destination.write_bytes(b"immutable")

    with pytest.raises(subject.ProvisionError, match="already exists"):
        subject._atomic_json_create(
            destination,
            {"status": "PASS"},
            parent_identity=identity,
            label="test receipt",
        )

    assert destination.read_bytes() == b"immutable"
    assert not list(root.glob(".*.tmp"))


def test_t6_component_is_rejected_even_if_other_fixed_contract_paths_match(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "T1" / "Custom"
    target = tmp_path / "T6" / "Custom"
    evidence = tmp_path / "evidence"
    monkeypatch.setattr(subject, "SOURCE_DATA_ROOT", source)
    monkeypatch.setattr(subject, "TARGET_DATA_ROOT", target)
    monkeypatch.setattr(subject, "EVIDENCE_ROOT", evidence)
    monkeypatch.setattr(subject, "MANIFEST_PATH", evidence / "provision_manifest.json")
    monkeypatch.setattr(subject, "RECEIPT_PATH", evidence / "provision_receipt.json")
    monkeypatch.setattr(subject.A, "PROVISION_SOURCE_DATA_ROOT", source)
    monkeypatch.setattr(subject.A, "PROVISION_TARGET_DATA_ROOT", target)
    monkeypatch.setattr(subject.A, "PROVISION_ROOT", evidence)
    monkeypatch.setattr(
        subject.A, "PROVISION_MANIFEST_PATH", evidence / "provision_manifest.json"
    )
    monkeypatch.setattr(
        subject.A, "PROVISION_RECEIPT_PATH", evidence / "provision_receipt.json"
    )

    with pytest.raises(subject.ProvisionError, match="T6 is forbidden"):
        subject._assert_fixed_contract()

    assert not tmp_path.exists() or not any(tmp_path.iterdir())


@pytest.mark.parametrize(
    "argv",
    [
        ["provision", "--symbol", "WS30.DWX"],
        [
            "provision",
            "--symbol",
            "NDX.DWX",
            "--acknowledge-research-historical-only",
        ],
    ],
)
def test_cli_requires_exact_symbol_and_explicit_research_only_acknowledgement(
    argv: list[str], monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(
        subject,
        "provision_historical_transport",
        lambda: pytest.fail("invalid CLI must not enter the mutating provisioner"),
    )

    assert subject.main(argv) == 2
    rejection = json.loads(capsys.readouterr().err)
    assert rejection["status"] == "REJECT"
    assert rejection["symbol_validation_status"] == "FAIL_RESEARCH_HISTORICAL_ONLY"
    assert rejection["live_parity_claim"] is False
    assert rejection["registry_updated"] is False
    assert rejection["mt5_started"] is False


def test_cli_has_no_path_override_surface() -> None:
    with pytest.raises(SystemExit):
        subject.parse_args(
            [
                "provision",
                "--symbol",
                "WS30.DWX",
                "--acknowledge-research-historical-only",
                "--source-root",
                "X:\\forbidden",
            ]
        )


def test_tool_has_no_process_launch_or_registry_write_code() -> None:
    tree = ast.parse(TOOL.read_text(encoding="utf-8"))
    imported = {
        alias.name.split(".")[0]
        for node in ast.walk(tree)
        if isinstance(node, (ast.Import, ast.ImportFrom))
        for alias in node.names
    }
    assert "subprocess" not in imported
    calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call)]
    forbidden_names = {"Popen", "run", "check_call", "check_output", "system"}
    assert not any(
        isinstance(call.func, ast.Attribute) and call.func.attr in forbidden_names
        for call in calls
    )
    assert subject.SYMBOL_VALIDATION_STATUS == "FAIL_RESEARCH_HISTORICAL_ONLY"
