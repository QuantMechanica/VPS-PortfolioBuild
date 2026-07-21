from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOL = EA_ROOT / "tools" / "candidate_analysis" / "audit_tv_nq_ict_ob_ws30.py"
BASE_TOOL = EA_ROOT / "tools" / "candidate_analysis" / "audit_tv_nq_ict_ob.py"


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


subject = _load("audit_tv_nq_ict_ob_ws30_test", TOOL)
ndx_subject = _load("audit_tv_nq_ict_ob_ndx_isolation_test", BASE_TOOL)


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _create_ws30_store(data_root: Path, *, include_extra: bool = False) -> Path:
    history = data_root / "history" / "WS30.DWX"
    ticks = data_root / "ticks" / "WS30.DWX"
    history.mkdir(parents=True, exist_ok=True)
    ticks.mkdir(parents=True, exist_ok=True)
    for year in subject.B._required_history_years():
        (history / f"{year}.hcc").write_bytes(f"ws30-hcc-{year}".encode("ascii"))
    for month in subject.B._required_tick_months():
        (ticks / f"{month}.tkc").write_bytes(f"ws30-tick-{month}".encode("ascii"))
    if include_extra:
        (ticks / "202601.tkc").write_bytes(b"outside-frozen-period")
    return data_root


def _provision_evidence(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Path, Path]:
    provision_root = tmp_path / "provision"
    manifest_path = provision_root / "provision_manifest.json"
    receipt_path = provision_root / "provision_receipt.json"
    source_data_root = _create_ws30_store(tmp_path / "source-Custom")
    target_data_root = _create_ws30_store(tmp_path / "target-Custom")
    monkeypatch.setattr(subject, "PROVISION_ROOT", provision_root)
    monkeypatch.setattr(subject, "PROVISION_MANIFEST_PATH", manifest_path)
    monkeypatch.setattr(subject, "PROVISION_RECEIPT_PATH", receipt_path)
    monkeypatch.setattr(subject, "PROVISION_SOURCE_DATA_ROOT", source_data_root)
    monkeypatch.setattr(subject, "PROVISION_TARGET_DATA_ROOT", target_data_root)
    manifest = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_WS30_DEV2_PROVISION_MANIFEST",
        "created_utc": "2026-07-21T00:00:00Z",
        "symbol": "WS30.DWX",
        "source_terminal": "T1",
        "source_data_root": str(source_data_root.resolve()),
        "target_terminal": "DEV2",
        "target_data_root": str(target_data_root.resolve()),
        "coverage": subject.B._data_coverage_contract(),
        "expected_history_files": 8,
        "expected_tick_files": 90,
        "expected_total_files": 98,
        "operation": "BYTE_EXACT_OFFLINE_FILE_TRANSPORT",
        "outcome_fence": {
            "mt5_terminal_started": False,
            "metatester_started": False,
            "native_reports_opened": False,
            "strategy_outcomes_read": False,
        },
    }
    _write_json(manifest_path, manifest)
    file_rows = []
    file_set_basis = []
    source_files = subject.B._expected_data_files("WS30.DWX", source_data_root)
    target_files = subject.B._expected_data_files("WS30.DWX", target_data_root)
    for source, target in zip(source_files, target_files):
        source_kind, source_period, source_path = source
        target_kind, target_period, target_path = target
        assert (source_kind, source_period) == (target_kind, target_period)
        source_binding = subject.B.stable_file_binding(source_path)
        target_binding = subject.B.stable_file_binding(target_path)
        assert source_binding["size"] == target_binding["size"]
        assert source_binding["sha256"] == target_binding["sha256"]
        file_rows.append(
            {
                "kind": source_kind,
                "period": source_period,
                "source": source_binding,
                "target": target_binding,
            }
        )
        file_set_basis.append(
            {
                "kind": source_kind,
                "period": source_period,
                "size": source_binding["size"],
                "sha256": source_binding["sha256"],
            }
        )
    file_set_sha256 = subject.B.canonical_sha256(file_set_basis)
    receipt = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_WS30_DEV2_PROVISION_RECEIPT",
        "status": "PASS",
        "completed_utc": "2026-07-21T00:01:00Z",
        "manifest": subject.B.stable_file_binding(manifest_path),
        "symbol": "WS30.DWX",
        "source_terminal": "T1",
        "target_terminal": "DEV2",
        "target_data_root": str(target_data_root.resolve()),
        "history_files": 8,
        "tick_files": 90,
        "file_count": 98,
        "files": file_rows,
        "source_file_set_sha256": file_set_sha256,
        "target_file_set_sha256": file_set_sha256,
        "source_target_sha256_equal": True,
        "outcome_fence": {
            "mt5_terminal_started": False,
            "metatester_started": False,
            "native_reports_opened": False,
            "strategy_outcomes_read": False,
        },
    }
    _write_json(receipt_path, receipt)
    return manifest_path, receipt_path


def _factory_evidence(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, *, include_aliases: bool = True
) -> dict[str, Path]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    design = tmp_path / "V5_FRAMEWORK_DESIGN.md"
    design.write_text(
        "Symbols carry `.DWX` in research and backtest, stripped only at deploy packaging.\n",
        encoding="utf-8",
    )
    rules = tmp_path / "seven_backtest_rules.md"
    rules.write_text(
        "### Rule 1 — Test ONLY on `.DWX` symbols\n\n"
        "Every backtest run uses the `.DWX`-suffixed custom symbols, never native broker symbols.\n",
        encoding="utf-8",
    )
    aliases = tmp_path / "execution_symbol_aliases_v1.json"
    dxz_symbols = (
        [{"raw_symbol": "WS30", "logical_symbol": "WS30.DWX"}]
        if include_aliases
        else []
    )
    ftmo_symbols = (
        [{"raw_symbol": "US30.cash", "logical_symbol": "WS30.DWX"}]
        if include_aliases
        else []
    )
    _write_json(
        aliases,
        {
            "schema_version": 1,
            "artifact_type": "QM_EXECUTION_SYMBOL_ALIASES",
            "status": "ACTIVE",
            "venues": [
                {"venue_id": "DXZ_LIVE", "symbols": dxz_symbols},
                {"venue_id": "FTMO_TRIAL", "symbols": ftmo_symbols},
            ],
        },
    )
    matrix = tmp_path / "dwx_symbol_matrix.csv"
    matrix.write_text(
        "symbol,asset_class,import_log_path,canonical_name_verified,evidence_line\n"
        "WS30.DWX,indices,Custom/Indices/Index 1/WS30.DWX,true,"
        "source=WS30 custom_tv=0.1 broker_tv=0.1\n",
        encoding="utf-8",
    )
    cost = tmp_path / "venue_cost_model.json"
    _write_json(
        cost,
        {
            "symbols": {
                "WS30": {
                    "asset_class": "index",
                    "dwx_symbol": "WS30.DWX",
                    "dxz": {
                        "commission_rt_per_lot_usd": 0.7,
                        "spread_source": "embedded in .DWX real-tick history",
                    },
                    "ftmo": {"commission_rt_per_lot_usd": 0.0},
                    "worst_case_rt_per_lot_usd": 0.7,
                }
            }
        },
    )
    calibration = tmp_path / "slippage.json"
    _write_json(
        calibration,
        {
            "symbols": {
                "WS30.DWX": {
                    "auto_stub": True,
                    "slippage_points": {"avg": 1.0, "p95": 3.0},
                }
            }
        },
    )
    monkeypatch.setattr(subject, "SLIPPAGE_CALIBRATION_PATH", calibration)
    manifest, receipt = _provision_evidence(tmp_path, monkeypatch)
    return {
        "v5_framework": design,
        "backtest_rules": rules,
        "aliases": aliases,
        "matrix": matrix,
        "cost": cost,
        "rebuild_done": receipt,
        "rebuild_source": manifest,
        "slippage_calibration": calibration,
    }


def _git_result(returncode: int, stdout: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(["git"], returncode, stdout=stdout, stderr="")


def test_private_import_keeps_ndx_auditor_unchanged() -> None:
    assert subject.B.RESEARCH_SYMBOL == "WS30.DWX"
    assert subject.B.ANALYSIS_ID == subject.ANALYSIS_ID
    assert ndx_subject.RESEARCH_SYMBOL == "NDX.DWX"
    assert ndx_subject.ANALYSIS_ID == "QM5_10834_TV_NQ_ICT_OB_NATIVE_001"
    assert ndx_subject.EXPECTED_MAGIC_SLOT_OFFSET == "0"
    assert ndx_subject.EXPECTED_LIVE_ALIASES == {
        "DXZ_LIVE": "NDX",
        "FTMO_TRIAL": "US100.cash",
    }


def test_preregistered_contract_is_hash_bound_and_semantically_valid() -> None:
    contract = subject.validate_transport_contract()
    assert subject.B.sha256_file(subject.CONTRACT_PATH) == subject.EXPECTED_CONTRACT_SHA256
    assert contract["candidate"]["research_symbol"] == "WS30.DWX"
    assert contract["candidate"]["ndx_analysis_may_not_be_retried_or_reset"] is True
    assert contract["attempt_budget"]["maximum_total_counted_attempts"] == 2
    assert contract["attempt_budget"]["further_attempts_forbidden"] is True


def test_ws30_set_is_same_strategy_with_only_preregistered_transport_differences() -> None:
    ndx_path = EA_ROOT / "sets" / f"{subject.B.EXPERT_NAME}_NDX.DWX_M5_backtest.set"
    ws30_path = EA_ROOT / "sets" / f"{subject.B.EXPERT_NAME}_WS30.DWX_M5_backtest.set"
    ndx_meta, ndx_inputs = subject.B.parse_set(ndx_path)
    ws30_meta, ws30_inputs = subject.B.parse_set(ws30_path)
    assert ndx_meta["symbol"] == "NDX.DWX"
    assert ws30_meta["symbol"] == "WS30.DWX"
    assert ndx_inputs["qm_magic_slot_offset"] == "0"
    assert ws30_inputs["qm_magic_slot_offset"] == "1"
    assert {k: v for k, v in ndx_inputs.items() if k != "qm_magic_slot_offset"} == {
        k: v for k, v in ws30_inputs.items() if k != "qm_magic_slot_offset"
    }
    subject.B._validate_set_contract("WS30.DWX", ws30_meta, ws30_inputs)


def test_ws30_cost_center_and_supplemental_axes_are_separate() -> None:
    schedule = subject.resolve_cost_schedule(subject.B.COST_PATH, "WS30.DWX")
    assert schedule["dxz_rt_per_lot_usd"] == "0.7"
    assert schedule["ftmo_rt_per_lot_usd"] == "0"
    assert schedule["worst_rt_per_lot_usd"] == "0.7"
    assert schedule["merit_center"]["additional_slippage_points"] == "0"
    assert schedule["supplemental_stress"]["slippage"]["points_axis"] == ["0", "1", "3"]
    overcost = schedule["supplemental_stress"]["registry_overcost"]
    assert overcost["absolute_commission_rt_per_lot_usd"] == "5.5"
    assert overcost["not_additive_to_merit_center"] is True
    assert overcost["merit_gate_effect"] == "NONE"


def test_factory_contract_requires_exact_future_live_alias_rows(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path, monkeypatch, include_aliases=False)
    with pytest.raises(subject.B.InvalidEvidence, match="DXZ_LIVE alias drift"):
        subject.B._validate_factory_contracts("WS30.DWX", evidence)


def test_factory_contract_accepts_ws30_alias_matrix_cost_and_provision(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path, monkeypatch)
    result = subject.B._validate_factory_contracts("WS30.DWX", evidence)
    assert result["namespace_contract"]["live_aliases"] == {
        "DXZ_LIVE": "WS30",
        "FTMO_TRIAL": "US30.cash",
    }
    assert result["namespace_contract"]["matrix_row"]["import_log_path"] == (
        "Custom/Indices/Index 1/WS30.DWX"
    )
    assert result["rebuild_contract"]["mode"] == "BYTE_EXACT_OFFLINE_FILE_TRANSPORT"
    assert result["rebuild_contract"]["files"] == 98


def test_provision_rehash_rejects_target_byte_flip_after_receipt(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path, monkeypatch)
    receipt = subject.B.load_json(evidence["rebuild_done"])
    target = Path(receipt["files"][0]["target"]["path"])
    target.write_bytes(target.read_bytes() + b"tamper")
    with pytest.raises(subject.B.InvalidEvidence, match="drift"):
        subject.B._validate_factory_contracts("WS30.DWX", evidence)


def test_provision_rejects_source_target_hardlink_identity(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path, monkeypatch)
    receipt_path = evidence["rebuild_done"]
    receipt = subject.B.load_json(receipt_path)
    source = Path(receipt["files"][0]["source"]["path"])
    target = Path(receipt["files"][0]["target"]["path"])
    target.unlink()
    target.hardlink_to(source)
    target_binding = subject.B.stable_file_binding(target)
    receipt["files"][0]["target"] = target_binding
    _write_json(receipt_path, receipt)
    with pytest.raises(subject.B.InvalidEvidence, match="same file|filesystem identity"):
        subject.B._validate_factory_contracts("WS30.DWX", evidence)


@pytest.mark.parametrize("mutation", ["reorder", "ndx_source_path", "ndx_target_path"])
def test_provision_rejects_reordered_or_cross_symbol_ledger_paths(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    mutation: str,
) -> None:
    evidence = _factory_evidence(tmp_path, monkeypatch)
    receipt_path = evidence["rebuild_done"]
    receipt = subject.B.load_json(receipt_path)
    if mutation == "reorder":
        receipt["files"][0], receipt["files"][1] = (
            receipt["files"][1],
            receipt["files"][0],
        )
    elif mutation == "ndx_source_path":
        receipt["files"][0]["source"]["path"] = (
            r"D:\QM\mt5\T1\Bases\Custom\history\NDX.DWX\2018.hcc"
        )
    else:
        receipt["files"][0]["target"]["path"] = (
            r"D:\QM\mt5\DEV2\Bases\Custom\history\NDX.DWX\2018.hcc"
        )
    _write_json(receipt_path, receipt)
    with pytest.raises(subject.B.InvalidEvidence, match="drift"):
        subject.B._validate_factory_contracts("WS30.DWX", evidence)


def test_freeze_data_is_ws30_only_exact_98_file_closure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path / "evidence", monkeypatch)
    data_root = subject.PROVISION_TARGET_DATA_ROOT
    (data_root / "ticks" / "WS30.DWX" / "202601.tkc").write_bytes(
        b"outside-frozen-period"
    )
    payload = subject.B.freeze_backtest_data(
        "WS30.DWX", terminal_data_root=data_root, evidence_paths=evidence
    )
    assert payload["artifact_type"] == "QM5_10834_WS30_BACKTEST_DATA_RECEIPT"
    assert payload["symbol"] == "WS30.DWX"
    assert payload["totals"]["history_files"] == 8
    assert payload["totals"]["tick_files"] == 90
    assert payload["totals"]["files"] == 98
    assert all("WS30.DWX" in row["path"] for row in payload["files"])
    assert all("NDX.DWX" not in row["path"] for row in payload["files"])
    assert not any(row["period"] == "202601" for row in payload["files"])
    assert payload["outcome_fence"] == {
        "strategy_outcomes_read": False,
        "native_reports_opened": False,
        "mt5_terminal_started": False,
        "metatester_started": False,
    }


def test_freeze_receipt_round_trip_reasserts_all_ws30_bytes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path / "evidence", monkeypatch)
    data_root = subject.PROVISION_TARGET_DATA_ROOT
    payload = subject.B.freeze_backtest_data(
        "WS30.DWX", terminal_data_root=data_root, evidence_paths=evidence
    )
    receipt = tmp_path / "receipt.json"
    subject.B.atomic_json(receipt, payload, replace=False)
    validated = subject.B.validate_backtest_data_receipt(
        receipt,
        "WS30.DWX",
        terminal_data_root=data_root,
        evidence_paths=evidence,
    )
    assert validated["receipt"] == subject.B.stable_file_binding(receipt)
    assert validated["totals"]["files"] == 98


def test_missing_provision_fails_cleanly_before_any_data_mutation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    evidence = _factory_evidence(tmp_path / "evidence", monkeypatch)
    missing = tmp_path / "missing-provision.json"
    evidence["rebuild_done"] = missing
    data_root = subject.PROVISION_TARGET_DATA_ROOT
    before = sorted(path.relative_to(data_root) for path in data_root.rglob("*"))
    with pytest.raises(subject.B.InvalidEvidence, match="required file missing"):
        subject.B.freeze_backtest_data(
            "WS30.DWX", terminal_data_root=data_root, evidence_paths=evidence
        )
    after = sorted(path.relative_to(data_root) for path in data_root.rglob("*"))
    assert after == before
    assert not missing.exists()


def test_pre_rejects_nonpreregistered_data_receipt_without_calling_base_or_creating_run_root(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    called = False

    def forbidden(*_args, **_kwargs):
        nonlocal called
        called = True
        raise AssertionError("base PRE must not be called")

    monkeypatch.setattr(subject, "_BASE_PREFLIGHT", forbidden)
    run_root = tmp_path / "run"
    with pytest.raises(subject.B.InvalidEvidence, match="data receipt must be exactly"):
        subject.preflight(
            "WS30.DWX",
            tmp_path / "wrong-data-receipt.json",
            subject.BUILD_RECEIPT_PATH,
            run_root,
        )
    assert called is False
    assert not run_root.exists()


def test_freeze_cli_rejects_noncanonical_receipt_without_creating_it(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    receipt = tmp_path / "wrong.json"
    code = subject.main(
        [
            "freeze-data",
            "--symbol",
            "WS30.DWX",
            "--receipt",
            str(receipt),
        ]
    )
    captured = capsys.readouterr()
    assert code == 2
    assert not receipt.exists()
    assert "freeze receipt must be exactly" in captured.err


def test_freeze_readiness_failure_does_not_consume_canonical_receipt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    receipt = tmp_path / "canonical.json"
    monkeypatch.setattr(subject, "FUTURE_DATA_RECEIPT_PATH", receipt)
    monkeypatch.setattr(subject, "PROVISION_RECEIPT_PATH", tmp_path / "missing-receipt.json")
    monkeypatch.setattr(subject, "PROVISION_MANIFEST_PATH", tmp_path / "missing-manifest.json")
    code = subject.main(
        [
            "freeze-data",
            "--symbol",
            "WS30.DWX",
            "--receipt",
            str(receipt),
        ]
    )
    captured = capsys.readouterr()
    assert code == 2
    assert not receipt.exists()
    assert '"status": "INVALID"' in captured.err


def test_primary_and_reserved_alternate_identities_are_distinct_and_frozen() -> None:
    assert subject.PRIMARY_RUN_ROOT != subject.ALTERNATE_RUN_ROOT
    assert subject.PRIMARY_CLAIM_PATH != subject.ALTERNATE_CLAIM_PATH
    assert subject.PRIMARY_AUTHORIZATION_SCOPE != subject.ALTERNATE_AUTHORIZATION_SCOPE
    assert subject.PRIMARY_CLAIM_PATH.name.endswith("ATTEMPT_001.json")
    assert subject.ALTERNATE_CLAIM_PATH.name.endswith("ATTEMPT_002.json")
    contract = subject.execution_contract()
    assert contract["current_attempt_type"] == "PRIMARY_ONE_SHOT"
    assert contract["maximum_counted_alternate_attempts"] == 1
    assert contract["maximum_total_counted_attempts"] == 2
    assert contract["retrospective_infrastructure_exemptions_forbidden"] is True
    assert contract["attempt_budget_contract"] == subject.B.file_binding(
        subject.CONTRACT_PATH, subject.EXPECTED_CONTRACT_SHA256
    )


def test_runtime_provenance_binds_fix_commit_and_current_file_hashes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bindings = {}
    for role in subject.RUNTIME_BINDING_ROLES:
        path = tmp_path / f"{role}.bin"
        path.write_bytes(role.encode("ascii"))
        bindings[role] = subject.B.file_binding(path)
    head = "a" * 40

    def fake_git(*args: str, check: bool = True):
        if args[:3] == ("show", "-s", "--format=%s"):
            return _git_result(0, subject.REQUIRED_WMI_FIX_SUBJECT + "\n")
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args[:2] == ("merge-base", "--is-ancestor"):
            return _git_result(0)
        if args[:2] == ("cat-file", "-e"):
            return _git_result(0)
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git", fake_git)
    provenance = subject.runtime_provenance(bindings)
    assert provenance["required_wmi_fix_commit"] == subject.REQUIRED_WMI_FIX_COMMIT
    assert provenance["pre_head_commit"] == head
    assert provenance["runtime_bindings"] == bindings
    subject.validate_runtime_provenance(provenance, bindings)


def test_base_auditor_is_a_required_pre_runtime_binding() -> None:
    paths = subject._expected_binding_paths("WS30.DWX")
    assert "base_tool" in subject.B.REQUIRED_BINDING_ROLES
    assert "base_tool" in subject.RUNTIME_BINDING_ROLES
    assert paths["base_tool"].resolve() == subject.BASE_TOOL_PATH.resolve()


def test_assert_pre_rejects_base_auditor_hash_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bindings = {}
    for role in subject.RUNTIME_BINDING_ROLES:
        path = tmp_path / f"{role}.bin"
        path.write_bytes(role.encode("ascii"))
        bindings[role] = subject.B.file_binding(path)
    head = "c" * 40

    def fake_git(*args: str, check: bool = True):
        if args[:3] == ("show", "-s", "--format=%s"):
            return _git_result(0, subject.REQUIRED_WMI_FIX_SUBJECT + "\n")
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args[:2] in {("merge-base", "--is-ancestor"), ("cat-file", "-e")}:
            return _git_result(0)
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git", fake_git)
    provenance = subject.runtime_provenance(bindings)
    fake_pre = {
        "run_root": str(subject.PRIMARY_RUN_ROOT.resolve()),
        "build_receipt": {"path": str(subject.BUILD_RECEIPT_PATH.resolve())},
        "backtest_data_receipt": {
            "path": str(subject.FUTURE_DATA_RECEIPT_PATH.resolve())
        },
        "transport_distinctness": {
            "classification": "NEW_SYMBOL_TRANSPORT_NOT_NDX_RETRY",
            "research_symbol": "WS30.DWX",
            "ndx_data_receipt_reused": False,
            "ndx_native_report_read": False,
            "ndx_strategy_outcome_read": False,
            "parameters_tuned_for_ws30": False,
        },
        "runtime_provenance": provenance,
        "bindings": bindings,
    }
    monkeypatch.setattr(subject, "_BASE_ASSERT_PRE_RECEIPT", lambda *_args: fake_pre)
    Path(bindings["base_tool"]["path"]).write_bytes(b"changed base auditor")
    with pytest.raises(subject.B.InvalidEvidence, match="drift"):
        subject.assert_pre_receipt(subject.PRIMARY_PRE_RECEIPT_PATH, "0" * 64)


def test_runtime_provenance_rejects_head_without_wmi_fix(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bindings = {}
    for role in subject.RUNTIME_BINDING_ROLES:
        path = tmp_path / role
        path.write_text(role, encoding="utf-8")
        bindings[role] = subject.B.file_binding(path)

    def fake_git(*args: str, check: bool = True):
        if args[:3] == ("show", "-s", "--format=%s"):
            return _git_result(0, subject.REQUIRED_WMI_FIX_SUBJECT + "\n")
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, "b" * 40 + "\n")
        if args[:2] == ("merge-base", "--is-ancestor"):
            return _git_result(1)
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git", fake_git)
    with pytest.raises(subject.B.InvalidEvidence, match="not an ancestor"):
        subject.runtime_provenance(bindings)


def test_supplemental_registry_overcost_does_not_change_merit_center() -> None:
    ledger = [
        {
            "entry_deal": "1",
            "exit_deals": ["2"],
            "volume": "1",
            "native_net_usd": "10.00",
        },
        {
            "entry_deal": "3",
            "exit_deals": ["4"],
            "volume": "2",
            "native_net_usd": "-1.00",
        },
    ]
    run = {"cost_ledger": {"trades": ledger}}
    post = {"cells": [{"cell_id": "WS30_DWX_DEV", "runs": [run, run]}]}
    stress = subject._supplemental_stress(post)
    assert stress["merit_center_unchanged"] is True
    assert stress["merit_center_commission_rt_per_lot_usd"] == "0.70"
    assert stress["registry_overcost_absolute_commission_rt_per_lot_usd"] == "5.50"
    assert stress["registry_overcost_is_not_additive_to_merit_center"] is True
    assert stress["registry_overcost_metrics_pooled"]["net_usd"] == "-7.50"
    assert stress["slippage_points_axis"]["merit_gate_effect"] == "NONE"


def test_adapter_contains_no_ndx_historical_attempt_validation_or_retry_paths() -> None:
    source = TOOL.read_text(encoding="utf-8")
    assert "PRIOR_NATIVE_ATTEMPT_RUN_ROOT" not in source
    assert "PRIOR_DPAPI_ATTEMPT_RUN_ROOT" not in source
    assert "_validate_prior_native_port_attempt" not in source
    assert "_validate_prior_dpapi_attempt" not in source
    assert "NDX_ICT_OB_FULL_DEV2_NATIVE_ATTEMPT" not in source


@pytest.mark.parametrize(
    "arguments",
    [
        ["status", "--state", "{root}/NDX/launch_state.json"],
        [
            "launch",
            "--pre-receipt",
            "{root}/NDX/pre_receipt.json",
            "--pre-sha256",
            "0" * 64,
            "--authorization",
            "{root}/NDX/authorization.json",
            "--state",
            "{root}/NDX/launch_state.json",
        ],
        [
            "post",
            "--pre-receipt",
            "{root}/NDX/pre_receipt.json",
            "--pre-sha256",
            "0" * 64,
            "--state",
            "{root}/NDX/launch_state.json",
            "--receipt",
            "{root}/NDX/post_receipt.json",
        ],
        ["_run-plan", "--job", "{root}/NDX/launch_job.json"],
    ],
)
def test_ndx_like_control_paths_rejected_before_any_inherited_read_or_dispatch(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    arguments: list[str],
) -> None:
    rendered = [value.format(root=tmp_path) for value in arguments]
    called = {"load": False, "main": False}

    def forbidden_load(*_args, **_kwargs):
        called["load"] = True
        raise AssertionError("must reject before load")

    def forbidden_main(*_args, **_kwargs):
        called["main"] = True
        raise AssertionError("must reject before inherited dispatch")

    monkeypatch.setattr(subject.B, "load_json", forbidden_load)
    monkeypatch.setattr(subject.B, "main", forbidden_main)
    code = subject.main(rendered)
    captured = capsys.readouterr()
    assert code == 2
    assert called == {"load": False, "main": False}
    assert "lexically exact" in captured.err
    assert not any(path.name == "post_receipt.json" for path in tmp_path.rglob("*"))


def test_reparse_primary_namespace_rejected_before_status_read(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    original = subject._path_is_reparse

    def fake_reparse(path: Path) -> bool:
        if os.path.normcase(str(subject._lexical_path(path))) == os.path.normcase(
            str(subject._lexical_path(subject.PRIMARY_RUN_ROOT))
        ):
            return True
        return original(path)

    called = False

    def forbidden_load(*_args, **_kwargs):
        nonlocal called
        called = True
        raise AssertionError("must reject before load")

    monkeypatch.setattr(subject, "_path_is_reparse", fake_reparse)
    monkeypatch.setattr(subject.B, "load_json", forbidden_load)
    code = subject.main(["status", "--state", str(subject.PRIMARY_STATE_PATH)])
    captured = capsys.readouterr()
    assert code == 2
    assert called is False
    assert "reparse component" in captured.err


def test_reparse_ws30_data_root_rejected_before_file_enumeration(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    data_root = tmp_path / "Custom"
    data_root.mkdir()
    original = subject._path_is_reparse

    def fake_reparse(path: Path) -> bool:
        if os.path.normcase(str(subject._lexical_path(path))) == os.path.normcase(
            str(subject._lexical_path(data_root))
        ):
            return True
        return original(path)

    monkeypatch.setattr(subject, "_path_is_reparse", fake_reparse)
    with pytest.raises(subject.B.InvalidEvidence, match="reparse component"):
        subject._expected_data_files("WS30.DWX", data_root)


def test_cli_has_no_parameter_merit_cost_or_attempt_override() -> None:
    parser = subject.B.build_parser()
    help_text = parser.format_help()
    assert "--minimum-trades" not in help_text
    assert "--profit-factor" not in help_text
    assert "--commission" not in help_text
    assert "--symbol" not in help_text  # only subcommand-local, not a global selector
    freeze = next(
        action for action in parser._actions if action.dest == "command"
    ).choices["freeze-data"]
    option_strings = {
        option
        for action in freeze._actions
        for option in action.option_strings
    }
    assert option_strings == {"-h", "--help", "--symbol", "--receipt"}


def test_window_and_merit_contract_are_identical_to_ndx() -> None:
    assert [
        (row.cell_id, row.cohort, row.from_date, row.to_date)
        for row in subject.B.WINDOWS
    ] == [
        (row.cell_id, row.cohort, row.from_date, row.to_date)
        for row in ndx_subject.WINDOWS
    ]
    assert subject.B.MERIT_GATES == ndx_subject.MERIT_GATES
    assert subject.B.TIMEFRAME == ndx_subject.TIMEFRAME == "M5"
    assert subject.B.DUPLICATES == ndx_subject.DUPLICATES == 2
    assert subject.B.MAX_ATTEMPTS_PER_CELL == ndx_subject.MAX_ATTEMPTS_PER_CELL == 4
    assert [(row.from_date, row.to_date) for row in subject.B.WINDOWS] == [
        (date(2018, 7, 2), date(2022, 12, 31)),
        (date(2023, 1, 1), date(2023, 12, 31)),
        (date(2024, 1, 1), date(2024, 12, 31)),
        (date(2025, 1, 1), date(2025, 12, 31)),
    ]


def test_required_wmi_fix_commit_is_currently_an_ancestor() -> None:
    provenance = subprocess.run(
        [
            "git",
            "-C",
            str(subject.REPO_ROOT),
            "merge-base",
            "--is-ancestor",
            subject.REQUIRED_WMI_FIX_COMMIT,
            "HEAD",
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert provenance.returncode == 0
    subject_line = subprocess.run(
        [
            "git",
            "-C",
            str(subject.REPO_ROOT),
            "show",
            "-s",
            "--format=%s",
            subject.REQUIRED_WMI_FIX_COMMIT,
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=30,
    ).stdout.strip()
    assert subject_line == subject.REQUIRED_WMI_FIX_SUBJECT


def test_contract_created_timestamp_is_utc_and_not_future() -> None:
    contract = subject.validate_transport_contract()
    created = datetime.fromisoformat(contract["created_utc"].replace("Z", "+00:00"))
    assert created.tzinfo is not None
    assert created.astimezone(timezone.utc) <= datetime.now(timezone.utc)
