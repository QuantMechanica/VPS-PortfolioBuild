from __future__ import annotations

import importlib.util
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest


TOOL = (
    Path(__file__).parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_mulham_asian_sweep_london_eur_testwindow_semantic.py"
)
SPEC = importlib.util.spec_from_file_location("qm13210_eur_semantic_under_test", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _runtime(*, workers=None, mt5=None, task_state: str = "Disabled") -> dict:
    return {
        "scheduled_tasks": [
            {"task_name": name, "count": 1, "state": task_state}
            for name in subject.MANAGED_OFF_TASKS
        ],
        "exact_factory_mt5_processes": [] if mt5 is None else mt5,
        "registered_factory_python_workers": [] if workers is None else workers,
    }


def _install_fake_quiescence(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    *,
    workers=None,
    mt5=None,
    mutexes=None,
) -> Path:
    flag = tmp_path / "FACTORY_OFF.flag"
    codex = tmp_path / "codex_parallel.txt"
    registry = tmp_path / "worker_pids.json"
    flag.write_text(
        json.dumps(
            {
                "off_at": (datetime.now(timezone.utc) - timedelta(seconds=10)).isoformat(),
                "codex_parallel_before": "3",
            }
        ),
        encoding="utf-8",
    )
    codex.write_text("0\n", encoding="ascii")
    registry.write_text('{"T1": 111}\n', encoding="utf-8")
    monkeypatch.setattr(subject, "FACTORY_OFF_FLAG_PATH", flag)
    monkeypatch.setattr(subject, "CODEX_PARALLEL_PATH", codex)
    monkeypatch.setattr(subject, "WORKER_PIDS_PATH", registry)
    monkeypatch.setattr(
        subject,
        "_probe_quiescence_runtime",
        lambda: _runtime(workers=workers, mt5=mt5),
    )
    monkeypatch.setattr(
        subject,
        "_probe_worker_mutexes",
        lambda: [] if mutexes is None else mutexes,
    )
    return registry


def test_draft_contract_is_exact_and_eur_only() -> None:
    draft = subject.validate_draft_contract()
    candidate = draft["candidate"]
    assert draft["analysis_id"].endswith("EURUSD_NATIVE_001")
    assert candidate["research_symbol"] == "EURUSD.DWX"
    assert candidate["research_namespace"] == ".DWX"
    assert candidate["live_symbol_alias_policy"] == "DEPLOY_PACKAGING_ONLY_EXACT_VENUE_ALIAS"
    assert candidate["timeframe"] == "M5"
    assert candidate["model"] == 4
    assert candidate["magic_slot"] == 0
    assert candidate["magic"] == 132100000
    assert candidate["registry_worst_case_rt_per_lot_usd"] == "5.85"


def test_eur_adapter_never_imports_or_delegates_to_xau_auditors() -> None:
    source = TOOL.read_text(encoding="utf-8")
    assert "audit_mulham_asian_sweep_london_xau" not in source
    assert subject.BASE_TOOL_PATH.name == "audit_mulham_asian_sweep_london.py"
    boundary = subject._xau_family_boundary_contract()
    assert boundary["closure_scope"] == "XAUUSD.DWX_XAUUSD_MULHAM_NATIVE_003_ONLY"
    assert boundary["xau_family_is_terminal_and_must_never_resume_retry_or_relaunch"] is True
    assert boundary["eurusd_analysis_is_a_distinct_unused_symbol_slot_family"] is True
    assert boundary["eurusd_adapter_imports_or_delegates_to_xau_auditors"] is False


def test_missing_eur_manifest_and_readiness_fail_explicitly(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    manifest = tmp_path / "EURUSD_DWX_201807_202512_T1_manifest.json"
    readiness = tmp_path / "EURUSD_DWX_201807_202512_T1_receipt.json"
    monkeypatch.setattr(subject, "DATA_MANIFEST_PATH", manifest)
    monkeypatch.setattr(subject, "RESEARCH_READINESS_PATH", readiness)
    with pytest.raises(subject.InvalidEvidence, match=r"EURUSD\.DWX PRE blocked.*missing"):
        subject._require_preregistered_eur_data_artifacts()


def test_preflight_stops_at_missing_data_before_base_or_xau_boundary(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    manifest = tmp_path / "EURUSD_DWX_201807_202512_T1_manifest.json"
    readiness = tmp_path / "EURUSD_DWX_201807_202512_T1_receipt.json"
    monkeypatch.setattr(subject, "DATA_MANIFEST_PATH", manifest)
    monkeypatch.setattr(subject, "RESEARCH_READINESS_PATH", readiness)
    monkeypatch.setattr(
        subject,
        "_BASE_PREFLIGHT",
        lambda *args, **kwargs: pytest.fail("base PRE must not run without EUR data receipts"),
    )
    monkeypatch.setattr(
        subject,
        "_assert_xau_family_boundary",
        lambda: pytest.fail("XAU boundary need not be touched after explicit data failure"),
    )
    with pytest.raises(subject.InvalidEvidence, match="preregistered tick-data"):
        subject.preflight(
            "EURUSD.DWX",
            readiness,
            manifest,
            subject.BUILD_RECEIPT_PATH,
            subject.ALLOWED_RUN_ROOT,
        )


def test_prepare_and_pre_paths_are_exact(tmp_path: Path) -> None:
    with pytest.raises(subject.InvalidEvidence, match="EUR data manifest must be exactly"):
        subject._assert_exact_data_paths(
            tmp_path / "manifest.json", subject.RESEARCH_READINESS_PATH
        )
    subject._assert_exact_data_paths(
        subject.DATA_MANIFEST_PATH, subject.RESEARCH_READINESS_PATH
    )


def test_raw_worker_registry_byte_drift_with_empty_live_projection_is_accepted(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    registry = _install_fake_quiescence(monkeypatch, tmp_path)
    first = subject.probe_testwindow_off_quiescence()
    registry.write_text('{"stale":"historical bytes changed"}\n', encoding="utf-8")
    second = subject.assert_testwindow_off_quiescence(first)
    assert first["invariant"] == second["invariant"]
    worker_binding = first["invariant"]["worker_pid_registry"]
    assert worker_binding == {
        "path": str(registry.resolve()),
        "binding_mode": "SEMANTIC_LIVE_REGISTERED_WORKER_PROJECTION",
        "raw_sha256_bound": False,
        "raw_size_bound": False,
    }


@pytest.mark.parametrize(
    ("workers", "mt5", "mutexes", "message"),
    [
        ([{"terminal": "T1", "pid": 99, "image": "python"}], None, None, "semantically live"),
        (None, [{"terminal": "T2", "pid": 88, "image": "terminal64"}], None, "exact T1-T10"),
        (None, None, ["T3"], "active terminal-worker mutexes"),
    ],
)
def test_semantically_live_worker_mt5_or_mutex_fails_closed(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    workers,
    mt5,
    mutexes,
    message: str,
) -> None:
    _install_fake_quiescence(
        monkeypatch, tmp_path, workers=workers, mt5=mt5, mutexes=mutexes
    )
    with pytest.raises(subject.InvalidEvidence, match=message):
        subject.probe_testwindow_off_quiescence()


def test_quiescence_contract_rechecks_all_native_boundaries() -> None:
    contract = subject._testwindow_contract()
    assert contract["required_at"] == [
        "PRE",
        "LAUNCH",
        "WORKER_BOOTSTRAP",
        "BEFORE_EACH_NATIVE_CELL",
        "POST",
    ]
    assert contract["worker_registry_raw_sha256_bound"] is False
    assert contract["worker_registry_raw_size_bound"] is False
    assert contract["live_process_command_line_reads_forbidden"] is True
    assert "CommandLine" not in subject._QUIESCENCE_POWERSHELL
    assert "ExecutablePath" in subject._QUIESCENCE_POWERSHELL


def test_runner_rechecks_quiescence_before_every_cell(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[object] = []
    proof = {"status": "PASS", "invariant": {}, "invariant_sha256": "x"}
    monkeypatch.setattr(
        subject,
        "assert_testwindow_off_quiescence",
        lambda expected=None: calls.append(expected) or {"status": "PASS"},
    )
    monkeypatch.setattr(
        subject,
        "_BASE_RUNNER_COMMAND",
        lambda pre, cell: ["bound-runner", str(cell["cell_id"])],
    )
    assert subject.runner_command(
        {"testwindow_off_quiescence": proof}, {"cell_id": "DEV"}
    ) == ["bound-runner", "DEV"]
    assert calls == [proof]


def test_resume_is_rejected_before_base_launcher(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        subject,
        "_BASE_LAUNCH_PERSISTENT_TASK",
        lambda *args, **kwargs: pytest.fail("base launch must not receive resume"),
    )
    with pytest.raises(subject.AuthorizationError, match="resume is forbidden"):
        subject.launch_persistent_task(
            subject.PRE_RECEIPT_PATH,
            "a" * 64,
            subject.AUTHORIZATION_PATH,
            subject.STATE_PATH,
            resume=True,
        )


def test_one_shot_namespace_and_control_paths_are_exact() -> None:
    contract = subject._run_namespace_contract()
    assert contract["attempt_id"] == "ATTEMPT_001"
    assert contract["resume_forbidden"] is True
    assert contract["retry_or_attempt002_plus_forbidden"] is True
    assert contract["single_run_root"].endswith(
        r"EURUSD_MULHAM_NATIVE_001\ATTEMPT_001"
    )
    assert set(contract["exact_control_paths"]) == {
        "pre",
        "authorization",
        "state",
        "job",
        "post",
    }


def test_base_strategy_windows_costs_and_merit_are_unchanged() -> None:
    assert subject.MERIT_GATES == subject.B.MERIT_GATES
    assert subject._windows_contract() == [
        {
            "cell_id": "DEV",
            "cohort": "DEV",
            "from_date": "2018-07-02",
            "to_date": "2022-12-31",
        },
        {
            "cell_id": "OOS_2023",
            "cohort": "OOS",
            "from_date": "2023-01-01",
            "to_date": "2023-12-31",
        },
        {
            "cell_id": "OOS_2024",
            "cohort": "OOS",
            "from_date": "2024-01-01",
            "to_date": "2024-12-31",
        },
        {
            "cell_id": "OOS_2025",
            "cohort": "OOS",
            "from_date": "2025-01-01",
            "to_date": "2025-12-31",
        },
    ]
    candidate = subject._candidate_contract()
    assert candidate["duplicates_per_cell"] == subject.B.DUPLICATES == 2
    assert candidate["set_sha256"] == subject.B.EXPECTED_BUILD_HASHES["set"]
    assert candidate["source_build_commit"] == subject.B.EXPECTED_BUILD_COMMIT


def test_final_artifact_roles_bind_data_and_xau_terminal_boundary() -> None:
    roles = subject.FINAL_ARTIFACT_ROLES
    assert {"research_data_manifest", "research_readiness_receipt"} <= roles
    assert "xau_native003_terminal_closure" in roles
    assert "adapter" in roles and "base_tool" in roles
    assert "eur_semantic_contract" not in roles


def test_final_freeze_revalidates_build_set_and_cost_identity(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commit = subject.B.EXPECTED_BUILD_COMMIT
    artifacts = {
        "set": {"path": str(subject.EA_ROOT / "frozen.set")},
        "cost": {"path": str(subject.REPO_ROOT / "cost.json")},
        "live_commission": {"path": str(subject.REPO_ROOT / "commission.json")},
    }
    checked: list[tuple[object, ...]] = []
    monkeypatch.setattr(
        subject.B,
        "validate_build_receipt",
        lambda path, symbol, bindings: {"build_commit": commit},
    )
    monkeypatch.setattr(subject.B, "parse_set", lambda path: ({"symbol": "EURUSD.DWX"}, {}))
    monkeypatch.setattr(
        subject.B,
        "_validate_set_contract",
        lambda symbol, metadata, inputs: checked.append((symbol, metadata, inputs)),
    )
    monkeypatch.setattr(
        subject.B,
        "resolve_cost_schedule",
        lambda *args: {
            "registry_indicative_rt_per_lot_usd": "5.85",
            "ftmo_rt_per_lot_usd": "5",
            "dxz_pct_notional_rt": "0.00005",
        },
    )
    subject._validate_frozen_eur_execution_identity(artifacts, commit)
    assert checked == [("EURUSD.DWX", {"symbol": "EURUSD.DWX"}, {})]
    monkeypatch.setattr(
        subject.B,
        "resolve_cost_schedule",
        lambda *args: {
            "registry_indicative_rt_per_lot_usd": "5.84",
            "ftmo_rt_per_lot_usd": "5",
            "dxz_pct_notional_rt": "0.00005",
        },
    )
    with pytest.raises(subject.InvalidEvidence, match="cost identity drift"):
        subject._validate_frozen_eur_execution_identity(artifacts, commit)


def test_authorization_is_exact_eur_four_cell_model4(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    path = tmp_path / "native_outcome_authorization.json"
    monkeypatch.setattr(subject, "AUTHORIZATION_PATH", path)
    now = datetime(2026, 7, 21, 12, 0, tzinfo=timezone.utc)
    payload = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": subject.ANALYSIS_ID,
        "pre_receipt_sha256": "a" * 64,
        "scope": subject.AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": "EURUSD.DWX",
        "authorized_cells": ["DEV", "OOS_2023", "OOS_2024", "OOS_2025"],
        "duplicates_per_cell": 2,
        "model": 4,
        "authorize_native_outcomes": True,
        "created_utc": (now - timedelta(minutes=1)).isoformat(),
        "expires_utc": (now + timedelta(hours=1)).isoformat(),
    }
    path.write_text(json.dumps(payload), encoding="utf-8")
    validated = subject.validate_authorization(path, "a" * 64, now=now)
    assert validated["payload"] == payload
    payload["unexpected"] = True
    path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(subject.AuthorizationError, match="schema drift"):
        subject.validate_authorization(path, "a" * 64, now=now)
