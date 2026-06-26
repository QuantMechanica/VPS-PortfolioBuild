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


def _make_work_item_db(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY,
            phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            status TEXT NOT NULL,
            verdict TEXT,
            payload_json TEXT NOT NULL,
            evidence_path TEXT,
            updated_at TEXT NOT NULL
        )
        """
    )
    return conn


def _make_portfolio_candidates_db(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE portfolio_candidates (
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            q11_work_item_id TEXT NOT NULL,
            state TEXT NOT NULL,
            evidence_path TEXT,
            first_seen_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY(ea_id, symbol, q11_work_item_id)
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


def test_repair_sparse_q09_overlap_fail_downgrades_to_need_more_data(tmp_path: Path) -> None:
    db = tmp_path / "farm_state.sqlite"
    evidence = tmp_path / "aggregate.json"
    evidence.write_text(
        json.dumps(
            {
                "verdict": "FAIL_PORTFOLIO",
                "reason": "insufficient_overlap",
                "diversifies": True,
            }
        ),
        encoding="utf-8",
    )
    conn = _make_work_item_db(db)
    conn.execute(
        """
        INSERT INTO work_items(
            id, phase, ea_id, symbol, status, verdict,
            payload_json, evidence_path, updated_at
        )
        VALUES (
            'q09-1', 'Q09_PORTFOLIO', 'QM5_10940', 'XAUUSD.DWX',
            'done', 'FAIL_PORTFOLIO', '{}', ?, '2026-06-16T00:54:54+00:00'
        )
        """,
        (str(evidence),),
    )
    conn.commit()

    fixes = repair.repair_sparse_q09_portfolio_overlap_fails(conn)

    assert [fix["target"] for fix in fixes] == ["q09-1"]
    row = conn.execute("SELECT verdict, payload_json FROM work_items WHERE id='q09-1'").fetchone()
    assert row["verdict"] == "NEED_MORE_DATA"
    payload = json.loads(row["payload_json"])
    assert payload["previous_verdict"] == "FAIL_PORTFOLIO"
    assert payload["sparse_overlap_watchlist"] is True
    artifact = json.loads(evidence.read_text(encoding="utf-8"))
    assert artifact["verdict"] == "NEED_MORE_DATA"
    assert artifact["reason"] == "portfolio_correlation_overlap_below_min"
    assert artifact["previous_reason"] == "insufficient_overlap"


def test_repair_stale_portfolio_candidates_demotes_missing_stream(tmp_path: Path, monkeypatch) -> None:
    db = tmp_path / "farm_state.sqlite"
    stream_dir = tmp_path / "q08_trades"
    stream_dir.mkdir()
    monkeypatch.setattr(repair, "COMMON_Q08_STREAM_DIR", stream_dir)
    conn = _make_portfolio_candidates_db(db)
    conn.execute(
        """
        INSERT INTO portfolio_candidates(
            ea_id, symbol, q11_work_item_id, state, evidence_path, first_seen_at, updated_at
        )
        VALUES (
            'QM5_10692', 'NDX.DWX', 'q09-10692', 'Q12_REVIEW_READY',
            'aggregate.json', '2026-06-03T07:22:35+00:00', '2026-06-03T07:22:35+00:00'
        )
        """
    )
    conn.commit()

    fixes = repair.repair_stale_portfolio_candidates(conn)

    assert [fix["target"] for fix in fixes] == ["QM5_10692:NDX.DWX"]
    row = conn.execute(
        "SELECT state FROM portfolio_candidates WHERE ea_id='QM5_10692'"
    ).fetchone()
    assert row["state"] == "EVIDENCE_STALE"
