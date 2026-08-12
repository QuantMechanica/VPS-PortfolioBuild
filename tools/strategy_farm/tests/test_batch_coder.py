from __future__ import annotations

from pathlib import Path


from tools.strategy_farm import batch_coder


def test_generated_build_uses_canonical_enqueue_defaults(monkeypatch) -> None:
    observed: dict[str, object] = {}

    def fake_enqueue(root: Path, task_type: str, **kwargs: object) -> dict[str, object]:
        observed.update({"root": root, "task_type": task_type, **kwargs})
        return {"enqueued": True, "task_id": "test-task"}

    monkeypatch.setattr(batch_coder.agent_router, "enqueue_task", fake_enqueue)

    result = batch_coder.enqueue_generated_build(
        "QM5_12345",
        "test-slug",
        r"C:\QM\repo\framework\EAs\QM5_12345_test-slug\QM5_12345_test-slug.mq5",
    )

    assert result == {"enqueued": True, "task_id": "test-task"}
    assert observed == {
        "root": batch_coder.strategy_farm_root,
        "task_type": "build_ea",
        "state": "BACKLOG",
        "artifact_path": (
            "C:/QM/repo/framework/EAs/QM5_12345_test-slug/"
            "QM5_12345_test-slug.mq5"
        ),
        "payload": {
            "ea_id": "12345",
            "slug": "test-slug",
            "target_agent_profile": "codex",
        },
    }


def test_batch_coder_contains_no_private_agent_task_insert() -> None:
    source = Path(batch_coder.__file__).read_text(encoding="utf-8")

    assert "INSERT INTO agent_tasks" not in source
    assert "sqlite3" not in source
    assert "agent_router.enqueue_task(" in source
