from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm.blocked_backlog_retest import apply_manifest, sha256_text


def _farm(tmp_path: Path) -> Path:
    root = tmp_path / "farm"
    (root / "state").mkdir(parents=True)
    conn = sqlite3.connect(root / "state" / "farm_state.sqlite")
    conn.executescript(
        """
        CREATE TABLE agent_tasks (
            id TEXT PRIMARY KEY,
            task_type TEXT NOT NULL,
            state TEXT NOT NULL,
            priority INTEGER NOT NULL,
            required_capabilities_json TEXT NOT NULL,
            assigned_agent TEXT,
            budget_class TEXT NOT NULL,
            parent_id TEXT,
            artifact_path TEXT,
            verdict TEXT,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            required_skills_json TEXT NOT NULL
        );
        CREATE TABLE agent_task_transition_ledger (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            idempotency_key TEXT NOT NULL UNIQUE,
            ts TEXT NOT NULL,
            task_id TEXT NOT NULL,
            action TEXT NOT NULL,
            from_state TEXT NOT NULL,
            to_state TEXT NOT NULL,
            reason TEXT NOT NULL,
            detail_json TEXT NOT NULL
        );
        """
    )
    for task_id, verdict in (("task-a", "old-a"), ("task-b", "old-b")):
        conn.execute(
            "INSERT INTO agent_tasks VALUES (?, 'ops_issue', 'BLOCKED', 50, '[]', "
            "'codex', 'standard', NULL, NULL, ?, '{}', '2026-08-21T00:00:00+00:00', "
            "'2026-08-21T01:00:00+00:00', '[]')",
            (task_id, verdict),
        )
    conn.commit()
    conn.close()
    return root


def _write_manifest(path: Path, decisions: list[dict[str, object]]) -> Path:
    path.write_text(
        json.dumps({"campaign": "test-campaign", "decisions": decisions}),
        encoding="utf-8",
    )
    return path


def _decision(task_id: str, verdict: str, **overrides: object) -> dict[str, object]:
    result: dict[str, object] = {
        "task_id": task_id,
        "target_state": "BLOCKED",
        "reason": "still true",
        "owner": "Development",
        "unblock_action": "repair and re-review",
        "blocking_condition_still_true": True,
        "expected_updated_at": "2026-08-21T01:00:00+00:00",
        "expected_verdict_sha256": sha256_text(verdict),
    }
    result.update(overrides)
    return result


def test_apply_records_named_action_and_transition(tmp_path: Path) -> None:
    farm = _farm(tmp_path)
    manifest = _write_manifest(
        tmp_path / "manifest.json",
        [
            _decision("task-a", "old-a"),
            _decision(
                "task-b",
                "old-b",
                target_state="PASSED",
                reason="superseded bookkeeping",
                owner=None,
                unblock_action=None,
                blocking_condition_still_true=False,
            ),
        ],
    )

    result = apply_manifest(farm_root=farm, manifest_path=manifest)

    assert result["applied_count"] == 2
    assert result["states"] == {"BLOCKED": 1, "PASSED": 1}
    conn = sqlite3.connect(farm / "state" / "farm_state.sqlite")
    rows = conn.execute(
        "SELECT id, state, verdict, payload_json FROM agent_tasks ORDER BY id"
    ).fetchall()
    ledger = conn.execute(
        "SELECT task_id, from_state, to_state FROM agent_task_transition_ledger ORDER BY task_id"
    ).fetchall()
    conn.close()
    assert rows[0][1] == "BLOCKED"
    assert "OWNER=Development" in rows[0][2]
    assert json.loads(rows[0][3])["blocked_retest"]["unblock_action"] == "repair and re-review"
    assert rows[1][1] == "PASSED"
    assert ledger == [
        ("task-a", "BLOCKED", "BLOCKED"),
        ("task-b", "BLOCKED", "PASSED"),
    ]


def test_apply_rolls_back_whole_manifest_on_cas_failure(tmp_path: Path) -> None:
    farm = _farm(tmp_path)
    manifest = _write_manifest(
        tmp_path / "manifest.json",
        [
            _decision("task-a", "old-a"),
            _decision("task-b", "wrong-verdict"),
        ],
    )

    with pytest.raises(ValueError, match="verdict changed for task-b"):
        apply_manifest(farm_root=farm, manifest_path=manifest)

    conn = sqlite3.connect(farm / "state" / "farm_state.sqlite")
    assert conn.execute("SELECT id, state, verdict FROM agent_tasks ORDER BY id").fetchall() == [
        ("task-a", "BLOCKED", "old-a"),
        ("task-b", "BLOCKED", "old-b"),
    ]
    assert conn.execute("SELECT COUNT(*) FROM agent_task_transition_ledger").fetchone()[0] == 0
    conn.close()


def test_apply_refuses_unowned_blocked_action(tmp_path: Path) -> None:
    farm = _farm(tmp_path)
    manifest = _write_manifest(
        tmp_path / "manifest.json",
        [_decision("task-a", "old-a", owner="", unblock_action="")],
    )

    with pytest.raises(ValueError, match="BLOCKED decision lacks owner/action"):
        apply_manifest(farm_root=farm, manifest_path=manifest)
