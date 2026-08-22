from __future__ import annotations

import contextlib
import io
import json
import sqlite3
from pathlib import Path
from unittest.mock import patch

import pytest

from tools.strategy_farm import agent_router, farmctl


def _root(tmp_path: Path) -> Path:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    agent_router.sync_default_registry(root, claude_disabled_flag=root / "missing.flag")
    return root


def test_writer_generation_contract_is_owned_by_canonical_checkout(tmp_path: Path) -> None:
    root = _root(tmp_path)
    with agent_router.connect(root) as conn:
        contract = agent_router._router_writer_contract_from_conn(conn)
        trigger_names = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'trg_agent_%canonical%'"
            )
        }

    assert contract["authorized"] is True
    assert contract["stored"]["generation"] == agent_router.ROUTER_WRITER_GENERATION
    assert Path(contract["stored"]["canonical_checkout_root"]).resolve() == (
        agent_router.CANONICAL_ROUTER_ROOT.resolve()
    )
    assert trigger_names == {
        "trg_agent_registry_canonical_insert",
        "trg_agent_registry_canonical_update",
        "trg_agent_registry_canonical_delete",
        "trg_agent_tasks_canonical_insert",
        "trg_agent_tasks_canonical_assignment",
    }


def test_old_connection_cannot_rewrite_registry_enqueue_or_assign(tmp_path: Path) -> None:
    root = _root(tmp_path)
    task = agent_router.enqueue_task(root, "ops_issue", priority=50)

    # Simulates an old agent_router checkout: it opens the shared DB but does
    # not know/register qm_router_writer_generation(). Durable triggers must
    # reject its writes even if that old checkout believes it is authorized.
    with farmctl.connect(root) as old_conn:
        with pytest.raises(sqlite3.OperationalError, match="no such function"):
            old_conn.execute(
                "UPDATE agent_registry SET max_parallel=99 WHERE agent_id='codex'"
            )
        old_conn.rollback()
        with pytest.raises(sqlite3.OperationalError, match="no such function"):
            old_conn.execute(
                """
                INSERT INTO agent_tasks(
                    id,task_type,state,priority,required_capabilities_json,
                    required_skills_json,assigned_agent,budget_class,parent_id,
                    artifact_path,verdict,payload_json,created_at,updated_at
                ) VALUES ('stale-enqueue','ops_issue','TODO',50,'[]','[]',NULL,
                          'standard',NULL,NULL,NULL,'{}','now','now')
                """
            )
        old_conn.rollback()
        with pytest.raises(sqlite3.OperationalError, match="no such function"):
            old_conn.execute(
                "UPDATE agent_tasks SET assigned_agent='codex' WHERE id=?",
                (task["task_id"],),
            )
        old_conn.rollback()
        # Consumer completion does not route or change ownership and remains
        # available to task workspaces running older read/consumer code.
        old_conn.execute(
            "UPDATE agent_tasks SET state='REVIEW' WHERE id=?",
            (task["task_id"],),
        )
        old_conn.commit()

    with agent_router.connect(root) as conn:
        row = conn.execute(
            "SELECT state,assigned_agent FROM agent_tasks WHERE id=?",
            (task["task_id"],),
        ).fetchone()
        max_parallel = conn.execute(
            "SELECT max_parallel FROM agent_registry WHERE agent_id='codex'"
        ).fetchone()[0]
        stale_count = conn.execute(
            "SELECT COUNT(*) FROM agent_tasks WHERE id='stale-enqueue'"
        ).fetchone()[0]
    assert (row["state"], row["assigned_agent"]) == ("REVIEW", None)
    assert max_parallel == agent_router.DEFAULT_AGENT_REGISTRY["codex"]["max_parallel"]
    assert stale_count == 0


def test_current_linked_checkout_refuses_all_router_commands_loudly(tmp_path: Path) -> None:
    linked = tmp_path / "linked"
    linked.mkdir()
    (linked / ".git").write_text("gitdir: elsewhere\n", encoding="utf-8")
    for command in sorted(agent_router.ROUTER_MUTATING_COMMANDS):
        output = io.StringIO()
        with patch.object(agent_router, "ROUTER_CHECKOUT_ROOT", linked), \
             contextlib.redirect_stdout(output):
            return_code = agent_router.main([command])
        document = json.loads(output.getvalue())
        assert return_code == 2
        assert document["refused"] is True
        assert document["reason"] == "noncanonical_router_checkout"
        assert document["command"] == command
        assert document["checkout_root"] == str(linked)
        assert document["git_marker_type"] == "file"
        assert document["canonical_root"] == str(agent_router.CANONICAL_ROUTER_ROOT)


def test_canonical_connection_can_still_assign(tmp_path: Path) -> None:
    root = _root(tmp_path)
    task = agent_router.enqueue_task(root, "ops_issue", priority=50)
    with agent_router.connect(root) as conn:
        cursor = conn.execute(
            "UPDATE agent_tasks SET assigned_agent='codex',state='IN_PROGRESS' WHERE id=?",
            (task["task_id"],),
        )
        conn.commit()
        row = conn.execute(
            "SELECT state,assigned_agent FROM agent_tasks WHERE id=?",
            (task["task_id"],),
        ).fetchone()
    assert cursor.rowcount == 1
    assert (row["state"], row["assigned_agent"]) == ("IN_PROGRESS", "codex")
