"""Durability and fail-closed evidence tests for the Q04 runner."""

from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path
from unittest import mock

from framework.scripts import q04_walkforward as q04
from tools.strategy_farm import prune_workitem_logs


FOLD = {
    "id": "F1",
    "dev_start": "2017-01-01",
    "dev_end": "2022-12-31",
    "oos_start": "2023-01-01",
    "oos_end": "2023-12-31",
}


def test_broken_fold_writes_deterministic_classifiable_summary(tmp_path: Path) -> None:
    setfile = tmp_path / "input.set"
    setfile.write_text("InpFoo=1\n", encoding="utf-8")
    durable = tmp_path / "reports" / "pipeline" / "QM5_1001" / "Q04" / "leaf"
    scratch = tmp_path / "reports" / "work_items" / "wi-1"

    with mock.patch.object(subprocess, "run") as run_mock:
        first = q04.run_fold_via_smoke(
            ea_id=1001,
            ea_expert=r"QM\QM5_1001_missing",
            symbol="EURUSD.DWX",
            setfile=setfile,
            fold=FOLD,
            report_root=tmp_path / "reports" / "pipeline",
            scratch_root=scratch,
            evidence_dir=durable,
            repo_root=tmp_path,
            mt5_root=tmp_path / "mt5",
            terminal="T2",
            period="H1",
        )
        first_bytes = Path(first["summary_path"]).read_bytes()
        second = q04.run_fold_via_smoke(
            ea_id=1001,
            ea_expert=r"QM\QM5_1001_missing",
            symbol="EURUSD.DWX",
            setfile=setfile,
            fold=FOLD,
            report_root=tmp_path / "reports" / "pipeline",
            scratch_root=scratch,
            evidence_dir=durable,
            repo_root=tmp_path,
            mt5_root=tmp_path / "mt5",
            terminal="T2",
            period="H1",
        )

    run_mock.assert_not_called()
    assert Path(second["summary_path"]).read_bytes() == first_bytes
    summary = json.loads(first_bytes)
    assert summary["evidence_schema"] == "q04_fold/v2"
    assert summary["status"] == "INVALID"
    assert summary["verdict_reason"] == "EX5_NOT_RESOLVED"
    assert summary["invalid_reason"] == "EX5_NOT_RESOLVED"


def test_missing_oos_history_is_classified_before_launch(tmp_path: Path) -> None:
    expert_leaf = "QM5_1001_test"
    ea_dir = tmp_path / "framework" / "EAs" / expert_leaf
    ea_dir.mkdir(parents=True)
    (ea_dir / f"{expert_leaf}.ex5").write_bytes(b"compiled")
    setfile = tmp_path / "input.set"
    setfile.write_text("InpFoo=1\n", encoding="utf-8")

    with mock.patch.object(subprocess, "run") as run_mock:
        result = q04.run_fold_via_smoke(
            ea_id=1001,
            ea_expert=rf"QM\{expert_leaf}",
            symbol="EURUSD.DWX",
            setfile=setfile,
            fold=FOLD,
            report_root=tmp_path / "pipeline",
            evidence_dir=tmp_path / "pipeline" / "QM5_1001" / "Q04" / "leaf",
            repo_root=tmp_path,
            mt5_root=tmp_path / "mt5",
            terminal="T2",
            period="H1",
        )

    run_mock.assert_not_called()
    summary = json.loads(Path(result["summary_path"]).read_text(encoding="utf-8"))
    assert summary["verdict_reason"] == "OOS_HISTORY_NOT_WARM"
    assert summary["preflight"]["missing_history_paths"][0].endswith(
        r"EURUSD.DWX\2023.hcc"
    )


def test_q04_main_publishes_ingester_visible_aggregate_that_survives_purge(
    tmp_path: Path,
) -> None:
    reports_parent = tmp_path / "reports"
    pipeline = reports_parent / "pipeline"
    scratch = reports_parent / "work_items" / "wi-q04-7"
    setfile = tmp_path / "baseline.set"
    setfile.write_text("InpFoo=1\n", encoding="utf-8")

    class _Venue:
        @staticmethod
        def per_lot_rt(symbol, variant):
            return 5.85

        @staticmethod
        def source_tag():
            return "test-venue-model"

    def fake_fold(**kwargs):
        return q04._write_fold_summary(
            kwargs["evidence_dir"],
            {
                **kwargs["fold"],
                "pf_net": 1.2,
                "trades": 10,
                "sim_commission_total": 1.0,
                "gross_total": 10.0,
                "cost_variant": "dxz",
                "commission_per_lot_used": 5.85,
                "commission_basis": "venue_dxz_stream",
                "report_pf": 1.2,
                "report_trades": 10,
                "report_guard_reason": None,
                "oos_nets": [1.0] * 10,
                "status": "OK",
                "verdict_reason": "FOLD_COMPLETE",
                "invalid_reason": None,
                "exit_code": 0,
                "log_path": str(scratch / "run_smoke.log"),
                "preflight": {},
            },
        )

    argv = [
        "q04_walkforward.py",
        "--ea", "QM5_1001_test",
        "--symbol", "EURUSD.DWX",
        "--setfile", str(setfile),
        "--report-root", str(pipeline),
        "--scratch-root", str(scratch),
        "--evidence-key", "wi-q04-7",
    ]
    with (
        mock.patch.object(sys, "argv", argv),
        mock.patch.object(q04, "resolve_ea_expert_path", return_value=r"QM\QM5_1001_test"),
        mock.patch.object(q04, "_venue_model", return_value=_Venue()),
        mock.patch.object(q04, "run_fold_via_smoke", side_effect=fake_fold),
    ):
        assert q04.main() == 0

    aggregate = (
        pipeline
        / "QM5_1001"
        / "Q04"
        / q04.q04_evidence_leaf("EURUSD.DWX", "wi-q04-7")
        / "aggregate.json"
    )
    assert json.loads(aggregate.read_text(encoding="utf-8"))["verdict"] == "PASS"
    assert list(pipeline.glob("QM5_*/Q04/*/aggregate.json")) == [aggregate]

    old_log = aggregate.parent / "raw" / "run_01" / "tester.log"
    old_log.parent.mkdir(parents=True)
    old_log.write_text("raw journal", encoding="utf-8")
    old_epoch = dt.datetime(2026, 7, 1, tzinfo=dt.UTC).timestamp()
    os.utime(old_log, (old_epoch, old_epoch))
    stats = prune_workitem_logs.prune_pipeline_logs(
        dry_run=False,
        older_than_days=1,
        reports_parent=reports_parent,
        now=dt.datetime(2026, 7, 25, tzinfo=dt.UTC),
    )

    assert stats["files"] == 1
    assert not old_log.exists()
    assert aggregate.is_file()
    assert json.loads(aggregate.read_text(encoding="utf-8"))["evidence_key"] == "wi-q04-7"
