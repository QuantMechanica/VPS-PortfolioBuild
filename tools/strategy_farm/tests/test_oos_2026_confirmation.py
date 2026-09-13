import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import farmctl
from tools.strategy_farm import oos_2026_confirmation as subject
from tools.strategy_farm import q09_news_runner as q09


def test_enqueue_phase_is_manifest_derived_not_a_hard_coded_literal() -> None:
    """LINK 1 of the 2026-09-04 mis-phase defect: the INSERT must not carry a literal."""

    assert subject.active_news_phase() == q09.NEWS_PHASE == farmctl._NEWS_PHASE
    assert subject.news_storage_lanes()[0] == farmctl._NEWS_PHASE
    source = Path(subject.__file__).read_text(encoding="utf-8")
    insert = next(
        line for line in source.splitlines()
        if "INSERT INTO work_items(id,kind,phase" in line
    )
    assert "'Q09_NEWS'" not in insert
    assert "VALUES(?,'backtest',?," in insert


def test_enqueue_refuses_when_resolved_phase_is_not_the_active_news_lane(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(farmctl, "_NEWS_PHASE", "Q11_NEWS_SOMETHING_ELSE")
    with pytest.raises(subject.OOS2026Error, match="not the active NEWS lane"):
        subject.active_news_phase()
    # enqueue resolves the lane BEFORE it opens the write transaction.
    with pytest.raises(subject.OOS2026Error, match="not the active NEWS lane"):
        subject.enqueue({"runs": [], "router_task_id": "x"})


def _misphase_db(tmp_path: Path) -> Path:
    db = tmp_path / "farm_state.sqlite"
    campaign = {"diagnostic_campaign_id": subject.CAMPAIGN_ID, "window_source": "oos_2026"}
    other = {"diagnostic_campaign_id": "some-other-campaign"}
    with sqlite3.connect(db) as conn:
        conn.execute(
            "CREATE TABLE work_items("
            "id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,"
            "status TEXT,created_at TEXT,payload_json TEXT)"
        )
        conn.execute(
            "CREATE TABLE work_item_holds(work_item_id TEXT,hold_code TEXT,"
            "reason TEXT,active INTEGER)"
        )
        rows = [
            ("held", "Q09_NEWS", "pending", campaign),
            ("unheld", "Q09_NEWS", "pending", campaign),
            ("active_lane", farmctl._NEWS_PHASE, "pending", campaign),
            ("done_historical", "Q09_NEWS", "done", campaign),
            ("foreign", "Q09_NEWS", "pending", other),
        ]
        for item_id, phase, status, payload in rows:
            conn.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
                (item_id, "backtest", phase, "QM5_1", "EURUSD.DWX", status,
                 "2026-09-02T00:00:00+00:00", json.dumps(payload, sort_keys=True)),
            )
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?)",
            ("held", "OOS_WINDOW_MISMATCH", "campaign window mismatch", 1),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?)",
            ("held", "RELEASED_HOLD", "already released", 0),
        )
    return db


def test_report_misphased_pending_rows_is_read_only_and_lists_holds(
    tmp_path: Path,
) -> None:
    db = _misphase_db(tmp_path)
    before = db.read_bytes()

    report = subject.report_misphased_pending_rows(db)

    assert report["schema_version"] == subject.MISPHASED_REPORT_SCHEMA
    assert report["read_only"] is True
    assert report["active_news_phase"] == farmctl._NEWS_PHASE
    assert report["misphased_pending_count"] == 2
    assert report["pending_on_active_lane_count"] == 1
    by_id = {row["work_item_id"]: row for row in report["rows"]}
    # Only pending campaign rows off the active lane; done/foreign are excluded.
    assert set(by_id) == {"held", "unheld"}
    assert by_id["held"]["phase"] == "Q09_NEWS"
    assert by_id["held"]["held"] is True
    assert [hold["hold_code"] for hold in by_id["held"]["holds"]] == [
        "OOS_WINDOW_MISMATCH"
    ]
    assert by_id["unheld"]["holds"] == []
    assert by_id["unheld"]["held"] is False
    assert db.read_bytes() == before


def test_campaign_scope_is_fixed_single_window_non_admission() -> None:
    assert len(subject.FRONTIER) == 31
    assert len(set(subject.FRONTIER)) == 31
    assert subject.FROM_UTC == "2026-01-01T00:00:00Z"
    assert subject.TO_UTC == "2026-04-06T23:59:59Z"
    assert subject.WINDOW_SOURCE == "oos_2026"
    assert subject.ALLOWED == ["T1", "T2", "T3", "T4", "T5"]
    assert subject.AVOID == ["T6", "T7", "T8", "T9", "T10"]


def test_single_window_timeout_is_supported() -> None:
    assert q09.required_factory_timeout_min(1, window_count=1) > 60


def _write_basket_manifest(repo_root: Path) -> Path:
    ea_dir = repo_root / "framework" / "EAs" / "QM5_12778_test-basket"
    ea_dir.mkdir(parents=True)
    manifest = ea_dir / "basket_manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "logical_symbol": "QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1",
                "host_symbol": "AUDUSD.DWX",
                "host_timeframe": "D1",
                "tester_currency": "EUR",
                "tester_deposit": 100000,
                "basket_symbols": [
                    "AUDUSD.DWX",
                    "EURJPY.DWX",
                    "EURUSD.DWX",
                    "EURAUD.DWX",
                ],
                "traded_symbols": ["AUDUSD.DWX", "EURJPY.DWX"],
            }
        ),
        encoding="utf-8",
    )
    return manifest


def test_basket_payload_binds_all_history_and_conversion_symbols(tmp_path: Path) -> None:
    manifest = _write_basket_manifest(tmp_path)

    payload = subject._basket_payload(
        "QM5_12778", "AUDUSD.DWX", "D1", repo_root=tmp_path
    )

    assert payload["basket_manifest"] == str(manifest.resolve())
    assert payload["basket_manifest_sha256"] == subject.sha(manifest)
    assert payload["basket_symbol_count"] == 4
    assert payload["basket_symbols"] == [
        "AUDUSD.DWX",
        "EURJPY.DWX",
        "EURUSD.DWX",
        "EURAUD.DWX",
    ]
    assert payload["traded_symbols"] == ["AUDUSD.DWX", "EURJPY.DWX"]
    assert payload["conversion_symbols"] == ["EURUSD.DWX", "EURAUD.DWX"]
    assert payload["portfolio_scope"] == "basket"


def test_guarded_repair_adds_manifest_context_to_one_pending_diagnostic(
    tmp_path: Path,
) -> None:
    _write_basket_manifest(tmp_path)
    db = tmp_path / "farm_state.sqlite"
    work_item_id = "24acc5d4-test"
    payload = {
        "diagnostic_non_admission": True,
        "diagnostic_campaign_id": subject.CAMPAIGN_ID,
        "q09_activation_state": "RUNNABLE_BOUND",
        "host_symbol": "AUDUSD.DWX",
        "host_timeframe": "D1",
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
    }
    payload["q09_dispatch_binding_sha256"] = q09._dispatch_binding_sha256(payload)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "CREATE TABLE work_items("
            "id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,"
            "status TEXT,claimed_by TEXT,payload_json TEXT,updated_at TEXT)"
        )
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?)",
            (
                work_item_id,
                "backtest",
                "Q09_NEWS",
                "QM5_12778",
                "AUDUSD.DWX",
                "pending",
                None,
                json.dumps(payload, sort_keys=True),
                "2026-09-03T00:00:00+00:00",
            ),
        )

    plan = subject.plan_basket_payload_repair(db, work_item_id, repo_root=tmp_path)
    assert plan["status"] == "READY_FOR_APPLY"
    assert set(plan["added_keys"]) >= {
        "basket_manifest",
        "basket_symbol_count",
        "basket_symbols",
        "conversion_symbols",
        "traded_symbols",
    }

    journal = tmp_path / "repair.json"
    result = subject.apply_basket_payload_repair(
        db,
        tmp_path / "FACTORY_MUTATION.lock",
        work_item_id,
        journal,
        repo_root=tmp_path,
    )
    assert result["status"] == "APPLIED"
    assert journal.is_file()
    with sqlite3.connect(db) as conn:
        repaired = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (work_item_id,)
            ).fetchone()[0]
        )
    assert repaired["basket_symbol_count"] == 4
    assert repaired["conversion_symbols"] == ["EURUSD.DWX", "EURAUD.DWX"]
    assert repaired[subject.BASKET_REPAIR_MARKER]["reason"] == subject.BASKET_REPAIR_REASON
    assert repaired["risk_fixed"] == 1000.0
    assert repaired["risk_percent"] == 0.0
    assert subject.plan_basket_payload_repair(
        db, work_item_id, repo_root=tmp_path
    )["status"] == "NOTHING_TO_DO"

    repaired["basket_symbol_count"] = 2
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id=?",
            (json.dumps(repaired, sort_keys=True), work_item_id),
        )
    with pytest.raises(subject.OOS2026Error, match="contradicts the manifest"):
        subject.plan_basket_payload_repair(db, work_item_id, repo_root=tmp_path)
