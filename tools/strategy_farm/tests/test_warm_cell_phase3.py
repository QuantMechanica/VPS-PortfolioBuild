"""Focused tests for the V4a Phase-3 validation packet."""
from __future__ import annotations

import json
from types import SimpleNamespace

from tools.strategy_farm import warm_cell_phase3 as phase3
from tools.strategy_farm import warm_cell_runner as core


def _reference(index: int) -> dict:
    return {
        "selection_rank": index + 1,
        "cell_key": f"cell-{index:02d}",
        "work_item_id": f"work-{index:02d}",
        "arm": "baseline" if index == 0 else f"buy_{index:03d}",
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
        "setfile_sha256": f"{index + 1:064x}",
        "history_manifest_sha256": "c" * 64,
        "cold_elapsed_seconds": 10.0,
        "report_metrics": {"total_trades": 1},
        "trades": [{"entry_time": "2019-01-02T10:00:00Z"}],
        "entry_trading_days": 1,
        "logger_sample_sha256": "d" * 64,
        "native_report_sha256": "e" * 64,
        "receipt_schema_sha256": "f" * 64,
        "summary_path": f"cold-summary-{index}",
        "report_path": f"cold-report-{index}",
        "logger_sample_path": f"cold-logger-{index}",
    }


def test_prepare_cells_authenticates_staged_risk_fixed_inputs(tmp_path):
    repo = tmp_path / "repo"
    inputs = repo / "docs" / "ops" / "evidence" / "inputs"
    inputs.mkdir(parents=True)
    setfile = inputs / "cell.set"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    reference = _reference(0)
    reference["setfile_source_path"] = str(tmp_path / "source" / "cell.set")
    reference["setfile_sha256"] = core.sha256_file(setfile)
    cells = phase3.prepare_cells([reference], input_dir=inputs, repo_root=repo)
    assert cells[0]["setfile_path"] == str(setfile.resolve())
    assert cells[0]["setfile_guard"]["risk_fixed"] == 1000
    assert cells[0]["setfile_guard"]["risk_percent"] == 0


def test_history_receipts_may_have_distinct_paths_when_inventory_is_identical(
    tmp_path,
):
    references = [_reference(index) for index in range(2)]
    files = [
        {"relative_path": "USDJPY.DWX/1.hcc", "size": 3, "sha256": "1" * 64}
    ]
    for index, reference in enumerate(references):
        path = tmp_path / f"receipt-{index}.json"
        path.write_text(
            json.dumps(
                {
                    "schema_version": "qm.custom-history-copy-on-claim/v1",
                    "status": "PASS_PRIVATIZED",
                    "manifest_sha256": "c" * 64,
                    "work_item_id": f"claim-{index}",
                    "files": files,
                }
            ),
            encoding="utf-8",
        )
        reference["history_receipt_path"] = str(path)
    result = phase3.authenticate_common_history_projection(references)
    assert result["status"] == "PASS_COMMON_BYTE_INVENTORY"
    assert result["receipt_count"] == 2
    assert result["file_count"] == 1
    assert result["receipts"][0]["receipt_sha256"] != result["receipts"][1]["receipt_sha256"]
    assert result["receipts"][0]["inventory_sha256"] == result["receipts"][1]["inventory_sha256"]


def test_phase3_packet_proves_twenty_exact_and_measured_speedup(
    tmp_path, monkeypatch
):
    references = [_reference(index) for index in range(20)]
    warm_results = []
    comparisons = []
    for reference in references:
        warm = dict(reference)
        warm["warm_elapsed_seconds"] = 4.0
        warm_results.append(warm)
        comparisons.append(core.compare_cell_results(reference, warm))
    backend = SimpleNamespace(
        results=warm_results,
        session_summary={"elapsed_seconds": 80.0, "closed_exact": True},
        artifact_dir=tmp_path / "runtime",
    )
    authorization_path = tmp_path / "authorization.json"
    authorization_path.write_text(json.dumps({"schema": "authorization"}), encoding="utf-8")
    cold_rows = [
        {
            "path": "tools/strategy_farm/terminal_worker.py",
            "workspace_sha256": "1" * 64,
            "task_start_sha256": "1" * 64,
            "byte_identical_to_task_start": True,
            "tracked_diff": False,
        },
        {
            "path": "framework/scripts/run_smoke.ps1",
            "workspace_sha256": "2" * 64,
            "task_start_sha256": "2" * 64,
            "byte_identical_to_task_start": True,
            "tracked_diff": False,
        },
        {
            "path": "tools/strategy_farm/opt_census.py",
            "workspace_sha256": "3" * 64,
            "task_start_sha256": "3" * 64,
            "byte_identical_to_task_start": True,
            "tracked_diff": False,
        },
        {
            "path": "tools/strategy_farm/dl089_matrix_service.py",
            "workspace_sha256": "4" * 64,
            "task_start_sha256": "4" * 64,
            "byte_identical_to_task_start": True,
            "tracked_diff": False,
        },
    ]
    monkeypatch.setattr(core, "cold_path_identity", lambda *args, **kwargs: cold_rows)
    monkeypatch.setattr(phase3, "_git_head", lambda path: "0" * 40)
    monkeypatch.setattr(phase3, "_implementation_commit", lambda path: "1" * 40)
    packet = phase3.build_packet(
        references=references,
        comparisons=comparisons,
        backend=backend,
        authorization_manifest={"schema": "authorization"},
        authorization_path=authorization_path,
        repo_root=tmp_path,
        db_path=tmp_path / "farm.sqlite",
        outcome_status="EXACT_PARITY",
        outcome_error=None,
        history_projection={
            "status": "PASS_COMMON_BYTE_INVENTORY",
            "receipt_count": 20,
            "file_count": 108,
        },
    )
    assert packet["outcome"]["all_twenty_exact"] is True
    assert packet["timing"]["complete_batch_speedup"] == 2.5
    assert packet["timing"]["target_met"] is True
    assert len(packet["comparison"]["rows"]) == 20
    assert packet["cold_path"]["dl089_untouched"] is True
    assert packet["cold_history_projection"]["receipt_count"] == 20
