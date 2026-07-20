from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


def _insert_old_fifo_row(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        INSERT INTO work_items(
            id, kind, phase, ea_id, symbol, setfile_path, status,
            attempt_count, payload_json, created_at, updated_at
        ) VALUES (
            'old-fifo', 'backtest', 'Q02', 'QM5_8000', 'EURUSD.DWX',
            'old.set', 'pending', 0, '{}',
            '2026-05-01T00:00:00+00:00', '2026-05-01T00:00:00+00:00'
        )
        """
    )
    conn.commit()


def test_fresh_build_q02_is_priority_and_outranks_aged_fifo(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_old_fifo_row(conn)

    setfile = tmp_path / "QM5_9000_new_EURUSD.DWX_H1_backtest.set"
    result = farmctl._auto_enqueue_q02_for_build(
        root,
        {
            "ea_id": "QM5_9000",
            "task_id": "fresh-build-task",
            "setfiles_generated": [str(setfile)],
        },
    )
    assert len(result["enqueued"]) == 1

    with farmctl.connect(root) as conn:
        fresh = conn.execute(
            "SELECT payload_json FROM work_items WHERE ea_id='QM5_9000'"
        ).fetchone()
        ordered = conn.execute(terminal_worker._priority_pending_query()).fetchall()

    assert json.loads(fresh[0])["priority_track"] is True
    assert [row["ea_id"] for row in ordered[:2]] == ["QM5_9000", "QM5_8000"]


def test_force_build_does_not_depend_on_strategy_priority(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    approved = root / "artifacts" / "cards_approved"
    approved.mkdir(parents=True)
    (approved / "QM5_9001_forced.md").write_text(
        "---\nea_id: QM5_9001\nslug: forced\nforce_build: true\n---\n",
        encoding="utf-8",
    )
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status,
                attempt_count, payload_json, created_at, updated_at
            ) VALUES (
                'prior', 'backtest', 'Q02', 'QM5_9001', 'EURUSD.DWX',
                'prior.set', 'done', 0, '{}',
                '2026-01-01T00:00:00+00:00', '2026-01-01T00:00:00+00:00'
            )
            """
        )
        conn.commit()
        assert farmctl._q02_priority_track_required(conn, root, "QM5_9001") is True


def test_first_q02_is_priority_but_existing_organic_survivor_is_unchanged(
    tmp_path: Path,
    monkeypatch,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    monkeypatch.setattr(
        farmctl,
        "_card_requests_force_build",
        lambda _root, _ea_id: False,
    )
    fake_scores = type(
        "Scores",
        (),
        {"compute_scores": staticmethod(lambda: {})},
    )
    monkeypatch.setitem(sys.modules, "strategy_priority", fake_scores)

    with farmctl.connect(root) as conn:
        assert farmctl._q02_priority_track_required(conn, root, "QM5_9002") is True
        conn.execute(
            """
            INSERT INTO work_items(
                id, kind, phase, ea_id, symbol, setfile_path, status,
                attempt_count, payload_json, created_at, updated_at
            ) VALUES (
                'organic-history', 'backtest', 'Q02', 'QM5_9002', 'EURUSD.DWX',
                'prior.set', 'done', 0, '{}',
                '2026-01-01T00:00:00+00:00', '2026-01-01T00:00:00+00:00'
            )
            """
        )
        conn.commit()
        assert farmctl._q02_priority_track_required(conn, root, "QM5_9002") is False


def test_existing_scored_priority_is_preserved_for_later_phases(
    tmp_path: Path,
    monkeypatch,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    setfile = tmp_path / "QM5_9008_scored_EURUSD.DWX_H1_backtest.set"
    setfile.write_text("", encoding="utf-8")
    monkeypatch.setattr(
        farmctl,
        "_find_ea_setfiles",
        lambda _ea_id, _phase: [("EURUSD.DWX", str(setfile))],
    )
    monkeypatch.setattr(
        farmctl,
        "_scored_priority_track",
        lambda _ea_id: True,
    )
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO tasks(
                id, kind, status, card_id, payload_json, created_at, updated_at
            ) VALUES ('parent-q03', 'backtest_q03', 'active', 'QM5_9008', '{}', ?, ?)
            """,
            (now, now),
        )
        created, skipped = farmctl._create_backtest_work_items(
            conn,
            "parent-q03",
            root,
            "QM5_9008",
            "Q03",
            ["EURUSD.DWX"],
        )

    assert skipped == []
    assert created[0]["payload"]["priority_track"] is True
