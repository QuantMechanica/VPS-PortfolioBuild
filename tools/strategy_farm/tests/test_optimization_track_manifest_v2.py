from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import farmctl, render_cockpit
from tools.strategy_farm.optimization_dashboard_status import (
    optimization_track_snapshot,
    successful_phase_counts,
)


def _database(path: Path) -> None:
    with sqlite3.connect(path) as con:
        con.execute(
            """
            CREATE TABLE work_items (
                id TEXT PRIMARY KEY,
                phase TEXT NOT NULL,
                verdict TEXT,
                status TEXT NOT NULL
            )
            """
        )
        con.executemany(
            "INSERT INTO work_items VALUES (?,?,?,?)",
            [
                ("q14-ok", "Q14", "OPT_ELIGIBLE", "done"),
                ("q14-no", "Q14", "OPT_REJECTED", "done"),
                ("q14-open", "Q14", None, "pending"),
                ("q15-ok", "Q15", "CHALLENGER_SPAWNED", "done"),
                ("q16-promote", "Q16", "PROMOTE_CHALLENGER", "done"),
                ("q16-keep", "Q16", "KEEP_INCUMBENT", "done"),
                ("q16-both", "Q16", "ADMIT_BOTH", "done"),
                ("ordinary", "Q10", "PASS", "done"),
            ],
        )


def _book_manifest(root: Path, directory: str, lane: str, status: str) -> Path:
    path = root / directory / "manifest.json"
    path.parent.mkdir(parents=True)
    lane_fields = (
        {"weighting": {}, "comparison": {}, "stream_basis": {}}
        if lane == "Q11_DXZ"
        else {
            "challenge_recommendation": "NONE",
            "fund_score": {},
            "density": {},
            "ftmo_cost_swap": {},
            "phase1_bootstrap": {},
            "bar": {},
        }
    )
    path.write_text(
        json.dumps(
            {
                "schema": "qm.dual-book-manifest/v1",
                "lane": lane,
                "as_of": "2026-08-12",
                "execution_mode": "DRY_RUN",
                "status": status,
                "application_authority": "OWNER_ONLY",
                "deployment_action": "NONE",
                "autotrading_action": "NONE",
                "roster_sha256": "a" * 64,
                "sleeve_list_sha256": "b" * 64,
                "sleeves": [
                    {
                        "ea_id": 1,
                        "symbol": "EURUSD.DWX",
                        "magic": 10000001,
                        "setfile": "framework/EAs/QM5_1/sets/test.set",
                        "setfile_sha256": "c" * 64,
                        "weight": 1.0,
                    }
                ],
                **lane_fields,
            }
        ),
        encoding="utf-8",
    )
    return path


def test_read_model_counts_extension_and_validates_latest_parked_books(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    report_root = tmp_path / "portfolio"
    _database(database)
    _book_manifest(report_root, "book_dxz_2026-08-11", "Q11_DXZ", "NOT_WORSE_BAR_NOT_MET")
    latest_dxz = _book_manifest(
        report_root, "book_dxz_2026-08-12", "Q11_DXZ", "APPLY_RECOMMENDED"
    )
    _book_manifest(report_root, "book_ftmo_2026-08-12", "Q11_FTMO", "BAR_NOT_MET")
    before = hashlib.sha256(database.read_bytes()).hexdigest()

    snapshot = optimization_track_snapshot(database, report_root)

    assert snapshot["available"] is True
    assert snapshot["schema_version"] == "qm.optimization-track-dashboard/v1"
    assert snapshot["phases"]["Q14"] == {
        "phase": "Q14",
        "total": 3,
        "open": 1,
        "outcomes": {"OPT_ELIGIBLE": 1, "OPT_REJECTED": 1},
    }
    assert successful_phase_counts(snapshot) == {"Q14": 1, "Q15": 1, "Q16": 3}
    assert snapshot["books"]["Q11_DXZ"]["validation"] == "VALID"
    assert snapshot["books"]["Q11_DXZ"]["manifest_path"] == str(latest_dxz)
    assert snapshot["books"]["Q11_FTMO"]["book_status"] == "BAR_NOT_MET"
    assert hashlib.sha256(database.read_bytes()).hexdigest() == before

    page = render_cockpit.render_optimization_track(snapshot)
    assert "Optimization Track // Q10 Fork" in page
    assert "Q10 &rarr; Q14 &rarr; Q15" in page
    assert "Q11_DXZ // VALID" in page and "Q11_FTMO // VALID" in page
    assert "no worker, deployment, terminal" in page
    assert "AutoTrading authority" in page


def test_latest_manifest_is_fail_closed_and_missing_lane_is_visible(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    report_root = tmp_path / "portfolio"
    _database(database)
    _book_manifest(report_root, "book_dxz_2026-08-11", "Q11_DXZ", "APPLY_RECOMMENDED")
    invalid = _book_manifest(
        report_root, "book_dxz_2026-08-12", "Q11_DXZ", "APPLY_RECOMMENDED"
    )
    value = json.loads(invalid.read_text(encoding="utf-8"))
    value["autotrading_action"] = "ENABLE"
    invalid.write_text(json.dumps(value), encoding="utf-8")

    snapshot = optimization_track_snapshot(database, report_root)

    assert snapshot["books"]["Q11_DXZ"]["validation"] == "INVALID"
    assert "autotrading_action='ENABLE'" in snapshot["books"]["Q11_DXZ"]["error"]
    assert snapshot["books"]["Q11_FTMO"]["validation"] == "MISSING"
    page = render_cockpit.render_optimization_track(snapshot)
    assert "Q11_DXZ // INVALID" in page
    assert "Q11_FTMO // MISSING" in page


def test_manifest_v2_shipping_creates_no_rows_and_no_terminal_worker_route(
    tmp_path: Path,
) -> None:
    farmctl.init_db(tmp_path)
    with sqlite3.connect(farmctl.db_path(tmp_path)) as con:
        total = con.execute("SELECT COUNT(*) FROM work_items").fetchone()[0]
        extension = con.execute(
            "SELECT COUNT(*) FROM work_items WHERE phase IN ('Q14','Q15','Q16')"
        ).fetchone()[0]
    assert total == 0
    assert extension == 0

    parser = farmctl.build_parser()
    dry_run = parser.parse_args(["enqueue-opt-admission"])
    apply_run = parser.parse_args(["enqueue-opt-admission", "--apply"])
    assert farmctl._command_mutates_state(dry_run) is False
    assert farmctl._command_mutates_state(apply_run) is True
    assert {"Q14", "Q15", "Q16"}.isdisjoint(farmctl.PHASE_RUNNER_SCRIPTS)
    assert {
        "OPT_ELIGIBLE",
        "OPT_REJECTED",
        "CHALLENGER_SPAWNED",
        "PROMOTE_CHALLENGER",
        "KEEP_INCUMBENT",
        "ADMIT_BOTH",
    }.issubset(farmctl.CANONICAL_PARENT_CHILD_VERDICTS)

    worker_source = Path(farmctl.__file__).with_name("terminal_worker.py").read_text(
        encoding="utf-8"
    )
    assert all(token not in worker_source for token in ("Q14", "Q15", "Q16"))
