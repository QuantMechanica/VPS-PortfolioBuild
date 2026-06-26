import json
import sqlite3
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import repair  # noqa: E402


def _make_pending_task_db(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            status TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    return conn


def test_repair_stranded_ea_review_pending_deletes_old_orphan(tmp_path: Path, monkeypatch) -> None:
    root = tmp_path / "farm"
    log_dir = root / "logs"
    log_dir.mkdir(parents=True)
    verdict_dir = root / "artifacts" / "verdicts"
    verdict_dir.mkdir(parents=True)
    db = root / "state" / "farm_state.sqlite"
    db.parent.mkdir(parents=True)
    monkeypatch.setattr(repair, "ROOT", root)
    monkeypatch.setattr(repair, "LOG_DIR", log_dir)

    conn = _make_pending_task_db(db)
    conn.execute(
        """
        INSERT INTO tasks(id, kind, status, payload_json, updated_at)
        VALUES ('review-old', 'ea_review', 'pending', ?, '2026-06-01T00:00:00+00:00')
        """,
        (json.dumps({"build_task_id": "build-1234"}),),
    )
    conn.commit()

    fixes = repair.repair_stranded_ea_review_pending(conn)

    assert [fix["target"] for fix in fixes] == ["review-old"]
    remaining = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
    assert remaining == 0


def test_repair_stranded_ea_review_pending_keeps_written_verdict(tmp_path: Path, monkeypatch) -> None:
    root = tmp_path / "farm"
    log_dir = root / "logs"
    log_dir.mkdir(parents=True)
    verdict_dir = root / "artifacts" / "verdicts"
    verdict_dir.mkdir(parents=True)
    verdict = verdict_dir / "review-live.json"
    verdict.write_text('{"verdict":"APPROVE_FOR_BACKTEST"}', encoding="utf-8")
    db = root / "state" / "farm_state.sqlite"
    db.parent.mkdir(parents=True)
    monkeypatch.setattr(repair, "ROOT", root)
    monkeypatch.setattr(repair, "LOG_DIR", log_dir)

    conn = _make_pending_task_db(db)
    conn.execute(
        """
        INSERT INTO tasks(id, kind, status, payload_json, updated_at)
        VALUES ('review-live', 'ea_review', 'pending', ?, '2026-06-01T00:00:00+00:00')
        """,
        (json.dumps({"verdict_path": str(verdict)}),),
    )
    conn.commit()

    assert repair.repair_stranded_ea_review_pending(conn) == []
    remaining = conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
    assert remaining == 1


def test_record_review_result_accepts_utf8_bom_verdict(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        review_id = farmctl.create_task(
            conn,
            kind="ea_review",
            source_id=None,
            card_id="QM5_9999",
            payload={"build_task_id": "build-9999"},
        )
    verdict_path = root / "artifacts" / "verdicts" / "review_bom.json"
    verdict_path.write_text(
        json.dumps({"verdict": "APPROVE_FOR_BACKTEST", "findings": []}),
        encoding="utf-8-sig",
    )

    result = farmctl.record_review_result(root, review_id, str(verdict_path))

    assert result["recorded"] is True
    assert result["verdict"] == "APPROVE_FOR_BACKTEST"


def test_record_review_result_converts_smoke_infra_only_rework(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        review_id = farmctl.create_task(
            conn,
            kind="ea_review",
            source_id=None,
            card_id="QM5_9998",
            payload={"build_task_id": "build-9998"},
        )
    verdict_path = root / "artifacts" / "verdicts" / "review_infra.json"
    verdict_path.write_text(
        json.dumps(
            {
                "verdict": "REJECT_REWORK",
                "findings": [
                    {
                        "severity": "block",
                        "detail": "REPORT_MISSING / METATESTER_HUNG / MODEL4_MARKER_REQUIRED during terminal contention.",
                    },
                    {"severity": "info", "detail": "Mechanical Match PASS"},
                ],
                "rework_directives": [
                    "Retry run_smoke on a dedicated idle terminal; dispatch_status=duplicate."
                ],
            }
        ),
        encoding="utf-8",
    )

    result = farmctl.record_review_result(root, review_id, str(verdict_path))

    assert result["recorded"] is True
    assert result["verdict"] == "APPROVE_FOR_BACKTEST"
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT payload_json FROM tasks WHERE id=?", (review_id,)).fetchone()
    stored = json.loads(row["payload_json"])["verdict"]
    assert stored["infra_only_review_repaired"] is True
    assert stored["original_verdict"] == "REJECT_REWORK"
    assert stored["verdict"] == "APPROVE_FOR_BACKTEST"
