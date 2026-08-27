"""Tests for the Default-OFF V4a warm-cell runner contract."""
from __future__ import annotations

from copy import deepcopy
import json
from types import SimpleNamespace

import pytest

from tools.strategy_farm import warm_cell_runner as runner


def _result(index: int) -> dict:
    return {
        "cell_key": f"cell-{index:02d}",
        "ea_id": "QM5_41161",
        "symbol": "GBPUSD.DWX",
        "period": "H1",
        "model": 4,
        "seed": 42,
        "from_date": "2019.01.01",
        "to_date": "2019.12.31",
        "ex5_sha256": "a" * 64,
        "mq5_sha256": "b" * 64,
        "setfile_sha256": f"{index:064x}",
        "history_manifest_sha256": "c" * 64,
        "report_metrics": {
            "total_trades": index + 5,
            "profit_factor_raw": "1.20",
            "net_profit_raw": "100.00",
            "drawdown_raw": "50.00 (0.05%)",
        },
        "trades": [
            {
                "entry_time": f"2019-01-{index + 1:02d}T10:00:00Z",
                "exit_time": f"2019-01-{index + 1:02d}T12:00:00Z",
                "symbol": "GBPUSD.DWX",
                "side": "buy",
                "net": float(index),
            }
        ],
    }


def _validation_authorization() -> dict:
    return {
        "schema": "qm.warm-cell-validation-run/v1",
        "purpose": "OFFLINE_PARITY_VALIDATION",
        "task_id": runner.TASK_ID,
        "authorized_by": "OWNER_COMMISSION",
        "execution_backend": "SUPPORTED_RESIDENT_TESTER_CONTROL",
        "profile_mode": "DISPOSABLE",
        "production_wiring": False,
        "active_terminal_allowed": False,
        "minimum_comparisons": 20,
    }


class FakeBackend:
    def __init__(self, results: dict[str, dict]):
        self.results = results
        self.opened = 0
        self.closed = 0
        self.executed: list[str] = []

    def open_session(self, pair_contract):
        self.opened += 1
        return {"pair_contract": pair_contract}

    def run_cell(self, session, cell):
        key = cell["cell_key"]
        self.executed.append(key)
        return deepcopy(self.results[key])

    def close_session(self, session):
        self.closed += 1


@pytest.mark.parametrize("value", [None, "", "0", "false", "no", "off"])
def test_flag_is_default_off(value):
    environ = {} if value is None else {runner.FLAG_NAME: value}
    assert runner.feature_flag_enabled(environ) is False


@pytest.mark.parametrize("value", ["1", "true", "yes", "on", " TRUE "])
def test_flag_requires_explicit_on_value(value):
    assert runner.feature_flag_enabled({runner.FLAG_NAME: value}) is True


def test_invalid_flag_fails_closed():
    with pytest.raises(runner.FlagValueError):
        runner.feature_flag_enabled({runner.FLAG_NAME: "maybe"})


def test_default_off_never_touches_backend():
    backend = FakeBackend({})
    result = runner.WarmCellRunner(backend).run(
        cells=[], cold_references={}, environ={}, activation_manifest=None
    )
    assert result == {
        "status": "COLD_PATH_UNCHANGED",
        "flag": runner.FLAG_NAME,
        "flag_enabled": False,
        "cells_executed": 0,
    }
    assert backend.opened == backend.closed == 0


def test_enabled_flag_without_owner_seal_is_refused_before_backend():
    backend = FakeBackend({})
    with pytest.raises(runner.ActivationRefused, match="ACTIVATION_MANIFEST_MISSING"):
        runner.WarmCellRunner(backend).run(
            cells=[],
            cold_references={},
            environ={runner.FLAG_NAME: "1"},
            activation_manifest=None,
        )
    assert backend.opened == 0


def test_twenty_exact_cells_use_one_session():
    references = {f"cell-{i:02d}": _result(i) for i in range(20)}
    backend = FakeBackend(references)
    cells = [{"cell_key": key} for key in references]
    result = runner.WarmCellRunner(backend).run(
        cells=cells,
        cold_references=references,
        environ={runner.FLAG_NAME: "1"},
        activation_manifest=_validation_authorization(),
    )
    assert result["status"] == "EXACT_PARITY"
    assert result["cells_executed"] == 20
    assert result["session_count"] == 1
    assert result["authorization_mode"] == "VALIDATION"
    assert result["parity"]["all_exact"] is True
    assert backend.opened == backend.closed == 1
    assert backend.executed == list(references)


def test_metric_or_trade_deviation_stops_immediately_and_closes_session():
    references = {f"cell-{i:02d}": _result(i) for i in range(20)}
    warm = deepcopy(references)
    warm["cell-03"]["report_metrics"]["net_profit_raw"] = "100.01"
    warm["cell-04"]["trades"][0]["net"] = 999.0
    backend = FakeBackend(warm)
    with pytest.raises(runner.ParityDeviation, match="cell-03"):
        runner.WarmCellRunner(backend).run(
            cells=[{"cell_key": key} for key in references],
            cold_references=references,
            environ={runner.FLAG_NAME: "on"},
            activation_manifest=_validation_authorization(),
        )
    assert backend.executed == [f"cell-{i:02d}" for i in range(4)]
    assert backend.opened == backend.closed == 1


def test_comparator_detects_identity_and_canonical_trade_byte_changes():
    cold = _result(1)
    warm = deepcopy(cold)
    warm["seed"] = 43
    warm["trades"][0]["side"] = "sell"
    comparison = runner.compare_cell_results(cold, warm)
    assert comparison["all_exact"] is False
    assert comparison["identity_mismatch_fields"] == ["seed"]
    assert comparison["report_metrics_field_exact_match"] is True
    assert comparison["trade_list_byte_exact_match"] is False


def test_parity_floor_rejects_nineteen_exact_rows():
    rows = [
        {"cell_key": f"cell-{index:02d}", "all_exact": True}
        for index in range(19)
    ]
    summary = runner.parity_summary(rows)
    assert summary["all_exact"] is False
    assert summary["problems"] == ["PARITY_SAMPLE_BELOW_MINIMUM"]


def test_phase2_task_id_is_valid_for_offline_validation():
    manifest = _validation_authorization()
    manifest["task_id"] = runner.PHASE2_TASK_ID
    assert runner.validation_authorization_problems(manifest) == []


def test_oldest_authenticated_selection_is_deterministic_after_authentication():
    rows = [
        {
            "work_item_id": "b",
            "updated_at": "2026-08-22T07:00:00+00:00",
            "reference_status": "AUTHENTICATED_COLD",
        },
        {
            "work_item_id": "ignored",
            "updated_at": "2026-08-22T05:00:00+00:00",
            "reference_status": "INVALID",
        },
        {
            "work_item_id": "a",
            "updated_at": "2026-08-22T07:00:00+00:00",
            "reference_status": "AUTHENTICATED_COLD",
        },
        {
            "work_item_id": "c",
            "updated_at": "2026-08-22T08:00:00+00:00",
            "reference_status": "AUTHENTICATED_COLD",
        },
    ]
    selected = runner.oldest_authenticated_references(rows, limit=2)
    assert [row["work_item_id"] for row in selected] == ["a", "b"]


def test_cold_timing_summary_keeps_missing_samples_explicit():
    summary = runner.cold_timing_summary(
        [
            {"cold_elapsed_seconds": 10.0},
            {"cold_elapsed_seconds": None},
            {"cold_elapsed_seconds": 20.0},
        ]
    )
    assert summary == {
        "sample_count": 2,
        "total_seconds": 30.0,
        "mean_seconds": 15.0,
        "median_seconds": 15.0,
        "minimum_seconds": 10.0,
        "maximum_seconds": 20.0,
    }


def test_phase3_restart_authorization_is_task_and_lane_bound():
    manifest = {
        "schema": "qm.warm-cell-validation-run/v1",
        "purpose": "OFFLINE_PARITY_VALIDATION",
        "task_id": runner.PHASE3_TASK_ID,
        "authorized_by": "OWNER_COMMISSION",
        "execution_backend": runner.GOVERNED_RESTART_BACKEND,
        "profile_mode": runner.GOVERNED_RESTART_PROFILE,
        "production_wiring": False,
        "active_terminal_allowed": False,
        "minimum_comparisons": 20,
        "lane": "DEV2",
    }
    assert runner.validation_authorization_problems(manifest) == []
    manifest["lane"] = "T1"
    assert "VALIDATION_RESTART_LANE_INVALID" in runner.validation_authorization_problems(
        manifest
    )


def test_comparator_includes_receipt_artifact_bytes_and_entry_days():
    cold = _result(1)
    cold.update(
        {
            "entry_trading_days": 5,
            "logger_sample_sha256": "d" * 64,
            "native_report_sha256": "e" * 64,
            "receipt_schema_sha256": "f" * 64,
        }
    )
    warm = deepcopy(cold)
    warm["logger_sample_sha256"] = "0" * 64
    comparison = runner.compare_cell_results(cold, warm)
    assert comparison["all_exact"] is False
    assert comparison["logger_sample_byte_exact_match"] is False
    assert comparison["native_report_byte_exact_match"] is True
    assert comparison["entry_trading_days_exact_match"] is True
    assert comparison["receipt_schema_exact_match"] is True


def test_validation_setfile_enforces_risk_and_news_guardrails(tmp_path):
    path = tmp_path / "cell.set"
    path.write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=336\n",
        encoding="utf-8",
    )
    result = runner.validate_validation_setfile(path)
    assert result["risk_fixed"] == 1000
    assert result["risk_percent"] == 0
    assert result["qm_news_stale_max_hours"] == 336
    path.write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=337\n",
        encoding="utf-8",
    )
    with pytest.raises(runner.ActivationRefused, match="ABOVE_336"):
        runner.validate_validation_setfile(path)


def test_history_receipt_audit_is_byte_exact(tmp_path):
    lane = tmp_path / "DEV2"
    target = lane / "Bases" / "Custom" / "history" / "USDJPY.DWX" / "2019.hcc"
    target.parent.mkdir(parents=True)
    target.write_bytes(b"history")
    receipt = tmp_path / "receipt.json"
    receipt.write_text(
        json.dumps(
            {
                "schema_version": "qm.custom-history-copy-on-claim/v1",
                "status": "PASS_PRIVATIZED",
                "manifest_sha256": "a" * 64,
                "files": [
                    {
                        "relative_path": "history/USDJPY.DWX/2019.hcc",
                        "size": 7,
                        "sha256": runner.sha256_file(target),
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    result = runner.audit_history_receipt(
        receipt_path=receipt,
        lane_root=lane,
        expected_manifest_sha256="a" * 64,
    )
    assert result["status"] == "PASS_EXACT"
    assert result["file_count"] == 1
    target.write_bytes(b"changed")
    with pytest.raises(runner.ActivationRefused, match="HISTORY_PROJECTION_INVALID"):
        runner.audit_history_receipt(
            receipt_path=receipt,
            lane_root=lane,
            expected_manifest_sha256="a" * 64,
        )


def test_governed_dev2_backend_uses_controller_and_authenticates_receipt(
    tmp_path, monkeypatch
):
    repo = tmp_path / "repo"
    controller = repo / runner.DEV2_CONTROLLER_RELATIVE
    contract = repo / runner.DEV2_LANE_CONTRACT_RELATIVE
    helper = repo / runner.DEV2_CREDENTIAL_HELPER_RELATIVE
    for path in (controller, contract, helper):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(path.name, encoding="utf-8")
    lane = tmp_path / "DEV2"
    programs = {}
    for name in ("terminal64.exe", "metatester64.exe", "MetaEditor64.exe"):
        path = lane / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(name.encode("ascii"))
        programs[name] = runner.sha256_file(path)
    contract.write_text(
        json.dumps(
            {
                "contract_id": "QM_DEV2_ISOLATED_MT5_LANE_V3",
                "program_sha256": programs,
            }
        ),
        encoding="utf-8",
    )
    credential = tmp_path / "credential.json"
    credential.write_text("credential", encoding="utf-8")
    history = lane / "Bases" / "Custom" / "history" / "USDJPY.DWX" / "2019.hcc"
    history.parent.mkdir(parents=True)
    history.write_bytes(b"history")
    history_receipt = tmp_path / "history_receipt.json"
    history_receipt.write_text(
        json.dumps(
            {
                "schema_version": "qm.custom-history-copy-on-claim/v1",
                "status": "PASS_PRIVATIZED",
                "manifest_sha256": "c" * 64,
                "files": [
                    {
                        "relative_path": "history/USDJPY.DWX/2019.hcc",
                        "size": history.stat().st_size,
                        "sha256": runner.sha256_file(history),
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    setfile = repo / "evidence" / "cell.set"
    setfile.parent.mkdir(parents=True)
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    report = tmp_path / "report.htm"
    report.write_bytes(b"native report")
    logger = tmp_path / "logger.jsonl"
    logger.write_bytes(b"logger")
    summary = tmp_path / "summary.json"
    summary_payload = {
        "evidence_schema": "run_smoke/v2",
        "result": "PASS",
        "ea_id": 41097,
        "symbol": "USDJPY.DWX",
        "period": "H1",
        "model": 4,
        "from_date": "2019.01.01",
        "to_date": "2019.12.31",
        "expert": r"QM\QM5_41097_example",
        "logger_sample_path": str(logger),
        "logger_sample": {"path": str(logger), "sha256": runner.sha256_file(logger)},
        "execution_identity": {
            "expert_binary": {
                "deployed": {"sha256": "a" * 64},
                "stable_during_run": True,
            },
            "setfile": {
                "deployed": {"sha256": runner.sha256_file(setfile)},
                "source_matches_deployed": True,
                "stable_during_run": True,
            },
            "mq5_source": {"sha256": "b" * 64},
        },
        "runs": [
            {
                "status": "OK",
                "report_canonical_path": str(report),
                "report_sha256": runner.sha256_file(report),
                "total_trades": 1,
                "total_trades_raw": "1",
                "profit_factor": 1.1,
                "profit_factor_raw": "1.10",
                "net_profit": 10.0,
                "net_profit_raw": "10.00",
                "drawdown": 5.0,
                "drawdown_raw": "5.00 (0.01%)",
                "from_date": "2019.01.01",
                "to_date": "2019.12.31",
                "real_ticks_marker": True,
            }
        ],
    }
    summary.write_text(json.dumps(summary_payload), encoding="utf-8")
    controller_log = tmp_path / "controller.log"
    controller_log.write_text(f"run_smoke.summary={summary}\n", encoding="utf-8")
    controller_result = {
        "success": True,
        "dev2_account_restored_disabled": True,
        "cleanup_lease_disarmed": True,
        "log_path": str(controller_log),
    }
    calls = []

    def fake_process(command, **kwargs):
        calls.append((command, kwargs))
        return SimpleNamespace(
            returncode=0,
            stdout=json.dumps(controller_result),
            stderr="",
        )

    monkeypatch.setattr(runner, "DEV2_ROOT", lane)
    monkeypatch.setattr(runner, "DEV2_CREDENTIAL", credential)
    monkeypatch.setattr(
        runner,
        "_canonical_closed_trades",
        lambda path: ([{"entry_time": "2019-01-02T10:00:00Z"}], {"total_trades": 1}),
    )
    backend = runner.GovernedDev2RestartBackend(
        repo_root=repo,
        artifact_dir=repo / "evidence" / "runtime",
        history_receipt_path=history_receipt,
        expected_history_manifest_sha256="c" * 64,
        process_runner=fake_process,
        lane_probe=lambda: {
            "process_count": 0,
            "account_enabled": False,
            "password_required": True,
        },
    )
    session = backend.open_session(
        {
            "ea_id": "QM5_41097",
            "symbol": "USDJPY.DWX",
            "period": "H1",
            "ex5_sha256": "a" * 64,
            "history_manifest_sha256": "c" * 64,
        }
    )
    result = backend.run_cell(
        session,
        {
            "cell_key": "cell-00",
            "work_item_id": "work-00",
            "arm": "baseline",
            "ea_id": "QM5_41097",
            "ea_label": "QM5_41097_example",
            "expert": r"QM\QM5_41097_example",
            "symbol": "USDJPY.DWX",
            "period": "H1",
            "model": 4,
            "seed": None,
            "from_date": "2019.01.01",
            "to_date": "2019.12.31",
            "ex5_sha256": "a" * 64,
            "mq5_sha256": "b" * 64,
            "setfile_sha256": runner.sha256_file(setfile),
            "setfile_path": str(setfile),
            "history_manifest_sha256": "c" * 64,
        },
    )
    backend.close_session(session)
    assert calls and "terminal64.exe" not in calls[0][0]
    assert str(controller) in calls[0][0]
    assert result["native_report_sha256"] == runner.sha256_file(report)
    assert result["logger_sample_sha256"] == runner.sha256_file(logger)
    assert result["entry_trading_days"] == 1
    assert backend.session_summary["closed_exact"] is True
    assert backend.session_summary["terminal_restarts"] == 1
