import ast
import os
import sqlite3
import sys
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _audit_count(root: Path) -> int:
    with sqlite3.connect(root / "state" / "farm_state.sqlite") as conn:
        return conn.execute(
            "SELECT count(*) FROM events WHERE entity_type='agent_audit'"
        ).fetchone()[0]


def test_enqueue_backtest_audits_only_the_supplied_runtime_root(tmp_path: Path) -> None:
    target = tmp_path / "target"
    fallback = tmp_path / "must-not-be-used"
    with (
        mock.patch.object(farmctl, "DEFAULT_ROOT", fallback),
        mock.patch.dict(os.environ, {"QM_AGENT_ID": "controller"}),
    ):
        result = farmctl.enqueue_backtest(target, "missing-review", "Q02")

    assert result["reason"] == "Predecessor task not found: missing-review"
    assert _audit_count(target) == 1
    assert not (fallback / "state" / "farm_state.sqlite").exists()


def test_factory_off_enqueue_returns_before_init_and_audit(tmp_path: Path) -> None:
    target = tmp_path / "off-target"
    fallback = tmp_path / "fallback"
    (target / "state").mkdir(parents=True)
    farmctl.factory_off_flag_path(target).write_text("intentional\n", encoding="utf-8")
    farmctl.init_db(fallback)
    before = _audit_count(fallback)

    with (
        mock.patch.object(farmctl, "DEFAULT_ROOT", fallback),
        mock.patch.dict(os.environ, {"QM_AGENT_ID": "controller"}),
    ):
        result = farmctl.enqueue_backtest(target, "missing-review", "Q02")

    assert result["blocked"] is True
    assert result["reason"] == "factory_off"
    assert not (target / "state" / "farm_state.sqlite").exists()
    assert _audit_count(fallback) == before


def test_reserve_ea_ids_audits_only_the_supplied_runtime_root(tmp_path: Path) -> None:
    target = tmp_path / "reservation-audit"
    fallback = tmp_path / "must-not-be-used"
    with (
        mock.patch.object(farmctl, "DEFAULT_ROOT", fallback),
        mock.patch.dict(os.environ, {"QM_AGENT_ID": "controller"}),
    ):
        result = farmctl.reserve_ea_ids(
            target,
            [],
            strategy_id="TEST",
        )

    assert result == {"reserved": False, "reason": "no_slugs_provided"}
    assert _audit_count(target) == 1
    assert not (fallback / "state" / "farm_state.sqlite").exists()


def test_every_farmctl_scope_guard_call_has_an_explicit_connection() -> None:
    source_path = REPO / "tools" / "strategy_farm" / "farmctl.py"
    tree = ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
    calls = [
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "_scope_guard"
    ]

    assert calls
    without_sink = [
        node.lineno
        for node in calls
        if not any(keyword.arg == "conn" for keyword in node.keywords)
    ]
    assert without_sink == []
