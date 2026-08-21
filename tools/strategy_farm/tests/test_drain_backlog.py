from __future__ import annotations

import sqlite3
from pathlib import Path

from tools.strategy_farm import agent_router, drain_backlog, farmctl


def _fixture(tmp_path: Path, ea_id: str = "QM5_9009") -> drain_backlog.Config:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    farmctl.init_db(farm_root)
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    registry.parent.mkdir(parents=True)
    registry.write_text(
        "ea_id,slug,source_id,status,owner,created_at\n"
        f"{ea_id.removeprefix('QM5_')},fixture,source,active,Test,2026-08-21\n",
        encoding="utf-8",
    )
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_fixture"
    (ea_dir / "sets").mkdir(parents=True)
    (ea_dir / f"{ea_id}_fixture.mq5").write_text("#property strict\n", encoding="utf-8")
    return drain_backlog.Config.build(farm_root=farm_root, repo_root=repo_root)


def _insert_work_item(cfg: drain_backlog.Config, *, ea_id: str, status: str, verdict: str | None) -> None:
    with sqlite3.connect(cfg.db) as con:
        con.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,payload_json,created_at,updated_at
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                "wi-gated", "backtest", "Q02", ea_id, "EURUSD.DWX", "fixture.set",
                status, verdict, 0, "{}", "2026-08-21T00:00:00Z",
                "2026-08-21T01:00:00Z",
            ),
        )


def test_compiled_recycle_with_done_row_is_already_gated_and_refused(tmp_path: Path) -> None:
    cfg = _fixture(tmp_path)
    ea_dir = cfg.eas_root / "QM5_9009_fixture"
    (ea_dir / "QM5_9009_fixture.ex5").write_bytes(b"compiled")
    (ea_dir / "sets" / "QM5_9009_fixture_EURUSD.DWX_H4_backtest.set").write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8"
    )
    task = agent_router.enqueue_task(
        cfg.farm_root, "build_ea", state="RECYCLE", payload={"ea_id": "QM5_9009"}
    )
    _insert_work_item(cfg, ea_id="QM5_9009", status="done", verdict="PASS")

    snapshot = drain_backlog.classify(cfg)
    assert snapshot["counts"]["RECYCLE_BUILD_ALREADY_GATED"] == 1
    assert snapshot["counts"].get("RECYCLE_BUILD_NEEDS_REBUILD", 0) == 0

    receipt = drain_backlog.apply_wave(
        cfg, defect_class="RECYCLE_BUILD_NEEDS_REBUILD", limit=1, wave_id="gated-refusal"
    )
    assert receipt["selected_count"] == 0
    assert receipt["delegated"]["result"]["moved_count"] == 0
    with agent_router.connect(cfg.farm_root) as con:
        row = con.execute(
            "SELECT state,verdict FROM agent_tasks WHERE id=?", (task["task_id"],)
        ).fetchone()
    assert row["state"] == "RECYCLE"
    assert row["verdict"] is None


def test_recycle_needs_rebuild_wave_is_bounded_and_second_run_is_noop(tmp_path: Path) -> None:
    cfg = _fixture(tmp_path)
    task = agent_router.enqueue_task(
        cfg.farm_root, "build_ea", state="RECYCLE", payload={"ea_id": "QM5_9009"}
    )

    first = drain_backlog.apply_wave(
        cfg, defect_class="RECYCLE_BUILD_NEEDS_REBUILD", limit=1, wave_id="wave-one"
    )
    second = drain_backlog.apply_wave(
        cfg, defect_class="RECYCLE_BUILD_NEEDS_REBUILD", limit=1, wave_id="wave-one"
    )
    assert first["selected_count"] == 1
    assert first["journal_state"] == "COMMITTED"
    assert first["delegated"]["result"]["moved_count"] == 1
    assert second["replayed"] is True
    assert second["moved_count_this_invocation"] == 0
    assert Path(first["receipt_path"]).exists()
    assert Path(second["receipt_path"]).exists()
    with agent_router.connect(cfg.farm_root) as con:
        row = con.execute(
            "SELECT state,verdict FROM agent_tasks WHERE id=?", (task["task_id"],)
        ).fetchone()
    assert row["state"] == "TODO"
    assert row["verdict"] is None


def test_reconcile_exact_task_filter_cannot_move_unselected_recycle(tmp_path: Path) -> None:
    cfg = _fixture(tmp_path)
    first = agent_router.enqueue_task(
        cfg.farm_root, "build_ea", state="RECYCLE", payload={"ea_id": "QM5_9009"}
    )
    second = agent_router.enqueue_task(
        cfg.farm_root, "review_ea", state="RECYCLE", payload={"ea_id": "QM5_9009"}
    )
    result = agent_router.reconcile_task_exits(
        cfg.farm_root,
        apply=True,
        limit=1,
        states=["RECYCLE"],
        task_ids=[first["task_id"]],
    )
    assert result["moved_count"] == 1
    with agent_router.connect(cfg.farm_root) as con:
        states = {
            row["id"]: row["state"]
            for row in con.execute(
                "SELECT id,state FROM agent_tasks WHERE id IN (?,?)",
                (first["task_id"], second["task_id"]),
            )
        }
    assert states[first["task_id"]] == "TODO"
    assert states[second["task_id"]] == "RECYCLE"


def test_gemini_recycle_build_is_held_for_codex_review(tmp_path: Path) -> None:
    cfg = _fixture(tmp_path)
    task = agent_router.enqueue_task(
        cfg.farm_root, "build_ea", state="RECYCLE", payload={"ea_id": "QM5_9009"}
    )
    with sqlite3.connect(cfg.db) as con:
        con.execute(
            "UPDATE agent_tasks SET assigned_agent='gemini' WHERE id=?",
            (task["task_id"],),
        )
    snapshot = drain_backlog.classify(cfg)
    assert snapshot["counts"]["RECYCLE_BUILD_GEMINI_REVIEW_REQUIRED"] == 1
    assert snapshot["counts"].get("RECYCLE_BUILD_NEEDS_REBUILD", 0) == 0
