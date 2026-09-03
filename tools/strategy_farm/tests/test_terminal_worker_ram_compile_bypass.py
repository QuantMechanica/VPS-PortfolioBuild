"""2026-09-03 (CEO): under the RAM latch a worker may still claim COMPILE_EA
rows (and only those) while free RAM stays above COMPILE_RAM_MIN_FREE_GB."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


def _insert(conn, item_id, phase, payload=None):
    now = "2026-09-03T00:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                               evidence_path,payload_json,created_at,updated_at)
        VALUES(?,?,?,?,?,'x.set','pending',NULL,NULL,?,?,?)
        """,
        (item_id, "compile" if phase == farmctl.COMPILE_EA_PHASE else "backtest", phase,
         f"QM5_{item_id}", "", json.dumps(payload or {}), now, now),
    )


def test_compile_bypass_requires_a_claimable_compile_row(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    assert terminal_worker._ram_latch_compile_bypass_available(root, 6.0) is False
    with farmctl.connect(root) as conn:
        _insert(conn, "q02-row", "Q02")
        conn.commit()
    assert terminal_worker._ram_latch_compile_bypass_available(root, 6.0) is False
    with farmctl.connect(root) as conn:
        _insert(conn, "compile-row", farmctl.COMPILE_EA_PHASE)
        conn.commit()
    assert terminal_worker._ram_latch_compile_bypass_available(root, 6.0) is True


def test_compile_bypass_respects_the_compile_floor_and_holds(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert(conn, "compile-row", farmctl.COMPILE_EA_PHASE)
        conn.commit()
    assert terminal_worker._ram_latch_compile_bypass_available(
        root, terminal_worker.COMPILE_RAM_MIN_FREE_GB - 0.1
    ) is False
    with farmctl.connect(root) as conn:
        conn.execute(
            "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,created_at,updated_at) "
            "VALUES('compile-row','X','t',1,'2026-09-03T00:00:00+00:00','2026-09-03T00:00:00+00:00')"
        )
        conn.commit()
    assert terminal_worker._ram_latch_compile_bypass_available(root, 6.0) is False
