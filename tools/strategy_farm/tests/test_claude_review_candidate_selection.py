import json
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _task(root: Path, kind: str, status: str, payload: dict, updated_at: str) -> str:
    with farmctl.connect(root) as conn:
        task_id = farmctl.create_task(
            conn,
            kind=kind,
            source_id=None,
            card_id=payload.get("ea_id"),
            payload=payload,
        )
        conn.execute(
            "UPDATE tasks SET status=?, payload_json=?, updated_at=? WHERE id=?",
            (status, json.dumps(payload, separators=(",", ":")), updated_at, task_id),
        )
        conn.commit()
    return task_id


def _done_build(root: Path, ea_id: str, updated_at: str, generation: int, *, ready: bool) -> str:
    payload = {
        "ea_id": ea_id,
        "build_generation": generation,
    }
    if ready:
        payload["codex_result"] = {"mq5_path": f"{ea_id}.mq5"}
    return _task(root, "build_ea", "done", payload, updated_at)


def _pass(root: Path, build_id: str, generation: int) -> str:
    return _task(
        root,
        "codex_review",
        "done",
        {"build_task_id": build_id, "build_generation": generation, "verdict": "PASS"},
        "2026-08-06T12:00:00+00:00",
    )


def _review(root: Path, build_id: str, generation: int) -> str:
    return _task(
        root,
        "ea_review",
        "done",
        {"build_task_id": build_id, "build_generation": generation},
        "2026-08-06T12:01:00+00:00",
    )


def test_candidates_skip_unrenderable_and_current_review_without_starving_later_rows(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)

    unrenderable = _done_build(root, "QM5_BAD", "2026-07-01T00:00:00+00:00", 0, ready=False)
    _pass(root, unrenderable, 0)

    covered = _done_build(root, "QM5_COVERED", "2026-07-02T00:00:00+00:00", 1, ready=True)
    _pass(root, covered, 1)
    _review(root, covered, 1)

    rebuilt = _done_build(root, "QM5_REBUILT", "2026-07-03T00:00:00+00:00", 1, ready=True)
    _pass(root, rebuilt, 1)
    _review(root, rebuilt, 0)  # prior generation must not cover generation 1

    fresh = _done_build(root, "QM5_FRESH", "2026-07-04T00:00:00+00:00", 0, ready=True)
    _pass(root, fresh, 0)

    with farmctl.connect(root) as conn:
        candidates = farmctl._select_ea_review_candidates(conn, 2)

    assert [row["id"] for row in candidates] == [rebuilt, fresh]


def test_claude_spawn_idempotence_is_compact_json_and_generation_aware(
    tmp_path: Path,
    monkeypatch,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    build_id = _done_build(root, "QM5_REBUILT", "2026-08-01T00:00:00+00:00", 2, ready=True)
    _review(root, build_id, 1)
    with farmctl.connect(root) as conn:
        build_row = conn.execute("SELECT * FROM tasks WHERE id=?", (build_id,)).fetchone()

    render_calls: list[str] = []

    def render_probe(_root: Path, task_id: str, _out: str | None) -> dict:
        render_calls.append(task_id)
        return {"written": False, "reason": "probe_stop_before_process_spawn"}

    monkeypatch.setattr(farmctl, "render_claude_review_prompt", render_probe)
    old_generation = farmctl._spawn_claude_for_review(root, build_row)
    assert old_generation["reason"] == "render failed: probe_stop_before_process_spawn"
    assert render_calls == [build_id]

    current_review_id = _review(root, build_id, 2)
    current_generation = farmctl._spawn_claude_for_review(root, build_row)
    assert current_generation == {
        "spawned": False,
        "reason": "ea_review task already exists",
        "review_task_id": current_review_id,
    }
    assert render_calls == [build_id]
